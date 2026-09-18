const express = require('express');
const notificationController = require('../controllers/notificationController');
const router = express.Router();

router.get('/', notificationController.listNotifications);
router.get('/unread-count', notificationController.unreadCount);
router.post('/token', notificationController.registerToken);
router.put('/read-all', notificationController.markAllRead);
router.put('/:id/read', notificationController.markRead);
router.delete('/:id', notificationController.deleteNotification);

module.exports = router;
