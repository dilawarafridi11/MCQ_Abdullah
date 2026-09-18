const asyncHandler = require('../utils/asyncHandler');
const ApiResponse = require('../utils/ApiResponse');
const stats = require('../utils/stats');
const Shop = require('../models/Shop');

const getAnalytics = asyncHandler(async (req, res) => {
  const isAdmin = req.user.role === 'admin';
  const shopId = isAdmin ? (req.shopId || null) : req.user.assignedShop._id;

  const [daily, weekly, monthly, yearly, expenseBreakdown] = await Promise.all([
    stats.dailySeries(shopId, 30),
    stats.weeklySeries(shopId, 12),
    stats.monthlySeries(shopId, 12),
    stats.yearlySeries(shopId, 5),
    stats.expenseBreakdown(shopId, 90),
  ]);

  const comparison = isAdmin
    ? await stats.shopComparison((await Shop.find({ isDeleted: false })).map((s) => s._id))
    : await stats.shopComparison([shopId]);

  res.json(
    ApiResponse.ok('Analytics fetched', {
      daily,
      weekly,
      monthly,
      yearly,
      expenseBreakdown,
      comparison,
    })
  );
});

module.exports = { getAnalytics };
