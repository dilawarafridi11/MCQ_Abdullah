const Shop = require('../models/Shop');
const Product = require('../models/Product');
const Sale = require('../models/Sale');
const Customer = require('../models/Customer');
const Supplier = require('../models/Supplier');
const InventoryLog = require('../models/InventoryLog');
const AuditLog = require('../models/AuditLog');
const asyncHandler = require('../utils/asyncHandler');
const ApiResponse = require('../utils/ApiResponse');
const stats = require('../utils/stats');

const getDashboard = asyncHandler(async (req, res) => {
  const isAdmin = req.user.role === 'admin';
  const shopId = isAdmin ? (req.shopId || null) : req.user.assignedShop._id;

  const shopFilter = { isDeleted: false };
  if (shopId) shopFilter._id = shopId;
  const productFilter = { isDeleted: false };
  if (shopId) productFilter.shop = shopId;

  const [shops, productCount, stockValue, lowStockAgg] = await Promise.all([
    Shop.find(shopFilter).populate('manager', 'name'),
    Product.countDocuments(productFilter),
    Product.aggregate([
      { $match: productFilter },
      { $group: { _id: null, value: { $sum: { $multiply: ['$quantity', '$costPrice'] } } } },
    ]),
    Product.aggregate([
      { $match: productFilter },
      { $match: { $expr: { $lte: ['$quantity', '$lowStockThreshold'] } } },
      { $count: 'count' },
    ]),
  ]);

  const lowStockCount = lowStockAgg[0]?.count || 0;

  if (!isAdmin) {
    return res.json(
      ApiResponse.ok('Dashboard data fetched', await buildManagerPayload(req, shopId, productCount, lowStockCount))
    );
  }

  const [todaySales, todayExpenses, monthSales, monthExpenses, yearSales, yearExpenses] = await Promise.all([
    stats.getSalesTotal(stats.dateRange('today'), shopId),
    stats.getExpenseTotal(stats.dateRange('today'), shopId),
    stats.getSalesTotal(stats.dateRange('month'), shopId),
    stats.getExpenseTotal(stats.dateRange('month'), shopId),
    stats.getSalesTotal(stats.dateRange('year'), shopId),
    stats.getExpenseTotal(stats.dateRange('year'), shopId),
  ]);

  const [daily, weekly, monthly, yearly, topProducts, topCustomers] = await Promise.all([
    stats.dailySeries(shopId, 14),
    stats.weeklySeries(shopId, 12),
    stats.monthlySeries(shopId, 12),
    stats.yearlySeries(shopId, 5),
    stats.topProducts(shopId, 30, 5),
    buildTopCustomers(shopId, 5),
  ]);

  const comparison = await stats.shopComparison(shops);

  const expenseBreakdown = await stats.expenseBreakdown(shopId, 30);

  const lowStock = await Product.find({
    ...productFilter,
    $expr: { $lte: ['$quantity', '$lowStockThreshold'] },
  })
    .select('name sku quantity lowStockThreshold sellingPrice')
    .sort({ quantity: 1 })
    .limit(20);

  const activityFilter = {};
  if (shopId) activityFilter.shopId = shopId;
  const recentLogs = await AuditLog.find(activityFilter)
    .sort({ timestamp: -1 })
    .limit(8)
    .select('actionType remarks timestamp performedByName shopName');

  res.json(
    ApiResponse.ok('Dashboard data fetched', {
      role: 'admin',
      cards: {
        totalShops: shops.length,
        totalProducts: productCount,
        totalStockValue: stockValue[0]?.value || 0,
        lowStockCount,
        salesToday: todaySales.total,
        salesTodayCount: todaySales.count,
        expensesToday: todayExpenses.total,
        monthlyRevenue: monthSales.total,
        monthlyProfit: monthSales.profit - monthExpenses.total,
        monthlyExpenses: monthExpenses.total,
        yearlyRevenue: yearSales.total,
        yearlyProfit: yearSales.profit - yearExpenses.total,
        yearlyExpenses: yearExpenses.total,
      },
      charts: { daily, weekly, monthly, yearly, comparison, expenseBreakdown },
      topProducts,
      topCustomers,
      lowStock: lowStock.map((p) => ({
        id: p._id,
        name: p.name,
        sku: p.sku,
        quantity: p.quantity,
        lowStockThreshold: p.lowStockThreshold,
        sellingPrice: p.sellingPrice,
      })),
      recentActivity: recentLogs.map((l) => ({
        type: l.actionType,
        title: l.remarks || l.actionType,
        subtitle: l.shopName || (l.performedByName || ''),
        time: l.timestamp,
      })),
      shops: shops.map((s) => ({ id: s._id, name: s.name, manager: s.manager?.name || '—' })),
    })
  );
});

// Manager payload — operational KPIs only. No revenue, profit, expenses or
// financial charts are exposed to managers.
const buildManagerPayload = async (req, shopId, productCount, lowStockCount) => {
  const shop = req.user.assignedShop;

  const [todaySales, customerCount, supplierCount, lowStock, inventoryLogs, auditLogs, productList] = await Promise.all([
    stats.getSalesTotal(stats.dateRange('today'), shopId),
    Customer.countDocuments({ isDeleted: false, shop: shopId }),
    Supplier.countDocuments({ isDeleted: false, shop: shopId }),
    Product.find({
      isDeleted: false,
      shop: shopId,
      $expr: { $lte: ['$quantity', '$lowStockThreshold'] },
    })
      .select('name sku quantity lowStockThreshold sellingPrice')
      .sort({ quantity: 1 })
      .limit(50),
    InventoryLog.find({ shop: shopId })
      .populate('performedBy', 'name')
      .sort({ date: -1 })
      .limit(10)
      .select('actionType quantity productName date performedBy reason'),
    AuditLog.find({ shopId })
      .sort({ timestamp: -1 })
      .limit(10)
      .select('actionType remarks timestamp performedByName'),
    Product.find({ isDeleted: false, shop: shopId })
      .select('name sku barcode size images colorStocks quantity lowStockThreshold productType')
      .sort({ createdAt: -1 })
      .limit(50),
  ]);

  const recentActivity = [
    ...inventoryLogs.map((l) => ({
      type: l.actionType,
      title: l.actionType === 'STOCK_IN'
          ? `Stock in · ${l.productName}`
          : `Stock out · ${l.productName}`,
      subtitle: `${l.quantity} units${l.reason ? ` · ${l.reason}` : ''} · ${l.performedBy?.name || ''}`,
      time: l.date,
    })),
    ...auditLogs.map((l) => ({
      type: l.actionType,
      title: l.remarks || l.actionType,
      subtitle: l.performedByName || '',
      time: l.timestamp,
    })),
  ].sort((a, b) => new Date(b.time).getTime() - new Date(a.time).getTime());

  return {
    role: 'manager',
    cards: {
      totalProducts: productCount,
      lowStockCount,
      todayOrders: todaySales.count,
      salesToday: todaySales.total,
      supplierCount,
      customerCount,
      stockInToday: await countStockAction(shopId, 'STOCK_IN'),
      stockOutToday: await countStockAction(shopId, 'STOCK_OUT'),
    },
    lowStock: lowStock.map((p) => ({
      id: p._id,
      name: p.name,
      sku: p.sku,
      quantity: p.quantity,
      lowStockThreshold: p.lowStockThreshold,
      sellingPrice: p.sellingPrice,
    })),
    recentActivity,
    branch: shop
      ? { id: shop._id, name: shop.name, address: shop.address || '' }
      : null,
    products: productList.map((p) => ({
      id: p._id,
      name: p.name,
      code: p.sku || p.barcode || '',
      size: p.size || '',
      image: Array.isArray(p.images) && p.images[0] ? p.images[0] : '',
      quantity: p.quantity,
      lowStockThreshold: p.lowStockThreshold,
      productType: p.productType,
      colorStocks: (p.colorStocks || []).map((c) => ({
        color: c.color,
        sets: c.sets,
        pieces: c.pieces,
      })),
    })),
  };
};

const countStockAction = async (shopId, actionType) => {
  const range = stats.dateRange('today');
  const res = await InventoryLog.aggregate([
    {
      $match: {
        shop: shopId,
        actionType,
        date: { $gte: range.from, $lte: range.to },
      },
    },
    { $group: { _id: null, count: { $sum: 1 }, qty: { $sum: '$quantity' } } },
  ]);
  return res[0]?.count || 0;
};

const buildTopCustomers = async (shopId, limit = 5) => {
  const filter = { isDeleted: false };
  if (shopId) filter.shop = shopId;
  const res = await Sale.aggregate([
    { $match: filter },
    {
      $group: {
        _id: {
          name: { $ifNull: ['$customerName', 'Walk-in Customer'] },
          phone: { $ifNull: ['$customerPhone', ''] },
        },
        total: { $sum: '$totalAmount' },
        count: { $sum: 1 },
      },
    },
    { $sort: { total: -1 } },
    { $limit: limit },
  ]);
  return res.map((r) => ({
    name: r._id.name,
    phone: r._id.phone,
    total: r.total,
    orders: r.count,
  }));
};

module.exports = { getDashboard };
