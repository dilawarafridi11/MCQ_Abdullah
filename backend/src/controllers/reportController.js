const asyncHandler = require('../utils/asyncHandler');
const ApiResponse = require('../utils/ApiResponse');
const stats = require('../utils/stats');
const Sale = require('../models/Sale');
const Expense = require('../models/Expense');
const Product = require('../models/Product');
const InventoryLog = require('../models/InventoryLog');
const { recordAudit } = require('../middleware/auth');
const { Types } = require('mongoose');

const toObjectId = (v) => (v && Types.ObjectId.isValid(v) ? new Types.ObjectId(v) : null);

const resolveShop = (req, fallback) => {
  const shopId = req.user.role === 'manager' ? req.user.assignedShop._id : fallback || null;
  return toObjectId(shopId);
};

const buildReport = asyncHandler(async (req, res) => {
  const { period = 'month', shopId } = req.query;
  const scopedShopId = resolveShop(req, shopId);

  const range = stats.dateRange(period);

  const [sales, expenses, inventory] = await Promise.all([
    stats.getSalesTotal(range, scopedShopId),
    stats.getExpenseTotal(range, scopedShopId),
    Product.aggregate([
      { $match: { isDeleted: false, ...(scopedShopId ? { shop: scopedShopId } : {}) } },
      { $group: { _id: null, value: { $sum: { $multiply: ['$quantity', '$costPrice'] } }, count: { $sum: 1 } } },
    ]),
  ]);

  const report = {
    period,
    generatedAt: new Date().toISOString(),
    range,
    sales: { total: sales.total, count: sales.count },
    expenses: { total: expenses.total, count: expenses.count },
    profit: sales.total - expenses.total,
    inventory: {
      totalProducts: inventory[0]?.count || 0,
      stockValue: inventory[0]?.value || 0,
    },
  };

  await recordAudit(req, {
    actionType: 'REPORT_DOWNLOAD',
    module: 'reports',
    recordType: 'Report',
    newData: report,
    remarks: `Generated ${period} report`,
    shopId: scopedShopId || undefined,
  });

  res.json(ApiResponse.ok('Report generated', report));
});

const salesReport = asyncHandler(async (req, res) => {
  const { period = 'month', shopId } = req.query;
  const scopedShopId = resolveShop(req, shopId);
  const range = stats.dateRange(period);
  const filter = { isDeleted: false };
  if (scopedShopId) filter.shop = scopedShopId;
  if (range.from) filter.createdAt = { $gte: range.from, $lte: range.to };

  const [sales, paymentSummary] = await Promise.all([
    Sale.find(filter).populate('shop', 'name').populate('createdBy', 'name').sort({ createdAt: -1 }),
    Sale.aggregate([
      { $match: filter },
      { $group: { _id: '$paymentMethod', total: { $sum: '$totalAmount' }, count: { $sum: 1 } } },
    ]),
  ]);

  res.json(
    ApiResponse.ok('Sales report fetched', {
      count: sales.length,
      total: sales.reduce((a, s) => a + s.totalAmount, 0),
      profit: sales.reduce((a, s) => a + s.profit, 0),
      paymentSummary,
      sales,
    })
  );
});

const expenseReport = asyncHandler(async (req, res) => {
  const { period = 'month', shopId } = req.query;
  const scopedShopId = resolveShop(req, shopId);
  const range = stats.dateRange(period);
  const filter = { isDeleted: false };
  if (scopedShopId) filter.shop = scopedShopId;
  if (range.from) filter.expenseDate = { $gte: range.from, $lte: range.to };

  const breakdown = await stats.expenseBreakdown(scopedShopId, 36500);
  const filtered = breakdown.filter((b) => {
    if (!range.from) return true;
    return b.total > 0;
  });

  const expenses = await Expense.find(filter).populate('shop', 'name').populate('createdBy', 'name').sort({ expenseDate: -1 });

  res.json(
    ApiResponse.ok('Expense report fetched', {
      total: expenses.reduce((a, e) => a + e.amount, 0),
      count: expenses.length,
      breakdown: filtered,
      expenses,
    })
  );
});

const inventoryReport = asyncHandler(async (req, res) => {
  const shopId = resolveShop(req, req.query.shopId);
  const filter = { isDeleted: false };
  if (shopId) filter.shop = shopId;

  const products = await Product.find(filter).populate('category', 'name').populate('shop', 'name').sort({ quantity: 1 });

  const lowStock = products.filter((p) => p.quantity <= p.lowStockThreshold);
  const totalValue = products.reduce((a, p) => a + p.quantity * p.costPrice, 0);
  const potentialRevenue = products.reduce((a, p) => a + p.quantity * p.sellingPrice, 0);

  res.json(
    ApiResponse.ok('Inventory report fetched', {
      totalProducts: products.length,
      lowStockCount: lowStock.length,
      totalStockValue: totalValue,
      potentialRevenue,
      lowStock,
      products,
    })
  );
});

const exportCsv = (rows, headers, filename) => {
  const esc = (v) => {
    const s = v == null ? '' : String(v);
    return /[",\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
  };
  const lines = [headers.map(esc).join(',')];
  rows.forEach((r) => lines.push(headers.map((h) => esc(r[h])).join(',')));
  return { body: lines.join('\r\n'), filename };
};

const exportExcel = asyncHandler(async (req, res) => {
  const { type = 'sales', period = 'month', shopId } = req.query;
  const scopedShopId = resolveShop(req, shopId);
  const range = stats.dateRange(period);

  let rows = [];
  let headers = [];
  let filename = 'report.csv';

  if (type === 'sales') {
    const filter = { isDeleted: false };
    if (scopedShopId) filter.shop = scopedShopId;
    if (range.from) filter.createdAt = { $gte: range.from, $lte: range.to };
    const sales = await Sale.find(filter).populate('shop', 'name');
    headers = ['Invoice No', 'Date', 'Shop', 'Customer', 'Items', 'Subtotal', 'Discount', 'Total', 'Profit', 'Payment Method'];
    rows = sales.map((s) => ({
      'Invoice No': s.invoiceNo,
      Date: new Date(s.createdAt).toISOString(),
      Shop: s.shop?.name || '',
      Customer: s.customerName,
      Items: s.items.reduce((a, i) => a + i.quantity, 0),
      Subtotal: s.subtotal,
      Discount: s.discount,
      Total: s.totalAmount,
      Profit: s.profit,
      'Payment Method': s.paymentMethod,
    }));
    filename = `sales-${period}.csv`;
  } else if (type === 'expenses') {
    const filter = { isDeleted: false };
    if (scopedShopId) filter.shop = scopedShopId;
    if (range.from) filter.expenseDate = { $gte: range.from, $lte: range.to };
    const expenses = await Expense.find(filter).populate('shop', 'name');
    headers = ['Date', 'Shop', 'Category', 'Amount', 'Description'];
    rows = expenses.map((e) => ({
      Date: new Date(e.expenseDate).toISOString(),
      Shop: e.shop?.name || '',
      Category: e.category,
      Amount: e.amount,
      Description: e.description,
    }));
    filename = `expenses-${period}.csv`;
  } else if (type === 'inventory') {
    const filter = { isDeleted: false };
    if (scopedShopId) filter.shop = scopedShopId;
    const products = await Product.find(filter).populate('category', 'name');
    headers = ['Name', 'SKU', 'Category', 'Cost Price', 'Selling Price', 'Quantity', 'Stock Value'];
    rows = products.map((p) => ({
      Name: p.name,
      SKU: p.sku,
      Category: p.category?.name || '',
      'Cost Price': p.costPrice,
      'Selling Price': p.sellingPrice,
      Quantity: p.quantity,
      'Stock Value': p.quantity * p.costPrice,
    }));
    filename = `inventory-${period}.csv`;
  } else if (type === 'inventory-log') {
    const filter = {};
    if (scopedShopId) filter.shop = scopedShopId;
    if (range.from) filter.date = { $gte: range.from, $lte: range.to };
    const logs = await InventoryLog.find(filter).populate('shop', 'name').populate('performedBy', 'name');
    headers = ['Date', 'Shop', 'Product', 'Action', 'Quantity', 'Previous', 'New', 'By'];
    rows = logs.map((l) => ({
      Date: new Date(l.date).toISOString(),
      Shop: l.shop?.name || '',
      Product: l.productName,
      Action: l.actionType,
      Quantity: l.quantity,
      Previous: l.previousStock,
      New: l.newStock,
      By: l.performedBy?.name || '',
    }));
    filename = `inventory-log-${period}.csv`;
  }

  const { body } = exportCsv(rows, headers, filename);
  res.setHeader('Content-Type', 'text/csv; charset=utf-8');
  res.setHeader('Content-Disposition', `attachment; filename="${filename}"`);

  await recordAudit(req, {
    actionType: 'REPORT_DOWNLOAD',
    module: 'reports',
    recordType: 'Report',
    remarks: `Exported ${type} report as CSV (${period})`,
    shopId: scopedShopId || undefined,
  });

  res.send('\uFEFF' + body);
});

module.exports = { buildReport, salesReport, expenseReport, inventoryReport, exportExcel };
