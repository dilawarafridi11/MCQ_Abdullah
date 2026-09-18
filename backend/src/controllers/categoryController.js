const Category = require('../models/Category');
const ApiError = require('../utils/ApiError');
const asyncHandler = require('../utils/asyncHandler');
const ApiResponse = require('../utils/ApiResponse');
const { recordAudit } = require('../middleware/auth');

const listCategories = asyncHandler(async (req, res) => {
  const categories = await Category.find({ isDeleted: false }).sort({ name: 1 });
  res.json(ApiResponse.ok('Categories fetched', categories));
});

const createCategory = asyncHandler(async (req, res) => {
  const { name, description } = req.body;
  if (!name) throw new ApiError(400, 'Category name is required.');

  const category = await Category.create({ name, description: description || '' });

  await recordAudit(req, {
    actionType: 'CREATE_CATEGORY',
    module: 'categories',
    recordId: category._id,
    recordType: 'Category',
    newData: category.toObject(),
    remarks: `Category "${category.name}" created`,
  });

  res.status(201).json(ApiResponse.created('Category created', category));
});

const updateCategory = asyncHandler(async (req, res) => {
  const category = await Category.findById(req.params.id);
  if (!category || category.isDeleted) throw new ApiError(404, 'Category not found.');
  const oldData = category.toObject();

  const { name, description } = req.body;
  if (name !== undefined) category.name = name;
  if (description !== undefined) category.description = description;
  await category.save();

  await recordAudit(req, {
    actionType: 'UPDATE_CATEGORY',
    module: 'categories',
    recordId: category._id,
    recordType: 'Category',
    oldData,
    newData: category.toObject(),
    remarks: `Category "${category.name}" updated`,
  });

  res.json(ApiResponse.ok('Category updated', category));
});

const deleteCategory = asyncHandler(async (req, res) => {
  const { deleteReason } = req.body;
  const category = await Category.findById(req.params.id);
  if (!category) throw new ApiError(404, 'Category not found.');

  const oldData = category.toObject();
  category.isDeleted = true;
  category.deletedBy = req.user._id;
  category.deletedAt = new Date();
  category.deleteReason = deleteReason || '';
  await category.save();

  await recordAudit(req, {
    actionType: 'DELETE_CATEGORY',
    module: 'categories',
    recordId: category._id,
    recordType: 'Category',
    oldData,
    newData: null,
    status: 'deleted',
    remarks: `Category "${category.name}" soft-deleted`,
  });

  res.json(ApiResponse.ok('Category deleted'));
});

const restoreCategory = asyncHandler(async (req, res) => {
  const category = await Category.findById(req.params.id);
  if (!category) throw new ApiError(404, 'Category not found.');

  category.isDeleted = false;
  category.deletedBy = null;
  category.deletedAt = null;
  category.deleteReason = '';
  await category.save();

  await recordAudit(req, {
    actionType: 'RESTORE_CATEGORY',
    module: 'categories',
    recordId: category._id,
    recordType: 'Category',
    oldData: null,
    newData: category.toObject(),
    status: 'restored',
    remarks: `Category "${category.name}" restored`,
  });

  res.json(ApiResponse.ok('Category restored', category));
});

module.exports = { listCategories, createCategory, updateCategory, deleteCategory, restoreCategory };
