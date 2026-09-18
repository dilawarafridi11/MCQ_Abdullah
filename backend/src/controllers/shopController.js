const Shop = require('../models/Shop');
const User = require('../models/User');
const Product = require('../models/Product');
const Sale = require('../models/Sale');
const Expense = require('../models/Expense');
const Customer = require('../models/Customer');
const Supplier = require('../models/Supplier');
const stats = require('../utils/stats');
const ApiError = require('../utils/ApiError');
const asyncHandler = require('../utils/asyncHandler');
const ApiResponse = require('../utils/ApiResponse');
const { recordAudit } = require('../middleware/auth');

const listShops = asyncHandler(async (req, res) => {
  if (req.user.role === 'manager') {
    const shop = await Shop.findById(req.user.assignedShop._id).populate('manager', 'name email phone');
    if (!shop || shop.isDeleted) throw new ApiError(404, 'Assigned shop not found.');
    return res.json(ApiResponse.ok('Shop fetched', [shop]));
  }
  const shops = await Shop.find({ isDeleted: false })
    .populate('manager', 'name email phone')
    .sort({ createdAt: 1 });
  res.json(ApiResponse.ok('Shops fetched', shops));
});

const getShop = asyncHandler(async (req, res) => {
  const shop = await Shop.findById(req.params.id).populate('manager', 'name email phone');
  if (!shop || shop.isDeleted) throw new ApiError(404, 'Shop not found.');
  if (req.user.role === 'manager' && req.user.assignedShop._id.toString() !== shop._id.toString()) {
    throw new ApiError(403, 'You can only view your assigned shop.');
  }
  res.json(ApiResponse.ok('Shop fetched', shop));
});

// Admin-only branch command center. Bundles everything an owner needs to run a
// single branch: KPIs, receivables, staff, customers (top by balance) and
// products (top by stock value), plus the latest sales and expenses.
const getShopOverview = asyncHandler(async (req, res) => {
  const shop = await Shop.findById(req.params.id).populate('manager', 'name email phone');
  if (!shop || shop.isDeleted) throw new ApiError(404, 'Shop not found.');
  const shopId = shop._id;

  const productFilter = { isDeleted: false, shop: shopId };
  const [productCount, customerCount, lowStockAgg, stockValueAgg, receivablesAgg, supplierCount, saleStats, expenseStats] =
    await Promise.all([
      Product.countDocuments(productFilter),
      Customer.countDocuments({ isDeleted: false, shop: shopId }),
      Product.aggregate([
        { $match: productFilter },
        { $match: { $expr: { $lte: ['$quantity', '$lowStockThreshold'] } } },
        { $count: 'count' },
      ]),
      Product.aggregate([
        { $match: productFilter },
        { $group: { _id: null, value: { $sum: { $multiply: ['$quantity', '$costPrice'] } } } },
      ]),
      Customer.aggregate([
        { $match: { isDeleted: false, shop: shopId } },
        { $group: { _id: null, total: { $sum: '$balance' } } },
      ]),
      Supplier.countDocuments({ isDeleted: false, shop: shopId }),
      Promise.all([
        stats.getSalesTotal(stats.dateRange('today'), shopId),
        stats.getSalesTotal(stats.dateRange('month'), shopId),
      ]),
      stats.getExpenseTotal(stats.dateRange('month'), shopId),
    ]);

  const [todaySales, monthSales] = saleStats;
  const lowStockCount = lowStockAgg[0]?.count || 0;
  const receivables = receivablesAgg[0]?.total || 0;

  const [customers, products, lowStock, recentSales, recentExpenses, managers] = await Promise.all([
    Customer.find({ isDeleted: false, shop: shopId })
      .select('name phone balance totalSpent purchaseCount lastPurchaseAt')
      .sort({ balance: -1 })
      .limit(8),
    Product.aggregate([
      { $match: productFilter },
      {
        $project: {
          name: 1,
          sku: 1,
          productType: 1,
          quantity: 1,
          costPrice: 1,
          lowStockThreshold: 1,
          stockValue: { $multiply: ['$quantity', '$costPrice'] },
        },
      },
      { $sort: { stockValue: -1 } },
      { $limit: 12 },
    ]),
    Product.find({
      ...productFilter,
      $expr: { $lte: ['$quantity', '$lowStockThreshold'] },
    })
      .select('name sku quantity lowStockThreshold')
      .sort({ quantity: 1 })
      .limit(5),
    Sale.find({ shop: shopId, isDeleted: false })
      .sort({ createdAt: -1 })
      .limit(7)
      .select('invoiceNo customerName totalAmount paidAmount dueAmount createdAt notes'),
    Expense.find({ shop: shopId, isDeleted: false })
      .sort({ expenseDate: -1 })
      .limit(6)
      .select('category amount expenseDate description'),
    User.find({ role: 'manager', assignedShop: shopId, isActive: true }).select('name email phone'),
  ]);

  res.json(
    ApiResponse.ok('Shop overview fetched', {
      shop: {
        id: shop._id.toString(),
        name: shop.name,
        address: shop.address || '',
        contactNumber: shop.contactNumber || '',
        managerName: shop.manager?.name || '—',
        managerEmail: shop.manager?.email || '',
        managerPhone: shop.manager?.phone || '',
      },
      cards: {
        totalProducts: productCount,
        totalStockValue: stockValueAgg[0]?.value || 0,
        lowStockCount,
        customerCount,
        supplierCount,
        receivables,
        salesToday: todaySales.total,
        salesTodayCount: todaySales.count,
        monthlyRevenue: monthSales.total,
        monthlyProfit: monthSales.profit - expenseStats.total,
        monthlyExpenses: expenseStats.total,
      },
      customers: customers.map((c) => ({
        id: c._id.toString(),
        name: c.name,
        phone: c.phone || '',
        balance: c.balance,
        totalSpent: c.totalSpent,
        purchaseCount: c.purchaseCount,
        lastPurchaseAt: c.lastPurchaseAt,
      })),
      products: products.map((p) => ({
        id: p._id.toString(),
        name: p.name,
        sku: p.sku || '',
        productType: p.productType,
        quantity: p.quantity,
        costPrice: p.costPrice,
        stockValue: p.stockValue,
        lowStockThreshold: p.lowStockThreshold,
        isLowStock: p.quantity <= p.lowStockThreshold,
      })),
      lowStock: lowStock.map((p) => ({
        id: p._id.toString(),
        name: p.name,
        sku: p.sku || '',
        quantity: p.quantity,
        lowStockThreshold: p.lowStockThreshold,
      })),
      recentSales: recentSales.map((s) => ({
        id: s._id.toString(),
        invoiceNo: s.invoiceNo,
        customerName: s.customerName,
        totalAmount: s.totalAmount,
        paidAmount: s.paidAmount,
        dueAmount: s.dueAmount,
        createdAt: s.createdAt,
      })),
      recentExpenses: recentExpenses.map((e) => ({
        id: e._id.toString(),
        category: e.category,
        amount: e.amount,
        date: e.expenseDate,
        description: e.description || '',
      })),
      managers: managers.map((m) => ({ name: m.name, email: m.email || '', phone: m.phone || '' })),
    })
  );
});

const createShop = asyncHandler(async (req, res) => {
  const { name, address, contactNumber, manager } = req.body;
  if (!name) throw new ApiError(400, 'Shop name is required.');

  const shop = await Shop.create({ name, address, contactNumber, manager });

  if (manager) {
    await User.findByIdAndUpdate(manager, { $set: { assignedShop: shop._id } });
  }

  await recordAudit(req, {
    actionType: 'CREATE_USER',
    module: 'shops',
    recordId: shop._id,
    recordType: 'Shop',
    newData: shop.toObject(),
    remarks: `Shop "${shop.name}" created`,
  });

  res.status(201).json(ApiResponse.created('Shop created', shop));
});

const updateShop = asyncHandler(async (req, res) => {
  const shop = await Shop.findById(req.params.id);
  if (!shop || shop.isDeleted) throw new ApiError(404, 'Shop not found.');
  const oldData = shop.toObject();

  const { name, address, contactNumber, manager } = req.body;
  if (name !== undefined) shop.name = name;
  if (address !== undefined) shop.address = address;
  if (contactNumber !== undefined) shop.contactNumber = contactNumber;
  if (manager !== undefined) shop.manager = manager;
  await shop.save();

  if (manager !== undefined) {
    const previous = await Shop.findById(req.params.id);
    const prevManager = previous.manager;
    if (prevManager && prevManager.toString() !== manager.toString()) {
      await User.findByIdAndUpdate(prevManager, { $set: { assignedShop: null } });
    }
    await User.findByIdAndUpdate(manager, { $set: { assignedShop: shop._id } });
  }

  await recordAudit(req, {
    actionType: 'UPDATE_USER',
    module: 'shops',
    recordId: shop._id,
    recordType: 'Shop',
    oldData,
    newData: shop.toObject(),
    remarks: `Shop "${shop.name}" updated`,
  });

  res.json(ApiResponse.ok('Shop updated', shop));
});

const deleteShop = asyncHandler(async (req, res) => {
  const { deleteReason } = req.body;
  const shop = await Shop.findById(req.params.id);
  if (!shop) throw new ApiError(404, 'Shop not found.');

  const oldData = shop.toObject();
  shop.isDeleted = true;
  shop.deletedBy = req.user._id;
  shop.deletedAt = new Date();
  shop.deleteReason = deleteReason || '';
  await shop.save();

  await recordAudit(req, {
    actionType: 'DELETE_USER',
    module: 'shops',
    recordId: shop._id,
    recordType: 'Shop',
    oldData,
    newData: null,
    status: 'deleted',
    remarks: `Shop "${shop.name}" soft-deleted`,
  });

  res.json(ApiResponse.ok('Shop deleted'));
});

const restoreShop = asyncHandler(async (req, res) => {
  const shop = await Shop.findById(req.params.id);
  if (!shop) throw new ApiError(404, 'Shop not found.');

  shop.isDeleted = false;
  shop.deletedBy = null;
  shop.deletedAt = null;
  shop.deleteReason = '';
  await shop.save();

  await recordAudit(req, {
    actionType: 'RESTORE_PRODUCT',
    module: 'shops',
    recordId: shop._id,
    recordType: 'Shop',
    oldData: null,
    newData: shop.toObject(),
    status: 'restored',
    remarks: `Shop "${shop.name}" restored`,
  });

  res.json(ApiResponse.ok('Shop restored', shop));
});

module.exports = { listShops, getShop, getShopOverview, createShop, updateShop, deleteShop, restoreShop };
