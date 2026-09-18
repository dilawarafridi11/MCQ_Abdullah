const express = require('express');
const shopController = require('../controllers/shopController');
const { restrictTo } = require('../middleware/auth');
const router = express.Router();

router.get('/', shopController.listShops);
router.get('/:id/overview', restrictTo('admin'), shopController.getShopOverview);
router.get('/:id', shopController.getShop);

router.post('/', restrictTo('admin'), shopController.createShop);
router.put('/:id', restrictTo('admin'), shopController.updateShop);
router.delete('/:id', restrictTo('admin'), shopController.deleteShop);
router.post('/:id/restore', restrictTo('admin'), shopController.restoreShop);

module.exports = router;
