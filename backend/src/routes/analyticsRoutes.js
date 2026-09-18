const express = require('express');
const analyticsController = require('../controllers/analyticsController');
const { scopedShop, restrictTo } = require('../middleware/auth');
const router = express.Router();

// Financial analytics -> admin only.
router.use(restrictTo('admin'));

router.get('/', scopedShop, analyticsController.getAnalytics);

module.exports = router;
