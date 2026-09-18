const Expense = require('../models/Expense');
const Notification = require('../models/Notification');
const ApiError = require('../utils/ApiError');
const asyncHandler = require('../utils/asyncHandler');
const ApiResponse = require('../utils/ApiResponse');
const { recordAudit } = require('../middleware/auth');

const listExpenses = asyncHandler(async (req, res) => {
  const page = parseInt(req.query.page, 10) || 1;
  const limit = parseInt(req.query.limit, 10) || 30;
  const filter = { isDeleted: false };
  if (req.user.role === 'manager') filter.shop = req.user.assignedShop._id;
  else if (req.shopId) filter.shop = req.shopId;
  if (req.query.category) filter.category = req.query.category;
  if (req.query.from || req.query.to) {
    filter.expenseDate = {};
    if (req.query.from) filter.expenseDate.$gte = new Date(req.query.from);
    if (req.query.to) filter.expenseDate.$lte = new Date(req.query.to);
  }

  const [expenses, total] = await Promise.all([
    Expense.find(filter)
      .populate('shop', 'name')
      .populate('createdBy', 'name role')
      .sort({ expenseDate: -1 })
      .skip((page - 1) * limit)
      .limit(limit),
    Expense.countDocuments(filter),
  ]);

  res.json(ApiResponse.ok('Expenses fetched', { expenses, total, page, limit, totalPages: Math.ceil(total / limit) }));
});

const createExpense = asyncHandler(async (req, res) => {
  const { category, amount, expenseDate, description } = req.body;
  if (!category) throw new ApiError(400, 'Expense category is required.');
  if (amount === undefined || amount < 0) throw new ApiError(400, 'A valid amount is required.');

  const shopId =
    req.user.role === 'manager'
      ? req.user.assignedShop._id
      : req.body.shopId || (await require('../models/Shop').findOne({ isDeleted: false }))._id;
  if (!shopId) throw new ApiError(400, 'shopId is required.');

  const expense = await Expense.create({
    shop: shopId,
    category,
    amount,
    expenseDate: expenseDate || new Date(),
    description: description || '',
    createdBy: req.user._id,
  });

  await recordAudit(req, {
    actionType: 'CREATE_EXPENSE',
    module: 'expenses',
    recordId: expense._id,
    recordType: 'Expense',
    newData: expense.toObject(),
    remarks: `Expense ${category} Rs. ${amount} recorded`,
    shopId,
  });

  const Shop = require('../models/Shop');
  const User = require('../models/User');
  const shop = await Shop.findById(shopId);
  const admins = await User.find({ role: 'admin', isActive: true });
  if (admins.length) {
    await Notification.insertMany(
      admins.map((admin) => ({
        user: admin._id,
        title: 'Expense Recorded',
        body: `Rs. ${amount} ${category} expense recorded${shop ? ` at ${shop.name}` : ''}`,
        type: 'expense_alert',
        data: { expenseId: expense._id },
      }))
    );
  }

  res.status(201).json(ApiResponse.created('Expense recorded', expense));
});

const updateExpense = asyncHandler(async (req, res) => {
  const expense = await Expense.findById(req.params.id);
  if (!expense || expense.isDeleted) throw new ApiError(404, 'Expense not found.');
  if (req.user.role === 'manager' && expense.shop.toString() !== req.user.assignedShop._id.toString()) {
    throw new ApiError(403, 'You can only manage expenses of your assigned shop.');
  }
  const oldData = expense.toObject();

  const { category, amount, expenseDate, description } = req.body;
  if (category !== undefined) expense.category = category;
  if (amount !== undefined) expense.amount = amount;
  if (expenseDate !== undefined) expense.expenseDate = expenseDate;
  if (description !== undefined) expense.description = description;
  await expense.save();

  await recordAudit(req, {
    actionType: 'UPDATE_EXPENSE',
    module: 'expenses',
    recordId: expense._id,
    recordType: 'Expense',
    oldData,
    newData: expense.toObject(),
    remarks: `Expense ${expense.category} updated`,
    shopId: expense.shop,
  });

  res.json(ApiResponse.ok('Expense updated', expense));
});

const deleteExpense = asyncHandler(async (req, res) => {
  const { deleteReason } = req.body;
  const expense = await Expense.findById(req.params.id);
  if (!expense) throw new ApiError(404, 'Expense not found.');
  if (req.user.role === 'manager' && expense.shop.toString() !== req.user.assignedShop._id.toString()) {
    throw new ApiError(403, 'You can only manage expenses of your assigned shop.');
  }
  const oldData = expense.toObject();

  expense.isDeleted = true;
  expense.deletedBy = req.user._id;
  expense.deletedAt = new Date();
  expense.deleteReason = deleteReason || '';
  await expense.save();

  await recordAudit(req, {
    actionType: 'DELETE_EXPENSE',
    module: 'expenses',
    recordId: expense._id,
    recordType: 'Expense',
    oldData,
    newData: null,
    status: 'deleted',
    remarks: `Expense ${expense.category} soft-deleted`,
    shopId: expense.shop,
  });

  res.json(ApiResponse.ok('Expense deleted'));
});

const restoreExpense = asyncHandler(async (req, res) => {
  const expense = await Expense.findById(req.params.id);
  if (!expense) throw new ApiError(404, 'Expense not found.');

  expense.isDeleted = false;
  expense.deletedBy = null;
  expense.deletedAt = null;
  expense.deleteReason = '';
  await expense.save();

  await recordAudit(req, {
    actionType: 'RESTORE_EXPENSE',
    module: 'expenses',
    recordId: expense._id,
    recordType: 'Expense',
    oldData: null,
    newData: expense.toObject(),
    status: 'restored',
    remarks: `Expense ${expense.category} restored`,
    shopId: expense.shop,
  });

  res.json(ApiResponse.ok('Expense restored', expense));
});

module.exports = { listExpenses, createExpense, updateExpense, deleteExpense, restoreExpense };
