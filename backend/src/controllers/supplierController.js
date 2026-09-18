const Supplier = require('../models/Supplier');
const ApiError = require('../utils/ApiError');
const asyncHandler = require('../utils/asyncHandler');
const ApiResponse = require('../utils/ApiResponse');
const { recordAudit } = require('../middleware/auth');

const shopFilter = (req) =>
  req.user.role === 'manager'
    ? req.user.assignedShop._id
    : req.shopId || null;

const listSuppliers = asyncHandler(async (req, res) => {
  const page = parseInt(req.query.page, 10) || 1;
  const limit = parseInt(req.query.limit, 10) || 50;
  const filter = { isDeleted: false };
  const shopId = shopFilter(req);
  if (shopId) filter.shop = shopId;
  if (req.query.search) {
    const term = req.query.search.trim();
    filter.$or = [
      { name: { $regex: term, $options: 'i' } },
      { phone: { $regex: term, $options: 'i' } },
      { email: { $regex: term, $options: 'i' } },
      { city: { $regex: term, $options: 'i' } },
    ];
  }

  const [suppliers, total] = await Promise.all([
    Supplier.find(filter)
      .populate('shop', 'name')
      .sort({ createdAt: -1 })
      .skip((page - 1) * limit)
      .limit(limit),
    Supplier.countDocuments(filter),
  ]);

  res.json(
    ApiResponse.ok('Suppliers fetched', { suppliers, total, page, limit, totalPages: Math.ceil(total / limit) })
  );
});

const getSupplier = asyncHandler(async (req, res) => {
  const supplier = await Supplier.findById(req.params.id).populate('shop', 'name');
  if (!supplier || supplier.isDeleted) throw new ApiError(404, 'Supplier not found.');
  const supplierShopId = (supplier.shop && supplier.shop._id ? supplier.shop._id : supplier.shop).toString();
  if (req.user.role === 'manager' && supplierShopId !== req.user.assignedShop._id.toString()) {
    throw new ApiError(403, 'You can only view suppliers of your assigned shop.');
  }
  res.json(ApiResponse.ok('Supplier fetched', supplier));
});

const createSupplier = asyncHandler(async (req, res) => {
  const { name, phone, email, address, city, notes, balance } = req.body;
  if (!name || !name.trim()) throw new ApiError(400, 'Supplier name is required.');

  const shopId = shopFilter(req);
  if (!shopId) throw new ApiError(400, 'shopId is required.');

  const supplier = await Supplier.create({
    name: name.trim(),
    phone: phone || '',
    email: email || '',
    address: address || '',
    city: city || '',
    notes: notes || '',
    balance: Number(balance) || 0,
    shop: shopId,
    createdBy: req.user._id,
  });

  await recordAudit(req, {
    actionType: 'CREATE_SUPPLIER',
    module: 'suppliers',
    recordId: supplier._id,
    recordType: 'Supplier',
    newData: supplier.toObject(),
    remarks: `Supplier "${supplier.name}" added`,
    shopId,
  });

  res.status(201).json(ApiResponse.created('Supplier added successfully', supplier));
});

const updateSupplier = asyncHandler(async (req, res) => {
  const supplier = await Supplier.findById(req.params.id);
  if (!supplier || supplier.isDeleted) throw new ApiError(404, 'Supplier not found.');
  if (req.user.role === 'manager' && supplier.shop.toString() !== req.user.assignedShop._id.toString()) {
    throw new ApiError(403, 'You can only manage suppliers of your assigned shop.');
  }
  const oldData = supplier.toObject();

  const allowed = ['name', 'phone', 'email', 'address', 'city', 'notes'];
  allowed.forEach((field) => {
    if (req.body[field] !== undefined) supplier[field] = req.body[field];
  });
  await supplier.save();

  await recordAudit(req, {
    actionType: 'UPDATE_SUPPLIER',
    module: 'suppliers',
    recordId: supplier._id,
    recordType: 'Supplier',
    oldData,
    newData: supplier.toObject(),
    remarks: `Supplier "${supplier.name}" updated`,
    shopId: supplier.shop,
  });

  res.json(ApiResponse.ok('Supplier updated', supplier));
});

const deleteSupplier = asyncHandler(async (req, res) => {
  const { deleteReason } = req.body;
  const supplier = await Supplier.findById(req.params.id);
  if (!supplier) throw new ApiError(404, 'Supplier not found.');
  if (req.user.role === 'manager' && supplier.shop.toString() !== req.user.assignedShop._id.toString()) {
    throw new ApiError(403, 'You can only manage suppliers of your assigned shop.');
  }
  const oldData = supplier.toObject();

  supplier.isDeleted = true;
  supplier.deletedBy = req.user._id;
  supplier.deletedAt = new Date();
  supplier.deleteReason = deleteReason || '';
  await supplier.save();

  await recordAudit(req, {
    actionType: 'DELETE_SUPPLIER',
    module: 'suppliers',
    recordId: supplier._id,
    recordType: 'Supplier',
    oldData,
    newData: null,
    status: 'deleted',
    remarks: `Supplier "${supplier.name}" soft-deleted`,
    shopId: supplier.shop,
  });

  res.json(ApiResponse.ok('Supplier deleted'));
});

const restoreSupplier = asyncHandler(async (req, res) => {
  const supplier = await Supplier.findById(req.params.id);
  if (!supplier) throw new ApiError(404, 'Supplier not found.');

  supplier.isDeleted = false;
  supplier.deletedBy = null;
  supplier.deletedAt = null;
  supplier.deleteReason = '';
  await supplier.save();

  await recordAudit(req, {
    actionType: 'RESTORE_SUPPLIER',
    module: 'suppliers',
    recordId: supplier._id,
    recordType: 'Supplier',
    oldData: null,
    newData: supplier.toObject(),
    status: 'restored',
    remarks: `Supplier "${supplier.name}" restored`,
    shopId: supplier.shop,
  });

  res.json(ApiResponse.ok('Supplier restored', supplier));
});

// Adjust the outstanding balance: type "charge" increases the due amount
// (amount we owe the supplier), type "payment" reduces it (we paid them).
const adjustBalance = asyncHandler(async (req, res) => {
  const { amount, type, note } = req.body;
  const value = Number(amount);
  if (!value || value <= 0) throw new ApiError(400, 'A positive amount is required.');
  if (!['charge', 'payment'].includes(type)) {
    throw new ApiError(400, 'Type must be "charge" or "payment".');
  }

  const supplier = await Supplier.findById(req.params.id);
  if (!supplier || supplier.isDeleted) throw new ApiError(404, 'Supplier not found.');
  if (req.user.role === 'manager' && supplier.shop.toString() !== req.user.assignedShop._id.toString()) {
    throw new ApiError(403, 'You can only manage suppliers of your assigned shop.');
  }
  const oldData = supplier.toObject();

  if (type === 'charge') {
    supplier.balance += value;
  } else {
    supplier.balance = Math.max(0, supplier.balance - value);
  }
  supplier.transactions.push({
    amount: value,
    type,
    note: note || (type === 'charge' ? 'Due added' : 'Payment made'),
    date: new Date(),
    by: req.user._id,
  });
  await supplier.save();

  await recordAudit(req, {
    actionType: type === 'charge' ? 'CREATE_SUPPLIER' : 'UPDATE_SUPPLIER',
    module: 'suppliers',
    recordId: supplier._id,
    recordType: 'Supplier',
    oldData: { balance: oldData.balance },
    newData: { balance: supplier.balance, adjustment: value, type },
    remarks: type === 'charge'
        ? `Due Rs. ${value} added for "${supplier.name}"`
        : `Payment Rs. ${value} made to "${supplier.name}"`,
    shopId: supplier.shop,
  });

  res.json(ApiResponse.ok(type === 'charge' ? 'Due amount added' : 'Payment recorded', supplier));
});

module.exports = {
  listSuppliers,
  getSupplier,
  createSupplier,
  updateSupplier,
  deleteSupplier,
  restoreSupplier,
  adjustBalance,
};
