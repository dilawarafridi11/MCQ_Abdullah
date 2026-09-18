const express = require('express');
const productController = require('../controllers/productController');
const { restrictTo, scopedShop } = require('../middleware/auth');
const router = express.Router();

router.get('/', scopedShop, productController.listProducts);
router.get('/low-stock', scopedShop, productController.lowStockProducts);
router.get('/:id', productController.getProduct);

// Admin is view-only. Product mutations are manager (operational) actions.
router.post('/', restrictTo('manager'), productController.createProduct);
router.put('/:id', restrictTo('manager'), productController.updateProduct);
router.delete('/:id', restrictTo('manager'), productController.deleteProduct);
router.post('/:id/restore', restrictTo('manager'), productController.restoreProduct);

module.exports = router;
