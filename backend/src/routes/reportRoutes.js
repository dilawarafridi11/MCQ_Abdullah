const express = require('express');
const reportController = require('../controllers/reportController');
const { restrictTo } = require('../middleware/auth');
const router = express.Router();
const { sendDailyReportEmail } = require('../services/dailyReportService');
const asyncHandler = require('../utils/asyncHandler');
const ApiResponse = require('../utils/ApiResponse');

// Reports contain revenue/profit/financial analytics -> admin only.
router.use(restrictTo('admin'));

router.get('/', reportController.buildReport);
router.get('/sales', reportController.salesReport);
router.get('/expenses', reportController.expenseReport);
router.get('/inventory', reportController.inventoryReport);
router.get('/export', reportController.exportExcel);

router.post('/send-daily-report', asyncHandler(async (req, res) => {
  await sendDailyReportEmail();
  res.json(ApiResponse.ok('Daily report email sent (check your inbox).'));
}));

module.exports = router;
