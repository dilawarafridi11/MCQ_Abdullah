const express = require('express');
const { protect } = require('../middleware/auth');
const router = express.Router();

const authRoutes = require('./authRoutes');
const dashboardRoutes = require('./dashboardRoutes');
const shopRoutes = require('./shopRoutes');
const categoryRoutes = require('./categoryRoutes');
const productRoutes = require('./productRoutes');
const inventoryRoutes = require('./inventoryRoutes');
const saleRoutes = require('./saleRoutes');
const expenseRoutes = require('./expenseRoutes');
const customerRoutes = require('./customerRoutes');
const supplierRoutes = require('./supplierRoutes');
const reportRoutes = require('./reportRoutes');
const analyticsRoutes = require('./analyticsRoutes');
const auditRoutes = require('./auditRoutes');
const notificationRoutes = require('./notificationRoutes');
const { notFound } = require('../middleware/errorHandler');

router.get('/health', (req, res) =>
  res.json({ success: true, message: 'MCQ API is running', timestamp: new Date().toISOString() })
);

router.use('/auth', authRoutes);

router.use('/dashboard', protect, dashboardRoutes);
router.use('/shops', protect, shopRoutes);
router.use('/categories', protect, categoryRoutes);
router.use('/products', protect, productRoutes);
router.use('/inventory', protect, inventoryRoutes);
router.use('/sales', protect, saleRoutes);
router.use('/expenses', protect, expenseRoutes);
router.use('/customers', protect, customerRoutes);
router.use('/suppliers', protect, supplierRoutes);
router.use('/reports', protect, reportRoutes);
router.use('/analytics', protect, analyticsRoutes);
router.use('/audit', protect, auditRoutes);
router.use('/notifications', protect, notificationRoutes);

router.use(notFound);

module.exports = router;
