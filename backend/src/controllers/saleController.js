const Sale = require('../models/Sale');
const Product = require('../models/Product');
const Notification = require('../models/Notification');
const ApiError = require('../utils/ApiError');
const asyncHandler = require('../utils/asyncHandler');
const ApiResponse = require('../utils/ApiResponse');
const { recordAudit } = require('../middleware/auth');

const generateInvoiceNo = async () => {
  const date = new Date();
  const y = date.getFullYear();
  const m = String(date.getMonth() + 1).padStart(2, '0');
  const d = String(date.getDate()).padStart(2, '0');
  const rand = Math.floor(1000 + Math.random() * 9000);
  let invoiceNo = `INV-${y}${m}${d}-${rand}`;
  while (await Sale.findOne({ invoiceNo })) {
    invoiceNo = `INV-${y}${m}${d}-${rand++}`;
  }
  return invoiceNo;
};

const listSales = asyncHandler(async (req, res) => {
  const page = parseInt(req.query.page, 10) || 1;
  const limit = parseInt(req.query.limit, 10) || 30;
  const filter = { isDeleted: false };
  if (req.user.role === 'manager') filter.shop = req.user.assignedShop._id;
  else if (req.shopId) filter.shop = req.shopId;
  if (req.query.from || req.query.to) {
    filter.createdAt = {};
    if (req.query.from) filter.createdAt.$gte = new Date(req.query.from);
    if (req.query.to) filter.createdAt.$lte = new Date(req.query.to);
  }
  if (req.query.paymentMethod) filter.paymentMethod = req.query.paymentMethod;

  const [sales, total] = await Promise.all([
    Sale.find(filter)
      .populate('shop', 'name')
      .populate('createdBy', 'name role')
      // Managers must not see profit margins or cost prices.
      .select(req.user.role === 'manager' ? '-profit -items.costPrice' : '')
      .sort({ createdAt: -1 })
      .skip((page - 1) * limit)
      .limit(limit),
    Sale.countDocuments(filter),
  ]);

  res.json(ApiResponse.ok('Sales fetched', { sales, total, page, limit, totalPages: Math.ceil(total / limit) }));
});

const getSale = asyncHandler(async (req, res) => {
  const sale = await Sale.findById(req.params.id)
    .populate('shop', 'name address contactNumber')
    .populate('createdBy', 'name role')
    .select(req.user.role === 'manager' ? '-profit -items.costPrice' : '');
  if (!sale || sale.isDeleted) throw new ApiError(404, 'Sale not found.');
  res.json(ApiResponse.ok('Sale fetched', sale));
});

const createSale = asyncHandler(async (req, res) => {
  const { customerName, customerPhone, items, discount, paymentMethod, notes, paidAmount } = req.body;
  if (!items || !Array.isArray(items) || items.length === 0) {
    throw new ApiError(400, 'At least one product item is required.');
  }

  const shopId =
    req.user.role === 'manager'
      ? req.user.assignedShop._id
      : req.body.shopId || (await require('../models/Shop').findOne({ isDeleted: false }))._id;
  if (!shopId) throw new ApiError(400, 'shopId is required.');

  const saleItems = [];
  let subtotal = 0;
  let profit = 0;

  for (const item of items) {
    const product = await Product.findById(item.productId).populate('category', 'name');
    if (!product || product.isDeleted) throw new ApiError(404, `Product not found for item.`);
    if (product.shop.toString() !== shopId.toString()) {
      throw new ApiError(400, `"${product.name}" does not belong to this shop.`);
    }
    const qty = Number(item.quantity);
    if (!qty || qty <= 0) throw new ApiError(400, 'Quantity must be positive.');
    if (product.quantity < qty) {
      throw new ApiError(400, `Insufficient stock for "${product.name}" (only ${product.quantity} left).`);
    }

    const unitPrice = item.unitPrice !== undefined ? Number(item.unitPrice) : product.sellingPrice;
    const itemTotal = qty * unitPrice;
    product.quantity -= qty;
    await product.save();

    saleItems.push({
      product: product._id,
      productName: product.name,
      quantity: qty,
      unitPrice,
      totalAmount: itemTotal,
      costPrice: product.costPrice,
    });
    subtotal += itemTotal;
    profit += (unitPrice - product.costPrice) * qty;
  }

  const discountValue = Number(discount) || 0;
  if (discountValue > subtotal) throw new ApiError(400, 'Discount cannot exceed subtotal.');

  const totalAmount = subtotal - discountValue;
  const paidValue = Math.min(Math.max(Number(paidAmount) || 0, 0), totalAmount);
  const dueValue = totalAmount - paidValue;

  const invoiceNo = await generateInvoiceNo();
  const sale = await Sale.create({
    invoiceNo,
    shop: shopId,
    customerName: customerName || 'Walk-in Customer',
    customerPhone: customerPhone || '',
    items: saleItems,
    subtotal,
    discount: discountValue,
    totalAmount,
    paidAmount: paidValue,
    dueAmount: dueValue,
    profit,
    paymentMethod: paymentMethod || 'cash',
    notes: notes || '',
    createdBy: req.user._id,
  });

  await recordAudit(req, {
    actionType: 'CREATE_SALE',
    module: 'sales',
    recordId: sale._id,
    recordType: 'Sale',
    newData: sale.toObject(),
    remarks: `Sale ${invoiceNo} created - Rs. ${sale.totalAmount}`,
    shopId,
  });

  // Notify admins about the new sale
  const User = require('../models/User');
  const admins = await User.find({ role: 'admin', isActive: true });
  await Notification.insertMany(
    admins.map((admin) => ({
      user: admin._id,
      title: 'New Sale',
      body: `New sale ${invoiceNo} of Rs. ${sale.totalAmount}`,
      type: 'new_sale',
      data: { saleId: sale._id, invoiceNo },
    }))
  );

  // Send the PDF receipt to the customer's WhatsApp number (if one is given
  // and WhatsApp is configured). Failures never affect the sale itself.
  const whatsappService = require('../services/whatsappService');
  sale.whatsappReceipt = await whatsappService.sendWhatsAppReceipt(sale, sale.customerPhone);

  // Link the sale to a registered customer (matched by phone) and update
  // their purchase history. Credit sales also increase the outstanding due.
  const phone = (sale.customerPhone || '').trim();
  if (phone) {
    const Customer = require('../models/Customer');
    const customer = await Customer.findOne({
      isDeleted: false,
      shop: shopId,
      phone: { $regex: `^${phone.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}$`, $options: 'i' },
    });
    if (customer) {
      customer.totalSpent += sale.totalAmount;
      customer.purchaseCount += 1;
      customer.lastPurchaseAt = new Date();
      if (sale.dueAmount > 0) {
        customer.balance += sale.dueAmount;
        customer.transactions.push({
          amount: sale.dueAmount,
          type: 'charge',
          note: `Sale ${invoiceNo} (paid ${paidValue}, due ${dueValue})`,
          date: new Date(),
          by: req.user._id,
        });
      }
      if (sale.paidAmount > 0) {
        customer.transactions.push({
          amount: sale.paidAmount,
          type: 'payment',
          note: `Payment received on sale ${invoiceNo}`,
          date: new Date(),
          by: req.user._id,
        });
      }
      await customer.save();
    }
  }

  res.status(201).json(ApiResponse.created('Sale created successfully', sale));
});

const updateSale = asyncHandler(async (req, res) => {
  const sale = await Sale.findById(req.params.id);
  if (!sale || sale.isDeleted) throw new ApiError(404, 'Sale not found.');
  if (req.user.role === 'manager' && sale.shop.toString() !== req.user.assignedShop._id.toString()) {
    throw new ApiError(403, 'You can only manage sales of your assigned shop.');
  }
  const oldData = sale.toObject();

  const allowed = ['customerName', 'customerPhone', 'discount', 'paymentMethod', 'notes'];
  allowed.forEach((field) => {
    if (req.body[field] !== undefined) sale[field] = req.body[field];
  });
  if (sale.discount > sale.subtotal) throw new ApiError(400, 'Discount cannot exceed subtotal.');
  sale.totalAmount = sale.subtotal - sale.discount;
  await sale.save();

  await recordAudit(req, {
    actionType: 'UPDATE_SALE',
    module: 'sales',
    recordId: sale._id,
    recordType: 'Sale',
    oldData,
    newData: sale.toObject(),
    remarks: `Sale ${sale.invoiceNo} updated`,
    shopId: sale.shop,
  });

  res.json(ApiResponse.ok('Sale updated', sale));
});

const deleteSale = asyncHandler(async (req, res) => {
  const { deleteReason, restock = false } = req.body;
  const sale = await Sale.findById(req.params.id);
  if (!sale) throw new ApiError(404, 'Sale not found.');
  if (req.user.role === 'manager' && sale.shop.toString() !== req.user.assignedShop._id.toString()) {
    throw new ApiError(403, 'You can only manage sales of your assigned shop.');
  }
  const oldData = sale.toObject();

  if (restock) {
    for (const item of sale.items) {
      await Product.findByIdAndUpdate(item.product, { $inc: { quantity: item.quantity } });
    }
  }

  sale.isDeleted = true;
  sale.deletedBy = req.user._id;
  sale.deletedAt = new Date();
  sale.deleteReason = deleteReason || '';
  await sale.save();

  await recordAudit(req, {
    actionType: 'DELETE_SALE',
    module: 'sales',
    recordId: sale._id,
    recordType: 'Sale',
    oldData,
    newData: null,
    status: 'deleted',
    remarks: `Sale ${sale.invoiceNo} soft-deleted${restock ? ' (restocked)' : ''}`,
    shopId: sale.shop,
  });

  res.json(ApiResponse.ok('Sale deleted'));
});

const restoreSale = asyncHandler(async (req, res) => {
  const sale = await Sale.findById(req.params.id);
  if (!sale) throw new ApiError(404, 'Sale not found.');

  sale.isDeleted = false;
  sale.deletedBy = null;
  sale.deletedAt = null;
  sale.deleteReason = '';
  await sale.save();

  await recordAudit(req, {
    actionType: 'RESTORE_SALE',
    module: 'sales',
    recordId: sale._id,
    recordType: 'Sale',
    oldData: null,
    newData: sale.toObject(),
    status: 'restored',
    remarks: `Sale ${sale.invoiceNo} restored`,
    shopId: sale.shop,
  });

  res.json(ApiResponse.ok('Sale restored', sale));
});

module.exports = { listSales, getSale, createSale, updateSale, deleteSale, restoreSale };
