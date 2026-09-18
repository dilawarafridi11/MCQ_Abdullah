const express = require('express');
const expenseController = require('../controllers/expenseController');
const { restrictTo, scopedShop } = require('../middleware/auth');
const router = express.Router();

router.get('/', scopedShop, expenseController.listExpenses);

// Admin is view-only. Expense mutations are manager (operational) actions.
router.post('/', restrictTo('manager'), expenseController.createExpense);
router.put('/:id', restrictTo('manager'), expenseController.updateExpense);
router.delete('/:id', restrictTo('manager'), expenseController.deleteExpense);
router.post('/:id/restore', restrictTo('manager'), expenseController.restoreExpense);

module.exports = router;
