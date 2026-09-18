const express = require('express');
const dashboardController = require('../controllers/dashboardController');
const { scopedShop } = require('../middleware/auth');
const router = express.Router();

router.get('/', scopedShop, dashboardController.getDashboard);

module.exports = router;
