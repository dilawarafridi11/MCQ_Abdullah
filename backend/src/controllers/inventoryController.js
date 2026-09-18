const Product = require('../models/Product');
const InventoryLog = require('../models/InventoryLog');
const Notification = require('../models/Notification');
const Shop = require('../models/Shop');
const ApiError = require('../utils/ApiError');
const asyncHandler = require('../utils/asyncHandler');
const ApiResponse = require('../utils/ApiResponse');
const { recordAudit } = require('../middleware/auth');

const assertShopAccess = (product, user) => {
  if (user.role === 'manager' && product.shop.toString() !== user.assignedShop._id.toString()) {
    throw new ApiError(403, 'You can only manage inventory of your assigned shop.');
  }
};

const normalizeCarpetPieces = (arr) =>
  Array.isArray(arr)
    ? arr
        .filter((p) => p && Number(p.width) > 0 && Number(p.height) > 0)
        .map((p) => ({
          width: Number(p.width),
          height: Number(p.height),
          area: Number(p.width) * Number(p.height),
          color: String(p.color || ''),
          image: String(p.image || ''),
        }))
    : [];

const normalizeQaleenSizes = (arr) =>
  Array.isArray(arr)
    ? arr
        .filter((s) => s && Number(s.height) > 0 && Number(s.width) > 0 && Number(s.pieces) > 0)
        .map((s) => ({
          height: Number(s.height),
          width: Number(s.width),
          pieces: Number(s.pieces),
        }))
    : [];

const sizeKey = (s) => `${s.width}x${s.height}`;

const matchesPiece = (x, p) =>
  x && Math.abs(Number(x.width) - p.width) < 1e-9 &&
  Math.abs(Number(x.height) - p.height) < 1e-9 &&
  (p.color === '' || String(x.color || '') === p.color);

// Convert a legacy single-roll carpet (only width/height set, no piece breakdown)
// into a real tracked piece so the remaining stock stays dimensionally coherent.
const promoteLegacyCarpet = (product) => {
  if (product.carpetPiecesData.length === 0 && Number(product.carpetWidth) > 0 && Number(product.carpetHeight) > 0) {
    product.carpetPiecesData.push({
      width: Number(product.carpetWidth),
      height: Number(product.carpetHeight),
      area: Number(product.carpetWidth) * Number(product.carpetHeight),
      color: product.color || '',
      image: Array.isArray(product.images) && product.images[0] ? product.images[0] : '',
    });
    product.carpetWidth = 0;
    product.carpetHeight = 0;
  }
  if (product.carpetPiecesData.length > 0) {
    product.carpetPieces = product.carpetPiecesData.length;
  }
};

const maybeNotifyLowStock = async (product, user) => {
  if (product.quantity <= product.lowStockThreshold) {
    const User = require('../models/User');
    const Shop = require('../models/Shop');
    const [admins, shop] = await Promise.all([
      User.find({ role: 'admin', isActive: true }),
      Shop.findById(product.shop),
    ]);
    const recipients = [
      ...admins.map((a) => a._id),
      ...(shop && shop.manager ? [shop.manager] : []),
    ];
    const title = 'Low Stock Alert';
    const body = `Product "${product.name}" is low on stock (${product.quantity} left).`;
    await Notification.insertMany(
      recipients.map((user) => ({ user, title, body, type: 'low_stock', data: { productId: product._id } }))
    );
  }
};

const stockIn = asyncHandler(async (req, res) => {
  const { productId, quantity, supplier, date, notes, carpetPieces, qaleenSizes, length } = req.body;
  if (!productId) {
    throw new ApiError(400, 'Product is required.');
  }

  const product = await Product.findById(productId);
  if (!product || product.isDeleted) throw new ApiError(404, 'Product not found.');
  assertShopAccess(product, req.user);

  const previousStock = product.quantity;
  const pt = product.productType || 'qaleen';
  let addedQty = 0;
  let logPieces = [];
  let logSizes = [];
  let logLength = 0;

  if (pt === 'carpet') {
    const pieces = normalizeCarpetPieces(carpetPieces);
    if (pieces.length === 0) {
      throw new ApiError(400, 'Width and height are required for each carpet piece.');
    }
    promoteLegacyCarpet(product);
    product.carpetPiecesData.push(...pieces);
    product.carpetPieces = product.carpetPiecesData.length;
    addedQty = pieces.reduce((sum, p) => sum + p.area, 0);
    logPieces = pieces;
  } else if (pt === 'qaleen') {
    const sizes = normalizeQaleenSizes(qaleenSizes);
    if (sizes.length === 0) {
      throw new ApiError(400, 'Height, width and pieces are required for each qaleen size.');
    }
    sizes.forEach((s) => {
      const key = sizeKey(s);
      const idx = product.qaleenSizes.findIndex((x) => sizeKey(x) === key);
      if (idx >= 0) product.qaleenSizes[idx].pieces += s.pieces;
      else product.qaleenSizes.push(s);
    });
    addedQty = sizes.reduce((sum, s) => sum + s.pieces, 0);
    logSizes = sizes;
  } else if (pt === 'meter') {
    const len = Number(length);
    if (!(len > 0)) {
      throw new ApiError(400, 'A positive length in meters is required.');
    }
    product.meterLength = Number(product.meterLength || 0) + len;
    addedQty = len;
    logLength = len;
  } else {
    const q = Number(quantity);
    if (!(q > 0)) throw new ApiError(400, 'A positive quantity is required.');
    addedQty = q;
  }

  product.quantity = Number(product.quantity || 0) + addedQty;
  await product.save();

  await InventoryLog.create({
    shop: product.shop,
    product: product._id,
    productName: product.name,
    actionType: 'stock_in',
    quantity: Math.round(addedQty),
    previousStock,
    newStock: product.quantity,
    supplier: supplier || '',
    reason: notes || 'Stock In',
    reference: req.body.reference || '',
    date: date || new Date(),
    performedBy: req.user._id,
    carpetPieces: logPieces,
    qaleenSizes: logSizes,
    length: logLength,
  });

  await recordAudit(req, {
    actionType: 'STOCK_IN',
    module: 'inventory',
    recordId: product._id,
    recordType: 'Product',
    oldData: { quantity: previousStock },
    newData: {
      quantity: product.quantity,
      stockIn: Math.round(addedQty),
      carpetPieces: logPieces.length ? logPieces : undefined,
      qaleenSizes: logSizes.length ? logSizes : undefined,
      length: logLength || undefined,
    },
    remarks: `Stock in ${Math.round(addedQty)} x "${product.name}"`,
    shopId: product.shop,
  });

  res.status(201).json(ApiResponse.created('Stock added successfully', { product }));
});

const stockOut = asyncHandler(async (req, res) => {
  const { productId, quantity, reason, date, notes, carpetPieces, qaleenSizes, length } = req.body;
  if (!productId) {
    throw new ApiError(400, 'Product is required.');
  }

  const product = await Product.findById(productId);
  if (!product || product.isDeleted) throw new ApiError(404, 'Product not found.');
  assertShopAccess(product, req.user);

  const previousStock = product.quantity;
  const pt = product.productType || 'qaleen';
  let removedQty = 0;
  let logPieces = [];
  let logSizes = [];
  let logLength = 0;

  if (pt === 'carpet') {
    const requested = normalizeCarpetPieces(carpetPieces);
    if (requested.length === 0) {
      const q = Number(quantity);
      if (!(q > 0)) throw new ApiError(400, 'A positive quantity or piece details are required.');
      if (product.quantity < q) {
        throw new ApiError(400, `Insufficient stock. Only ${product.quantity} available.`);
      }
      removedQty = q;
    } else {
      requested.forEach((p) => {
        const idx = product.carpetPiecesData.findIndex((x) => matchesPiece(x, p));
        if (idx < 0) {
          throw new ApiError(400, `No ${p.width}m x ${p.height}m piece available in stock.`);
        }
        const removed = product.carpetPiecesData.splice(idx, 1)[0];
        removedQty += Number(removed.area) || p.area;
        logPieces.push({
          width: Number(removed.width),
          height: Number(removed.height),
          area: Number(removed.area) || p.area,
          color: String(removed.color || ''),
          image: String(removed.image || ''),
        });
      });
      product.carpetPieces = product.carpetPiecesData.length;
    }
  } else if (pt === 'qaleen') {
    const requested = normalizeQaleenSizes(qaleenSizes);
    if (requested.length === 0) {
      const q = Number(quantity);
      if (!(q > 0)) throw new ApiError(400, 'A positive quantity or size details are required.');
      if (product.quantity < q) {
        throw new ApiError(400, `Insufficient stock. Only ${product.quantity} available.`);
      }
      removedQty = q;
    } else {
      requested.forEach((s) => {
        const key = sizeKey(s);
        const idx = product.qaleenSizes.findIndex((x) => sizeKey(x) === key);
        if (idx < 0) {
          throw new ApiError(400, `Size ${s.height}m x ${s.width}m not found in stock.`);
        }
        if (product.qaleenSizes[idx].pieces < s.pieces) {
          throw new ApiError(
            400,
            `Insufficient pieces for size ${s.height}m x ${s.width}m. Only ${product.qaleenSizes[idx].pieces} available.`
          );
        }
        product.qaleenSizes[idx].pieces -= s.pieces;
        if (product.qaleenSizes[idx].pieces === 0) product.qaleenSizes.splice(idx, 1);
        logSizes.push({ height: s.height, width: s.width, pieces: s.pieces });
        removedQty += s.pieces;
      });
    }
  } else if (pt === 'meter') {
    const len = Number(length);
    if (!(len > 0)) {
      const q = Number(quantity);
      if (!(q > 0)) throw new ApiError(400, 'A positive length or quantity is required.');
      if (product.meterLength < q) {
        throw new ApiError(400, `Insufficient length. Only ${product.meterLength}m available.`);
      }
      product.meterLength -= q;
      removedQty = q;
      logLength = q;
    } else {
      if (product.meterLength < len) {
        throw new ApiError(400, `Insufficient length. Only ${product.meterLength}m available.`);
      }
      product.meterLength -= len;
      removedQty = len;
      logLength = len;
    }
  } else {
    const q = Number(quantity);
    if (!(q > 0)) throw new ApiError(400, 'A positive quantity is required.');
    if (product.quantity < q) {
      throw new ApiError(400, `Insufficient stock. Only ${product.quantity} available.`);
    }
    removedQty = q;
  }

  product.quantity = Math.max(0, Number(product.quantity || 0) - removedQty);
  await product.save();

  await InventoryLog.create({
    shop: product.shop,
    product: product._id,
    productName: product.name,
    actionType: 'stock_out',
    quantity: Math.round(removedQty),
    previousStock,
    newStock: product.quantity,
    reason: reason || notes || 'Stock Out',
    reference: req.body.reference || '',
    date: date || new Date(),
    performedBy: req.user._id,
    carpetPieces: logPieces,
    qaleenSizes: logSizes,
    length: logLength,
  });

  await recordAudit(req, {
    actionType: 'STOCK_OUT',
    module: 'inventory',
    recordId: product._id,
    recordType: 'Product',
    oldData: { quantity: previousStock },
    newData: {
      quantity: product.quantity,
      stockOut: Math.round(removedQty),
      carpetPieces: logPieces.length ? logPieces : undefined,
      qaleenSizes: logSizes.length ? logSizes : undefined,
      length: logLength || undefined,
    },
    remarks: `Stock out ${Math.round(removedQty)} x "${product.name}"${reason ? ` - ${reason}` : ''}`,
    shopId: product.shop,
  });

  await maybeNotifyLowStock(product, req.user);

  res.status(201).json(ApiResponse.created('Stock removed successfully', { product }));
});

const transferStock = asyncHandler(async (req, res) => {
  const { fromShopId, toShopId, productId, quantity, date, notes, carpetPieces, qaleenSizes, length } = req.body;
  if (!fromShopId || !toShopId || !productId) {
    throw new ApiError(400, 'Source shop, destination shop and product are required.');
  }
  if (fromShopId === toShopId) {
    throw new ApiError(400, 'Source and destination shops must be different.');
  }

  const [fromShop, toShop] = await Promise.all([
    Shop.findById(fromShopId),
    Shop.findById(toShopId),
  ]);
  if (!fromShop || fromShop.isDeleted) throw new ApiError(404, 'Source shop not found.');
  if (!toShop || toShop.isDeleted) throw new ApiError(404, 'Destination shop not found.');

  // Managers may only transfer when their assigned shop is one of the two
  // endpoints (push stock out of their branch or pull stock into it).
  if (req.user.role === 'manager') {
    const mine = req.user.assignedShop._id.toString();
    const from = fromShop._id.toString();
    const to = toShop._id.toString();
    if (from !== mine && to !== mine) {
      throw new ApiError(403, 'Transfers must involve your assigned shop.');
    }
  }

  const fromProduct = await Product.findOne({ _id: productId, shop: fromShopId, isDeleted: false });
  if (!fromProduct) throw new ApiError(404, 'Source product not found in the selected shop.');

  const pt = fromProduct.productType || 'qaleen';
  let moveQty = 0;
  let movedPieces = [];
  let movedSizes = [];
  let movedLength = 0;

  if (pt === 'carpet') {
    const requested = normalizeCarpetPieces(carpetPieces);
    if (requested.length === 0) {
      const q = Number(quantity);
      if (!(q > 0)) throw new ApiError(400, 'A positive quantity or piece details are required.');
      if (fromProduct.quantity < q) {
        throw new ApiError(400, `Insufficient stock. Only ${fromProduct.quantity} available in "${fromProduct.name}" at ${fromShop.name}.`);
      }
      moveQty = q;
    } else {
      requested.forEach((p) => {
        const idx = fromProduct.carpetPiecesData.findIndex((x) => matchesPiece(x, p));
        if (idx < 0) {
          throw new ApiError(400, `No ${p.width}m x ${p.height}m piece available in "${fromProduct.name}" at ${fromShop.name}.`);
        }
        const removed = fromProduct.carpetPiecesData.splice(idx, 1)[0];
        const area = Number(removed.area) || p.area;
        movedPieces.push({
          width: Number(removed.width),
          height: Number(removed.height),
          area,
          color: String(removed.color || ''),
          image: String(removed.image || ''),
        });
        moveQty += area;
      });
      fromProduct.carpetPieces = fromProduct.carpetPiecesData.length;
    }
  } else if (pt === 'qaleen') {
    const requested = normalizeQaleenSizes(qaleenSizes);
    if (requested.length === 0) {
      const q = Number(quantity);
      if (!(q > 0)) throw new ApiError(400, 'A positive quantity or size details are required.');
      if (fromProduct.quantity < q) {
        throw new ApiError(400, `Insufficient stock. Only ${fromProduct.quantity} available in "${fromProduct.name}" at ${fromShop.name}.`);
      }
      moveQty = q;
    } else {
      requested.forEach((s) => {
        const key = sizeKey(s);
        const idx = fromProduct.qaleenSizes.findIndex((x) => sizeKey(x) === key);
        if (idx < 0) {
          throw new ApiError(400, `Size ${s.height}m x ${s.width}m not found in "${fromProduct.name}" at ${fromShop.name}.`);
        }
        if (fromProduct.qaleenSizes[idx].pieces < s.pieces) {
          throw new ApiError(
            400,
            `Insufficient pieces for size ${s.height}m x ${s.width}m. Only ${fromProduct.qaleenSizes[idx].pieces} available.`
          );
        }
        fromProduct.qaleenSizes[idx].pieces -= s.pieces;
        if (fromProduct.qaleenSizes[idx].pieces === 0) fromProduct.qaleenSizes.splice(idx, 1);
        movedSizes.push({ height: s.height, width: s.width, pieces: s.pieces });
        moveQty += s.pieces;
      });
    }
  } else if (pt === 'meter') {
    const len = Number(length);
    if (!(len > 0)) {
      const q = Number(quantity);
      if (!(q > 0)) throw new ApiError(400, 'A positive length or quantity is required.');
      if (fromProduct.meterLength < q) {
        throw new ApiError(400, `Insufficient length. Only ${fromProduct.meterLength}m available in "${fromProduct.name}" at ${fromShop.name}.`);
      }
      fromProduct.meterLength -= q;
      moveQty = q;
      movedLength = q;
    } else {
      if (fromProduct.meterLength < len) {
        throw new ApiError(400, `Insufficient length. Only ${fromProduct.meterLength}m available in "${fromProduct.name}" at ${fromShop.name}.`);
      }
      fromProduct.meterLength -= len;
      moveQty = len;
      movedLength = len;
    }
  } else {
    const q = Number(quantity);
    if (!(q > 0)) throw new ApiError(400, 'A positive quantity is required.');
    if (fromProduct.quantity < q) {
      throw new ApiError(400, `Insufficient stock. Only ${fromProduct.quantity} available in "${fromProduct.name}" at ${fromShop.name}.`);
    }
    moveQty = q;
  }

  if (!(moveQty > 0)) throw new ApiError(400, 'Nothing to transfer.');

  fromProduct.quantity = Math.max(0, Number(fromProduct.quantity || 0) - moveQty);

  // Resolve the matching product in the destination shop (by name). If it does
  // not exist yet, create it so stock moves against the same logical product.
  let toProduct = await Product.findOne({
    shop: toShopId,
    name: fromProduct.name,
    isDeleted: false,
  });
  let destinationCreated = false;
  if (!toProduct) {
    const short = toShop.name.replace(/\s+/g, '').slice(0, 12);
    toProduct = await Product.create({
      name: fromProduct.name,
      sku: fromProduct.sku ? `${short}-${fromProduct.sku}` : '',
      barcode: fromProduct.barcode,
      category: fromProduct.category,
      brand: fromProduct.brand,
      supplier: fromProduct.supplier,
      productType: fromProduct.productType,
      carpetWidth: 0,
      carpetHeight: 0,
      carpetPieces: 0,
      costPerSqft: fromProduct.costPerSqft,
      costPerPiece: fromProduct.costPerPiece,
      qaleenSizes: [],
      meterLength: 0,
      costPerMeter: fromProduct.costPerMeter,
      costPrice: fromProduct.costPrice,
      sellingPrice: fromProduct.sellingPrice,
      quantity: 0,
      lowStockThreshold: fromProduct.lowStockThreshold,
      color: fromProduct.color,
      size: fromProduct.size,
      description: fromProduct.description,
      images: fromProduct.images,
      shop: toShopId,
    });
    destinationCreated = true;
  }

  // Apply the moved stock to the destination product (dimension-aware).
  if (pt === 'carpet') {
    if (movedPieces.length > 0) {
      promoteLegacyCarpet(toProduct);
      toProduct.carpetPiecesData.push(...movedPieces);
      toProduct.carpetPieces = toProduct.carpetPiecesData.length;
    }
    toProduct.quantity = Number(toProduct.quantity || 0) + moveQty;
  } else if (pt === 'qaleen') {
    movedSizes.forEach((s) => {
      const key = sizeKey(s);
      const idx = toProduct.qaleenSizes.findIndex((x) => sizeKey(x) === key);
      if (idx >= 0) toProduct.qaleenSizes[idx].pieces += s.pieces;
      else toProduct.qaleenSizes.push(s);
    });
    toProduct.quantity = Number(toProduct.quantity || 0) + moveQty;
  } else if (pt === 'meter') {
    toProduct.meterLength = Number(toProduct.meterLength || 0) + moveQty;
    toProduct.quantity = Number(toProduct.quantity || 0) + moveQty;
  } else {
    toProduct.quantity = Number(toProduct.quantity || 0) + moveQty;
  }

  await Promise.all([fromProduct.save(), toProduct.save()]);

  await InventoryLog.create([
    {
      shop: fromProduct.shop,
      product: fromProduct._id,
      productName: fromProduct.name,
      actionType: 'stock_out',
      quantity: Math.round(moveQty),
      previousStock: fromProduct.quantity + moveQty,
      newStock: fromProduct.quantity,
      reason: notes || `Transferred to ${toShop.name}`,
      reference: req.body.reference || '',
      date: date || new Date(),
      performedBy: req.user._id,
      carpetPieces: movedPieces,
      qaleenSizes: movedSizes,
      length: movedLength,
    },
    {
      shop: toProduct.shop,
      product: toProduct._id,
      productName: toProduct.name,
      actionType: 'stock_in',
      quantity: Math.round(moveQty),
      previousStock: toProduct.quantity - moveQty,
      newStock: toProduct.quantity,
      supplier: '',
      reason: notes || `Transferred from ${fromShop.name}`,
      reference: req.body.reference || '',
      date: date || new Date(),
      performedBy: req.user._id,
      carpetPieces: movedPieces,
      qaleenSizes: movedSizes,
      length: movedLength,
    },
  ]);

  await recordAudit(req, {
    actionType: 'STOCK_TRANSFER',
    module: 'inventory',
    recordId: fromProduct._id,
    recordType: 'Product',
    oldData: { fromQuantity: fromProduct.quantity + moveQty, toQuantity: toProduct.quantity - moveQty },
    newData: {
      fromQuantity: fromProduct.quantity,
      toQuantity: toProduct.quantity,
      transferred: Math.round(moveQty),
      carpetPieces: movedPieces.length ? movedPieces : undefined,
      qaleenSizes: movedSizes.length ? movedSizes : undefined,
      length: movedLength || undefined,
    },
    remarks: `Transferred ${Math.round(moveQty)} x "${fromProduct.name}" from ${fromShop.name} to ${toShop.name}`,
    shopId: fromProduct.shop,
  });

  await maybeNotifyLowStock(fromProduct, req.user);

  res.status(201).json(
    ApiResponse.created('Stock transferred successfully', {
      from: fromProduct,
      to: toProduct,
      fromShop: { id: fromShop._id, name: fromShop.name },
      toShop: { id: toShop._id, name: toShop.name },
      destinationCreated,
    })
  );
});

// Active shops a transfer can involve. Managers need the full list because a
// transfer may either start or end at any location (branch <-> warehouse).
const transferShops = asyncHandler(async (req, res) => {
  const shops = await Shop.find({ isDeleted: false }).sort({ createdAt: 1 });
  res.json(
    ApiResponse.ok(
      'Transfer shops fetched',
      shops.map((s) => ({ id: s._id, name: s.name, address: s.address || '' }))
    )
  );
});

// Products of a given shop, used to build the source-product dropdown of the
// transfer form when transferring from another location.
const shopProducts = asyncHandler(async (req, res) => {
  const shopId = req.params.shopId;
  if (!require('mongoose').Types.ObjectId.isValid(shopId)) {
    throw new ApiError(400, 'Invalid shop id.');
  }
  const products = await Product.find({ shop: shopId, isDeleted: false })
    .populate('category', 'name')
    .sort({ createdAt: 1 })
    .select(
      'name sku quantity sellingPrice costPrice category lowStockThreshold productType images ' +
        'carpetPiecesData carpetWidth carpetHeight carpetPieces costPerSqft ' +
        'qaleenSizes costPerPiece meterLength costPerMeter color size'
    );
  res.json(ApiResponse.ok('Shop products fetched', products));
});

const inventoryHistory = asyncHandler(async (req, res) => {
  const page = parseInt(req.query.page, 10) || 1;
  const limit = parseInt(req.query.limit, 10) || 30;
  const filter = {};
  if (req.user.role === 'manager') filter.shop = req.user.assignedShop._id;
  else if (req.shopId) filter.shop = req.shopId;
  if (req.query.actionType) filter.actionType = req.query.actionType;
  if (req.query.productId) filter.product = req.query.productId;
  if (req.query.from || req.query.to) {
    filter.date = {};
    if (req.query.from) filter.date.$gte = new Date(req.query.from);
    if (req.query.to) filter.date.$lte = new Date(req.query.to);
  }

  const [logs, total] = await Promise.all([
    InventoryLog.find(filter)
      .populate('performedBy', 'name role')
      .populate('shop', 'name')
      .sort({ date: -1 })
      .skip((page - 1) * limit)
      .limit(limit),
    InventoryLog.countDocuments(filter),
  ]);

  res.json(ApiResponse.ok('Inventory history fetched', { logs, total, page, limit, totalPages: Math.ceil(total / limit) }));
});

module.exports = { stockIn, stockOut, transferStock, transferShops, shopProducts, inventoryHistory };
