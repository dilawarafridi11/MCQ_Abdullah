const express = require('express');
const inventoryController = require('../controllers/inventoryController');
const { restrictTo } = require('../middleware/auth');
const router = express.Router();

// Admin is view-only. Stock in/out/transfer are manager (operational) actions.
router.post('/in', restrictTo('manager'), inventoryController.stockIn);
router.post('/out', restrictTo('manager'), inventoryController.stockOut);
router.post('/transfer', restrictTo('manager'), inventoryController.transferStock);
router.get('/shops', inventoryController.transferShops);
router.get('/products/:shopId', inventoryController.shopProducts);
router.get('/history', inventoryController.inventoryHistory);

module.exports = router;
