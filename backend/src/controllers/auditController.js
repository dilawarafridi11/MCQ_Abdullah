const AuditLog = require('../models/AuditLog');
const Product = require('../models/Product');
const Sale = require('../models/Sale');
const Expense = require('../models/Expense');
const Category = require('../models/Category');
const ApiError = require('../utils/ApiError');
const asyncHandler = require('../utils/asyncHandler');
const ApiResponse = require('../utils/ApiResponse');
const { recordAudit } = require('../middleware/auth');

const ACTION_TYPES = require('../models/AuditLog').ACTION_TYPES;

const listAuditLogs = asyncHandler(async (req, res) => {
  const page = parseInt(req.query.page, 10) || 1;
  const limit = parseInt(req.query.limit, 10) || 30;
  const filter = {};

  // Managers only see activity from their own shop, regardless of query params.
  if (req.user && req.user.role === 'manager') {
    filter.shopId = req.user.assignedShop._id;
  } else if (req.query.shopId) {
    filter.shopId = req.query.shopId;
  }
  if (req.query.userId) filter.performedBy = req.query.userId;
  if (req.query.actionType) filter.actionType = req.query.actionType;
  if (req.query.module) filter.module = req.query.module;
  if (req.query.status) filter.status = req.query.status;
  if (req.query.from || req.query.to) {
    filter.timestamp = {};
    if (req.query.from) filter.timestamp.$gte = new Date(req.query.from);
    if (req.query.to) filter.timestamp.$lte = new Date(req.query.to);
  }

  const [logs, total] = await Promise.all([
    AuditLog.find(filter)
      .populate('performedBy', 'name email role')
      .populate('shopId', 'name')
      .sort({ timestamp: -1 })
      .skip((page - 1) * limit)
      .limit(limit),
    AuditLog.countDocuments(filter),
  ]);

  res.json(ApiResponse.ok('Audit logs fetched', { logs, total, page, limit, totalPages: Math.ceil(total / limit) }));
});

const getAuditLog = asyncHandler(async (req, res) => {
  const log = await AuditLog.findById(req.params.id)
    .populate('performedBy', 'name email role')
    .populate('shopId', 'name');
  if (!log) throw new ApiError(404, 'Audit log not found.');
  res.json(ApiResponse.ok('Audit log fetched', log));
});

const auditStats = asyncHandler(async (req, res) => {
  const days = parseInt(req.query.days, 10) || 30;
  const since = new Date(Date.now() - days * 86400000);

  const [total, today, byAction, byUser, deleted] = await Promise.all([
    AuditLog.countDocuments({ timestamp: { $gte: since } }),
    AuditLog.countDocuments({ timestamp: { $gte: new Date().setHours(0, 0, 0, 0) } }),
    AuditLog.aggregate([
      { $match: { timestamp: { $gte: since } } },
      { $group: { _id: '$actionType', count: { $sum: 1 } } },
      { $sort: { count: -1 } },
      { $limit: 10 },
    ]),
    AuditLog.aggregate([
      { $match: { timestamp: { $gte: since } } },
      { $group: { _id: '$performedByName', count: { $sum: 1 } } },
      { $sort: { count: -1 } },
      { $limit: 8 },
    ]),
    AuditLog.countDocuments({ timestamp: { $gte: since }, status: 'deleted' }),
  ]);

  res.json(
    ApiResponse.ok('Audit stats fetched', {
      total,
      today,
      deleted,
      byAction,
      byUser,
    })
  );
});

const restoreRecord = asyncHandler(async (req, res) => {
  const { logId } = req.params;
  const log = await AuditLog.findById(logId);
  if (!log) throw new ApiError(404, 'Audit log not found.');
  if (log.status === 'restored') throw new ApiError(400, 'This record was already restored.');

  const modelByType = {
    Product: Product,
    Sale: Sale,
    Expense: Expense,
    Category: Category,
  };

  const Model = modelByType[log.recordType];
  if (!Model) throw new ApiError(400, `Restore is not supported for "${log.recordType}".`);

  const record = await Model.findById(log.recordId);
  if (!record) throw new ApiError(404, `${log.recordType} record not found.`);

  record.isDeleted = false;
  record.deletedBy = null;
  record.deletedAt = null;
  record.deleteReason = '';
  await record.save();

  log.status = 'restored';
  log.remarks = `${log.remarks || ''} | Restored by ${req.user.name}`;
  // Audit logs are immutable via hooks - use direct update bypass is not allowed,
  // so we create a follow-up RESTORE_* log instead.
  const restoreActionMap = {
    Product: 'RESTORE_PRODUCT',
    Sale: 'RESTORE_SALE',
    Expense: 'RESTORE_EXPENSE',
    Category: 'RESTORE_CATEGORY',
  };
  await recordAudit(req, {
    actionType: restoreActionMap[log.recordType],
    module: log.module,
    recordId: record._id,
    recordType: log.recordType,
    newData: record.toObject(),
    status: 'restored',
    remarks: `Restored from audit log ${log._id}`,
    shopId: record.shop || log.shopId || undefined,
  });

  res.json(ApiResponse.ok(`${log.recordType} restored successfully`, record));
});

const exportLogs = asyncHandler(async (req, res) => {
  const filter = {};
  if (req.query.userId) filter.performedBy = req.query.userId;
  if (req.query.shopId) filter.shopId = req.query.shopId;
  if (req.query.actionType) filter.actionType = req.query.actionType;
  if (req.query.module) filter.module = req.query.module;
  if (req.query.status) filter.status = req.query.status;
  if (req.query.from || req.query.to) {
    filter.timestamp = {};
    if (req.query.from) filter.timestamp.$gte = new Date(req.query.from);
    if (req.query.to) filter.timestamp.$lte = new Date(req.query.to);
  }

  const logs = await AuditLog.find(filter)
    .populate('performedBy', 'name')
    .populate('shopId', 'name')
    .sort({ timestamp: -1 });

  const headers = [
    'Timestamp',
    'Action',
    'Module',
    'Record Type',
    'Record ID',
    'User',
    'Role',
    'Shop',
    'IP',
    'Status',
    'Remarks',
  ];
  const esc = (v) => {
    const s = v == null ? '' : String(v);
    return /[",\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
  };
  const lines = [headers.join(',')];
  logs.forEach((l) => {
    lines.push(
      [
        new Date(l.timestamp).toISOString(),
        l.actionType,
        l.module,
        l.recordType,
        l.recordId,
        l.performedByName,
        l.userRole,
        l.shopName,
        l.ipAddress,
        l.status,
        l.remarks,
      ]
        .map(esc)
        .join(',')
    );
  });

  const filename = `audit-logs-${new Date().toISOString().slice(0, 10)}.csv`;
  res.setHeader('Content-Type', 'text/csv; charset=utf-8');
  res.setHeader('Content-Disposition', `attachment; filename="${filename}"`);

  await recordAudit(req, {
    actionType: 'REPORT_DOWNLOAD',
    module: 'reports',
    recordType: 'AuditLog',
    remarks: `Exported audit logs as CSV`,
  });

  res.send('\uFEFF' + lines.join('\r\n'));
});

const actionTypes = (req, res) => {
  res.json(ApiResponse.ok('Action types', ACTION_TYPES));
};

module.exports = { listAuditLogs, getAuditLog, auditStats, restoreRecord, exportLogs, actionTypes };
