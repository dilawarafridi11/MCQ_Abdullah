const User = require('../models/User');
const ApiError = require('../utils/ApiError');
const asyncHandler = require('../utils/asyncHandler');
const { verifyToken, parseDeviceInfo } = require('../utils/jwt');
const AuditLog = require('../models/AuditLog');
const { Types } = require('mongoose');

const protect = asyncHandler(async (req, res, next) => {
  let token;
  if (req.headers.authorization && req.headers.authorization.startsWith('Bearer ')) {
    token = req.headers.authorization.split(' ')[1];
  }
  if (!token) throw new ApiError(401, 'Not authorized. No token provided.');

  let decoded;
  try {
    decoded = verifyToken(token);
  } catch (err) {
    throw new ApiError(401, 'Session expired. Please login again.');
  }

  const user = await User.findById(decoded.id).populate('assignedShop');
  if (!user) throw new ApiError(401, 'User not found.');
  if (!user.isActive) throw new ApiError(403, 'Account has been deactivated.');

  req.user = user;
  req.deviceInfo = parseDeviceInfo(req);
  next();
});

const restrictTo = (...roles) => (req, res, next) => {
  if (!roles.includes(req.user.role)) {
    return next(new ApiError(403, 'You do not have permission to perform this action.'));
  }
  next();
};

// Resolves the shop scope for the current user.
// Admin may pass ?shopId=..., managers are locked to their assigned shop.
const scopedShop = asyncHandler(async (req, res, next) => {
  if (req.user.role === 'admin') {
    const raw = req.query.shopId || req.body.shopId || null;
    req.shopId = raw && Types.ObjectId.isValid(raw) ? new Types.ObjectId(raw) : null;
  } else {
    if (!req.user.assignedShop) {
      return next(new ApiError(403, 'No shop is assigned to your account.'));
    }
    req.shopId = req.user.assignedShop._id;
  }
  next();
});

const recordAudit = async (req, log) => {
  try {
    await AuditLog.create({
      actionType: log.actionType,
      module: log.module,
      recordType: log.recordType || '',
      recordId: log.recordId || null,
      oldData: log.oldData ?? null,
      newData: log.newData ?? null,
      performedBy: req.user ? req.user._id : null,
      performedByName: req.user ? req.user.name : 'System',
      userRole: req.user ? req.user.role : 'system',
      shopId: log.shopId || req.shopId || (req.user && req.user.assignedShop ? req.user.assignedShop._id : null),
      shopName: log.shopName || (req.user && req.user.assignedShop ? req.user.assignedShop.name : ''),
      ipAddress: req.ip || 'unknown',
      deviceInfo: req.deviceInfo || {},
      remarks: log.remarks || '',
      status: log.status || 'success',
    });
  } catch (err) {
    console.error('Failed to write audit log:', err.message);
  }
};

module.exports = { protect, restrictTo, scopedShop, recordAudit };
