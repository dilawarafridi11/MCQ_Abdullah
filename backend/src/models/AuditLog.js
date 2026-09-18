const mongoose = require('mongoose');

const ACTION_TYPES = [
  'CREATE_PRODUCT',
  'UPDATE_PRODUCT',
  'DELETE_PRODUCT',
  'RESTORE_PRODUCT',
  'CREATE_CATEGORY',
  'UPDATE_CATEGORY',
  'DELETE_CATEGORY',
  'RESTORE_CATEGORY',
  'STOCK_IN',
  'STOCK_OUT',
  'STOCK_TRANSFER',
  'CREATE_SALE',
  'UPDATE_SALE',
  'DELETE_SALE',
  'RESTORE_SALE',
  'CREATE_EXPENSE',
  'UPDATE_EXPENSE',
  'DELETE_EXPENSE',
  'RESTORE_EXPENSE',
  'CREATE_USER',
  'UPDATE_USER',
  'LOGIN',
  'LOGOUT',
  'REPORT_DOWNLOAD',
];

const MODULES = [
  'auth',
  'products',
  'categories',
  'inventory',
  'sales',
  'expenses',
  'shops',
  'users',
  'reports',
  'system',
];

const auditLogSchema = new mongoose.Schema(
  {
    actionType: { type: String, enum: ACTION_TYPES, required: true },
    module: { type: String, enum: MODULES, required: true },
    recordType: { type: String, default: '' },
    recordId: { type: mongoose.Schema.Types.Mixed, default: null },
    oldData: { type: mongoose.Schema.Types.Mixed, default: null },
    newData: { type: mongoose.Schema.Types.Mixed, default: null },
    performedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
    performedByName: { type: String, default: '' },
    userRole: { type: String, enum: ['admin', 'manager', 'system'], default: 'manager' },
    shopId: { type: mongoose.Schema.Types.ObjectId, ref: 'Shop', default: null },
    shopName: { type: String, default: '' },
    timestamp: { type: Date, default: Date.now },
    ipAddress: { type: String, default: 'unknown' },
    deviceInfo: {
      platform: { type: String, default: '' },
      userAgent: { type: String, default: '' },
      appVersion: { type: String, default: '' },
    },
    remarks: { type: String, default: '' },
    status: {
      type: String,
      enum: ['success', 'deleted', 'restored'],
      default: 'success',
    },
  },
  { timestamps: true }
);

// Audit logs are immutable - only admin may read. Prevents modification/deletion.
auditLogSchema.pre('updateOne', function (next) {
  const error = new Error('Audit logs are immutable and cannot be modified.');
  error.name = 'ImmutableDocumentError';
  next(error);
});
auditLogSchema.pre('updateMany', function (next) {
  const error = new Error('Audit logs are immutable and cannot be modified.');
  error.name = 'ImmutableDocumentError';
  next(error);
});

auditLogSchema.index({ timestamp: -1 });
auditLogSchema.index({ performedBy: 1, timestamp: -1 });
auditLogSchema.index({ shopId: 1, timestamp: -1 });
auditLogSchema.index({ actionType: 1 });

module.exports = mongoose.model('AuditLog', auditLogSchema);
module.exports.ACTION_TYPES = ACTION_TYPES;
module.exports.MODULES = MODULES;
