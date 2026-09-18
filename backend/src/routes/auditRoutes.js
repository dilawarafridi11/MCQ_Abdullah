const express = require('express');
const auditController = require('../controllers/auditController');
const { restrictTo } = require('../middleware/auth');
const router = express.Router();

// Managers may read activity (scoped to their shop in the controller).
// Stats, export, detail and restore stay admin-only.
router.get('/', auditController.listAuditLogs);

router.use(restrictTo('admin'));

router.get('/stats', auditController.auditStats);
router.get('/action-types', auditController.actionTypes);
router.get('/export', auditController.exportLogs);
router.get('/:id', auditController.getAuditLog);
router.post('/:id/restore', auditController.restoreRecord);

module.exports = router;
