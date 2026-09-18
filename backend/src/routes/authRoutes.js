const express = require('express');
const rateLimit = require('express-rate-limit');
const authController = require('../controllers/authController');
const { protect, restrictTo } = require('../middleware/auth');
const router = express.Router();

// Tight brute-force guard on credential checks: 10 tries per 15 min per IP.
const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 10,
  standardHeaders: true,
  legacyHeaders: false,
  message: { success: false, message: 'Too many login attempts. Please try again after 15 minutes.' },
});

router.post('/login', authLimiter, authController.login);
router.get('/preview', authController.previewLogin);

router.post('/logout', protect, authController.logout);
router.get('/profile', protect, authController.getProfile);
router.put('/profile', protect, authController.updateProfile);
router.put('/change-password', protect, authController.changePassword);

router.post('/managers', protect, restrictTo('admin'), authController.registerManager);
router.get('/managers', protect, restrictTo('admin'), authController.listManagers);
router.put('/managers/:id', protect, restrictTo('admin'), authController.updateManager);

module.exports = router;
