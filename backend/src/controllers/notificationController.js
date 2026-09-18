const Notification = require('../models/Notification');
const asyncHandler = require('../utils/asyncHandler');
const ApiResponse = require('../utils/ApiResponse');

const listNotifications = asyncHandler(async (req, res) => {
  const page = parseInt(req.query.page, 10) || 1;
  const limit = parseInt(req.query.limit, 10) || 30;
  const filter = { user: req.user._id };

  const [notifications, total, unread] = await Promise.all([
    Notification.find(filter).sort({ createdAt: -1 }).skip((page - 1) * limit).limit(limit),
    Notification.countDocuments(filter),
    Notification.countDocuments({ ...filter, isRead: false }),
  ]);

  res.json(ApiResponse.ok('Notifications fetched', { notifications, total, unread, page, limit, totalPages: Math.ceil(total / limit) }));
});

const unreadCount = asyncHandler(async (req, res) => {
  const count = await Notification.countDocuments({ user: req.user._id, isRead: false });
  res.json(ApiResponse.ok('Unread count fetched', { count }));
});

const markRead = asyncHandler(async (req, res) => {
  const notification = await Notification.findById(req.params.id);
  if (!notification) throw new (require('../utils/ApiError'))(404, 'Notification not found.');
  if (notification.user.toString() !== req.user._id.toString()) {
    throw new (require('../utils/ApiError'))(403, 'Not your notification.');
  }
  notification.isRead = true;
  notification.readAt = new Date();
  await notification.save();
  res.json(ApiResponse.ok('Notification marked as read', notification));
});

const markAllRead = asyncHandler(async (req, res) => {
  await Notification.updateMany({ user: req.user._id, isRead: false }, { $set: { isRead: true, readAt: new Date() } });
  res.json(ApiResponse.ok('All notifications marked as read'));
});

const deleteNotification = asyncHandler(async (req, res) => {
  const notification = await Notification.findById(req.params.id);
  if (!notification) throw new (require('../utils/ApiError'))(404, 'Notification not found.');
  if (notification.user.toString() !== req.user._id.toString()) {
    throw new (require('../utils/ApiError'))(403, 'Not your notification.');
  }
  await notification.deleteOne();
  res.json(ApiResponse.ok('Notification deleted'));
});

const registerToken = asyncHandler(async (req, res) => {
  const { fcmToken } = req.body;
  if (!fcmToken) throw new (require('../utils/ApiError'))(400, 'fcmToken is required.');
  const User = require('../models/User');
  await User.findByIdAndUpdate(req.user._id, { $set: { fcmToken, notificationEnabled: true } });
  res.json(ApiResponse.ok('Push token registered'));
});

module.exports = { listNotifications, unreadCount, markRead, markAllRead, deleteNotification, registerToken };
