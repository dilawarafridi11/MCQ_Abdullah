const express = require('express');
const customerController = require('../controllers/customerController');
const { restrictTo, scopedShop } = require('../middleware/auth');
const router = express.Router();

router.get('/', scopedShop, customerController.listCustomers);
router.get('/:id', customerController.getCustomer);

// Customer records are manager (operational) actions; admin is view-only.
router.post('/', restrictTo('manager'), customerController.createCustomer);
router.put('/:id', restrictTo('manager'), customerController.updateCustomer);
router.delete('/:id', restrictTo('manager'), customerController.deleteCustomer);
router.post('/:id/restore', restrictTo('manager'), customerController.restoreCustomer);
router.post('/:id/balance', restrictTo('manager'), customerController.adjustBalance);

module.exports = router;
