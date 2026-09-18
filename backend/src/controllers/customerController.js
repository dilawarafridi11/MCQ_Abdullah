const Customer = require('../models/Customer');
const Sale = require('../models/Sale');
const ApiError = require('../utils/ApiError');
const asyncHandler = require('../utils/asyncHandler');
const ApiResponse = require('../utils/ApiResponse');
const { recordAudit } = require('../middleware/auth');

const shopFilter = (req) =>
  req.user.role === 'manager'
    ? req.user.assignedShop._id
    : req.shopId || null;

const listCustomers = asyncHandler(async (req, res) => {
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

  const [customers, total] = await Promise.all([
    Customer.find(filter)
      .populate('shop', 'name')
      .sort({ createdAt: -1 })
      .skip((page - 1) * limit)
      .limit(limit),
    Customer.countDocuments(filter),
  ]);

  res.json(
    ApiResponse.ok('Customers fetched', { customers, total, page, limit, totalPages: Math.ceil(total / limit) })
  );
});

const getCustomer = asyncHandler(async (req, res) => {
  const customer = await Customer.findById(req.params.id).populate('shop', 'name');
  if (!customer || customer.isDeleted) throw new ApiError(404, 'Customer not found.');
  const customerShopId = (customer.shop && customer.shop._id ? customer.shop._id : customer.shop).toString();
  if (req.user.role === 'manager' && customerShopId !== req.user.assignedShop._id.toString()) {
    throw new ApiError(403, 'You can only view customers of your assigned shop.');
  }

  const phone = (customer.phone || '').trim();
  const recentSales = phone
    ? await Sale.find({
        isDeleted: false,
        shop: customer.shop,
        customerPhone: { $regex: `^${phone.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}$`, $options: 'i' },
      })
        .select('invoiceNo totalAmount createdAt paymentMethod items')
        .sort({ createdAt: -1 })
        .limit(20)
    : [];

  res.json(
    ApiResponse.ok('Customer fetched', {
      ...customer.toObject(),
      recentSales,
    })
  );
});

const createCustomer = asyncHandler(async (req, res) => {
  const { name, phone, email, address, city, notes, balance } = req.body;
  if (!name || !name.trim()) throw new ApiError(400, 'Customer name is required.');

  const shopId = shopFilter(req);
  if (!shopId) throw new ApiError(400, 'shopId is required.');

  const customer = await Customer.create({
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
    actionType: 'CREATE_CUSTOMER',
    module: 'customers',
    recordId: customer._id,
    recordType: 'Customer',
    newData: customer.toObject(),
    remarks: `Customer "${customer.name}" added`,
    shopId,
  });

  res.status(201).json(ApiResponse.created('Customer added successfully', customer));
});

const updateCustomer = asyncHandler(async (req, res) => {
  const customer = await Customer.findById(req.params.id);
  if (!customer || customer.isDeleted) throw new ApiError(404, 'Customer not found.');
  if (req.user.role === 'manager' && customer.shop.toString() !== req.user.assignedShop._id.toString()) {
    throw new ApiError(403, 'You can only manage customers of your assigned shop.');
  }
  const oldData = customer.toObject();

  const allowed = ['name', 'phone', 'email', 'address', 'city', 'notes'];
  allowed.forEach((field) => {
    if (req.body[field] !== undefined) customer[field] = req.body[field];
  });
  await customer.save();

  await recordAudit(req, {
    actionType: 'UPDATE_CUSTOMER',
    module: 'customers',
    recordId: customer._id,
    recordType: 'Customer',
    oldData,
    newData: customer.toObject(),
    remarks: `Customer "${customer.name}" updated`,
    shopId: customer.shop,
  });

  res.json(ApiResponse.ok('Customer updated', customer));
});

const deleteCustomer = asyncHandler(async (req, res) => {
  const { deleteReason } = req.body;
  const customer = await Customer.findById(req.params.id);
  if (!customer) throw new ApiError(404, 'Customer not found.');
  if (req.user.role === 'manager' && customer.shop.toString() !== req.user.assignedShop._id.toString()) {
    throw new ApiError(403, 'You can only manage customers of your assigned shop.');
  }
  const oldData = customer.toObject();

  customer.isDeleted = true;
  customer.deletedBy = req.user._id;
  customer.deletedAt = new Date();
  customer.deleteReason = deleteReason || '';
  await customer.save();

  await recordAudit(req, {
    actionType: 'DELETE_CUSTOMER',
    module: 'customers',
    recordId: customer._id,
    recordType: 'Customer',
    oldData,
    newData: null,
    status: 'deleted',
    remarks: `Customer "${customer.name}" soft-deleted`,
    shopId: customer.shop,
  });

  res.json(ApiResponse.ok('Customer deleted'));
});

const restoreCustomer = asyncHandler(async (req, res) => {
  const customer = await Customer.findById(req.params.id);
  if (!customer) throw new ApiError(404, 'Customer not found.');

  customer.isDeleted = false;
  customer.deletedBy = null;
  customer.deletedAt = null;
  customer.deleteReason = '';
  await customer.save();

  await recordAudit(req, {
    actionType: 'RESTORE_CUSTOMER',
    module: 'customers',
    recordId: customer._id,
    recordType: 'Customer',
    oldData: null,
    newData: customer.toObject(),
    status: 'restored',
    remarks: `Customer "${customer.name}" restored`,
    shopId: customer.shop,
  });

  res.json(ApiResponse.ok('Customer restored', customer));
});

// Adjust the outstanding balance: type "charge" increases the due amount
// (e.g. credit sale), type "payment" reduces it (customer paid).
const adjustBalance = asyncHandler(async (req, res) => {
  const { amount, type, note } = req.body;
  const value = Number(amount);
  if (!value || value <= 0) throw new ApiError(400, 'A positive amount is required.');
  if (!['charge', 'payment'].includes(type)) {
    throw new ApiError(400, 'Type must be "charge" or "payment".');
  }

  const customer = await Customer.findById(req.params.id);
  if (!customer || customer.isDeleted) throw new ApiError(404, 'Customer not found.');
  if (req.user.role === 'manager' && customer.shop.toString() !== req.user.assignedShop._id.toString()) {
    throw new ApiError(403, 'You can only manage customers of your assigned shop.');
  }
  const oldData = customer.toObject();

  if (type === 'charge') {
    customer.balance += value;
  } else {
    customer.balance = Math.max(0, customer.balance - value);
  }
  customer.transactions.push({
    amount: value,
    type,
    note: note || (type === 'charge' ? 'Due added' : 'Payment received'),
    date: new Date(),
    by: req.user._id,
  });
  await customer.save();

  await recordAudit(req, {
    actionType: type === 'charge' ? 'CREATE_CUSTOMER' : 'UPDATE_CUSTOMER',
    module: 'customers',
    recordId: customer._id,
    recordType: 'Customer',
    oldData: { balance: oldData.balance },
    newData: { balance: customer.balance, adjustment: value, type },
    remarks: type === 'charge'
        ? `Due Rs. ${value} added for "${customer.name}"`
        : `Payment Rs. ${value} received from "${customer.name}"`,
    shopId: customer.shop,
  });

  res.json(ApiResponse.ok(type === 'charge' ? 'Due amount added' : 'Payment recorded', customer));
});

module.exports = {
  listCustomers,
  getCustomer,
  createCustomer,
  updateCustomer,
  deleteCustomer,
  restoreCustomer,
  adjustBalance,
};
