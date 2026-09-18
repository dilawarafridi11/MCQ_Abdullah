const express = require('express');
const saleController = require('../controllers/saleController');
const { restrictTo, scopedShop } = require('../middleware/auth');
const router = express.Router();

router.get('/', scopedShop, saleController.listSales);
router.get('/:id', saleController.getSale);

// Admin is view-only. Sale mutations are manager (operational) actions.
router.post('/', restrictTo('manager'), saleController.createSale);
router.put('/:id', restrictTo('manager'), saleController.updateSale);
router.delete('/:id', restrictTo('manager'), saleController.deleteSale);
router.post('/:id/restore', restrictTo('manager'), saleController.restoreSale);

module.exports = router;
