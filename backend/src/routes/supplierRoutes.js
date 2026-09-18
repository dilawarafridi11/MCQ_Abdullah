const express = require('express');
const supplierController = require('../controllers/supplierController');
const { restrictTo, scopedShop } = require('../middleware/auth');
const router = express.Router();

router.get('/', scopedShop, supplierController.listSuppliers);
router.get('/:id', supplierController.getSupplier);

// Supplier records are manager (operational) actions; admin is view-only.
router.post('/', restrictTo('manager'), supplierController.createSupplier);
router.put('/:id', restrictTo('manager'), supplierController.updateSupplier);
router.delete('/:id', restrictTo('manager'), supplierController.deleteSupplier);
router.post('/:id/restore', restrictTo('manager'), supplierController.restoreSupplier);
router.post('/:id/balance', restrictTo('manager'), supplierController.adjustBalance);

module.exports = router;
