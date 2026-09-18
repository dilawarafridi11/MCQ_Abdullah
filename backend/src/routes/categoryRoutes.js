const express = require('express');
const categoryController = require('../controllers/categoryController');
const { restrictTo } = require('../middleware/auth');
const router = express.Router();

router.get('/', categoryController.listCategories);

router.post('/', restrictTo('admin', 'manager'), categoryController.createCategory);
router.put('/:id', restrictTo('admin', 'manager'), categoryController.updateCategory);
router.delete('/:id', restrictTo('admin', 'manager'), categoryController.deleteCategory);
router.post('/:id/restore', restrictTo('admin'), categoryController.restoreCategory);

module.exports = router;
