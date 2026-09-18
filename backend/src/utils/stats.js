const Sale = require('../models/Sale');
const Expense = require('../models/Expense');

const startOfDay = (d) => {
  const date = new Date(d);
  date.setHours(0, 0, 0, 0);
  return date;
};

const endOfDay = (d) => {
  const date = new Date(d);
  date.setHours(23, 59, 59, 999);
  return date;
};

const dateRange = (period, reference = new Date()) => {
  const ref = new Date(reference);
  if (period === 'today') return { from: startOfDay(ref), to: endOfDay(ref) };
  if (period === 'week') {
    const day = ref.getDay() || 7;
    const start = startOfDay(ref);
    start.setDate(ref.getDate() - day + 1);
    return { from: start, to: endOfDay(ref) };
  }
  if (period === 'month') {
    return { from: startOfDay(new Date(ref.getFullYear(), ref.getMonth(), 1)), to: endOfDay(ref) };
  }
  if (period === 'year') {
    return { from: startOfDay(new Date(ref.getFullYear(), 0, 1)), to: endOfDay(ref) };
  }
  return { from: null, to: null };
};

const buildDateFilter = (range, field) => {
  if (!range || !range.from) return {};
  return { [field]: { $gte: range.from, $lte: range.to } };
};

// range: { from: Date|null, to: Date|null }
const getSalesTotal = async (range, shopId) => {
  const filter = { isDeleted: false, ...buildDateFilter(range, 'createdAt') };
  if (shopId) filter.shop = shopId;
  const res = await Sale.aggregate([
    { $match: filter },
    { $group: { _id: null, total: { $sum: '$totalAmount' }, count: { $sum: 1 }, profit: { $sum: '$profit' } } },
  ]);
  return res[0] || { total: 0, count: 0, profit: 0 };
};

const getExpenseTotal = async (range, shopId) => {
  const filter = { isDeleted: false, ...buildDateFilter(range, 'expenseDate') };
  if (shopId) filter.shop = shopId;
  const res = await Expense.aggregate([
    { $match: filter },
    { $group: { _id: null, total: { $sum: '$amount' }, count: { $sum: 1 } } },
  ]);
  return res[0] || { total: 0, count: 0 };
};

const dailySeries = async (shopId, days = 14) => {
  const points = [];
  for (let i = days - 1; i >= 0; i--) {
    const d = new Date();
    d.setDate(d.getDate() - i);
    const [sales, expenses] = await Promise.all([
      getSalesTotal({ from: startOfDay(d), to: endOfDay(d) }, shopId),
      getExpenseTotal({ from: startOfDay(d), to: endOfDay(d) }, shopId),
    ]);
    points.push({
      date: d.toISOString().slice(0, 10),
      label: `${d.getDate()}/${d.getMonth() + 1}`,
      sales: sales.total,
      profit: sales.profit,
      expenses: expenses.total,
    });
  }
  return points;
};

const weeklySeries = async (shopId, weeks = 12) => {
  const points = [];
  for (let i = weeks - 1; i >= 0; i--) {
    const end = new Date();
    end.setDate(end.getDate() - i * 7);
    const start = new Date(end);
    start.setDate(start.getDate() - 6);
    const range = { from: startOfDay(start), to: endOfDay(end) };
    const [sales, expenses] = await Promise.all([getSalesTotal(range, shopId), getExpenseTotal(range, shopId)]);
    points.push({
      label: `${start.getDate()}/${start.getMonth() + 1}`,
      sales: sales.total,
      profit: sales.profit,
      expenses: expenses.total,
    });
  }
  return points;
};

const monthlySeries = async (shopId, months = 12) => {
  const points = [];
  const now = new Date();
  for (let i = months - 1; i >= 0; i--) {
    const d = new Date(now.getFullYear(), now.getMonth() - i, 1);
    const range = { from: startOfDay(d), to: endOfDay(new Date(d.getFullYear(), d.getMonth() + 1, 0)) };
    const [sales, expenses] = await Promise.all([getSalesTotal(range, shopId), getExpenseTotal(range, shopId)]);
    points.push({
      label: d.toLocaleString('en', { month: 'short' }),
      sales: sales.total,
      profit: sales.profit,
      expenses: expenses.total,
    });
  }
  return points;
};

const yearlySeries = async (shopId, years = 5) => {
  const points = [];
  const currentYear = new Date().getFullYear();
  for (let y = currentYear - years + 1; y <= currentYear; y++) {
    const range = {
      from: new Date(y, 0, 1),
      to: new Date(y, 11, 31, 23, 59, 59, 999),
    };
    const [sales, expenses] = await Promise.all([getSalesTotal(range, shopId), getExpenseTotal(range, shopId)]);
    points.push({ label: String(y), sales: sales.total, profit: sales.profit, expenses: expenses.total });
  }
  return points;
};

const shopComparison = async (shops) => {
  const out = [];
  for (const shop of shops) {
    const [sales, expenses] = await Promise.all([getSalesTotal(null, shop._id), getExpenseTotal(null, shop._id)]);
    out.push({
      shopId: shop._id,
      shopName: shop.name,
      manager: shop.manager ? (shop.manager.name || shop.manager) : null,
      sales: sales.total,
      expenses: expenses.total,
      profit: sales.profit,
      saleCount: sales.count,
    });
  }
  return out;
};

const topProducts = async (shopId, days = 30, limit = 5) => {
  const filter = { isDeleted: false, createdAt: { $gte: new Date(Date.now() - days * 86400000) } };
  if (shopId) filter.shop = shopId;
  const res = await Sale.aggregate([
    { $match: filter },
    { $unwind: '$items' },
    {
      $group: {
        _id: '$items.productName',
        quantity: { $sum: '$items.quantity' },
        revenue: { $sum: '$items.totalAmount' },
      },
    },
    { $sort: { quantity: -1, revenue: -1 } },
    { $limit: limit },
  ]);
  return res.map((r) => ({ name: r._id, quantity: r.quantity, revenue: r.revenue }));
};

const expenseBreakdown = async (shopId, days = 30) => {
  const filter = { isDeleted: false, expenseDate: { $gte: startOfDay(new Date(Date.now() - days * 86400000)) } };
  if (shopId) filter.shop = shopId;
  const res = await Expense.aggregate([
    { $match: filter },
    { $group: { _id: '$category', total: { $sum: '$amount' } } },
    { $sort: { total: -1 } },
  ]);
  return res.map((r) => ({ category: r._id, total: r.total }));
};

module.exports = {
  startOfDay,
  endOfDay,
  dateRange,
  getSalesTotal,
  getExpenseTotal,
  dailySeries,
  weeklySeries,
  monthlySeries,
  yearlySeries,
  shopComparison,
  expenseBreakdown,
  topProducts,
};
