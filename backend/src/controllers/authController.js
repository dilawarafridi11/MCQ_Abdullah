const User = require('../models/User');
const ApiError = require('../utils/ApiError');
const asyncHandler = require('../utils/asyncHandler');
const ApiResponse = require('../utils/ApiResponse');
const { signToken, parseDeviceInfo } = require('../utils/jwt');
const { recordAudit } = require('../middleware/auth');

const looksLikeEmail = (value) => /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value.trim());

// Normalise a phone number: strip spaces, dashes, parens; keep leading '+'.
const normalizePhone = (value) => String(value).trim().replace(/[\s\-()]/g, '');

const findLoginUser = (identifier) => {
  const id = identifier.trim();
  if (looksLikeEmail(id)) {
    return User.findOne({ email: id.toLowerCase() })
      .select('+password')
      .populate('assignedShop');
  }
  const normalized = normalizePhone(id);
  return User.findOne({
    $or: [{ phone: normalized }, { phone: id }],
  })
    .select('+password')
    .populate('assignedShop');
};

const login = asyncHandler(async (req, res) => {
  const { identifier, email, phone, password, shopId } = req.body;
  const id = identifier || email || phone;
  if (!password) throw new ApiError(400, 'Password is required.');
  if (!id) throw new ApiError(400, 'Email or phone number is required.');

  const user = await findLoginUser(id);
  if (!user || !(await user.comparePassword(password))) {
    throw new ApiError(401, 'Invalid credentials.');
  }
  if (!user.isActive) throw new ApiError(403, 'Your account has been deactivated.');

  if (user.role === 'manager') {
    if (!user.assignedShop) {
      throw new ApiError(403, 'No shop is assigned to your account. Contact the admin.');
    }
    if (shopId && shopId.toString() !== user.assignedShop._id.toString()) {
      throw new ApiError(400, 'The selected shop does not match your assigned shop.');
    }
  }

  user.lastLoginAt = new Date();
  if (req.body.fcmToken) user.fcmToken = req.body.fcmToken;
  await user.save({ validateBeforeSave: false });

  const device = parseDeviceInfo(req);
  req.user = user;
  await recordAudit(req, {
    actionType: 'LOGIN',
    module: 'auth',
    recordId: user._id,
    recordType: 'User',
    remarks: `${user.role.toUpperCase()} ${user.name} logged in`,
    shopId: user.assignedShop ? user.assignedShop._id : null,
    shopName: user.assignedShop ? user.assignedShop.name : '',
  });

  const token = signToken(user._id, user.role, user.assignedShop?._id);

  res.json(ApiResponse.ok('Login successful', { token, user: user.toPublicJSON() }));
});

const previewLogin = asyncHandler(async (req, res) => {
  const id = (req.query.identifier || req.query.email || '').trim();
  if (!id) throw new ApiError(400, 'Email or phone number is required.');

  const user = await findLoginUser(id);
  if (!user) {
    res.json(ApiResponse.ok('Login preview fetched', { exists: false }));
    return;
  }

  const shops =
    user.role === 'manager'
      ? user.assignedShop
        ? [
            {
              id: user.assignedShop._id.toString(),
              name: user.assignedShop.name,
            },
          ]
        : []
      : [];

  res.json(
    ApiResponse.ok('Login preview fetched', {
      exists: true,
      role: user.role,
      name: user.name,
      active: user.isActive,
      shops,
    })
  );
});

const logout = asyncHandler(async (req, res) => {
  if (req.user) {
    if (req.body.fcmToken) {
      await User.findByIdAndUpdate(req.user._id, { $set: { fcmToken: null } });
    }
    await recordAudit(req, {
      actionType: 'LOGOUT',
      module: 'auth',
      recordId: req.user._id,
      recordType: 'User',
      remarks: `${req.user.name} logged out`,
      shopId: req.user.assignedShop ? req.user.assignedShop._id : null,
      shopName: req.user.assignedShop ? req.user.assignedShop.name : '',
    });
  }
  res.json(ApiResponse.ok('Logout successful'));
});

const getProfile = asyncHandler(async (req, res) => {
  const user = await User.findById(req.user._id).populate('assignedShop');
  res.json(ApiResponse.ok('Profile fetched', user.toPublicJSON()));
});

const updateProfile = asyncHandler(async (req, res) => {
  const { name, phone, email, notificationEnabled } = req.body;
  const oldData = req.user.toPublicJSON();

  const user = await User.findById(req.user._id);
  if (name !== undefined) user.name = name;
  if (phone !== undefined) user.phone = phone;
  if (notificationEnabled !== undefined) user.notificationEnabled = notificationEnabled;
  if (email !== undefined) {
    const exists = await User.findOne({ email: email.toLowerCase(), _id: { $ne: user._id } });
    if (exists) throw new ApiError(409, 'Email already in use.');
    user.email = email;
  }
  await user.save();
  await user.populate('assignedShop');

  await recordAudit(req, {
    actionType: 'UPDATE_USER',
    module: 'users',
    recordId: user._id,
    recordType: 'User',
    oldData,
    newData: user.toPublicJSON(),
    remarks: 'Profile updated',
    shopId: user.assignedShop ? user.assignedShop._id : null,
    shopName: user.assignedShop ? user.assignedShop.name : '',
  });

  res.json(ApiResponse.ok('Profile updated', user.toPublicJSON()));
});

const changePassword = asyncHandler(async (req, res) => {
  const { currentPassword, newPassword } = req.body;
  if (!currentPassword || !newPassword) {
    throw new ApiError(400, 'Current and new password are required.');
  }
  if (newPassword.length < 6) throw new ApiError(400, 'New password must be at least 6 characters.');

  const user = await User.findById(req.user._id).select('+password');
  if (!(await user.comparePassword(currentPassword))) {
    throw new ApiError(400, 'Current password is incorrect.');
  }
  user.password = newPassword;
  await user.save();

  await recordAudit(req, {
    actionType: 'UPDATE_USER',
    module: 'users',
    recordId: user._id,
    recordType: 'User',
    remarks: 'Password changed',
    shopId: user.assignedShop ? user.assignedShop._id : null,
    shopName: user.assignedShop ? user.assignedShop.name : '',
  });

  res.json(ApiResponse.ok('Password changed successfully'));
});

const registerManager = asyncHandler(async (req, res) => {
  const { name, email, password, phone, assignedShop } = req.body;
  if (!name) throw new ApiError(400, 'Name is required.');
  if (!email && !phone) throw new ApiError(400, 'Email or phone number is required.');
  if (!password) throw new ApiError(400, 'Password is required.');

  const normalizedPhone = phone ? normalizePhone(phone) : '';

  if (email) {
    const exists = await User.findOne({ email: email.toLowerCase() });
    if (exists) throw new ApiError(409, 'A user with this email already exists.');
  }
  if (normalizedPhone) {
    const exists = await User.findOne({ phone: normalizedPhone });
    if (exists) throw new ApiError(409, 'A user with this phone number already exists.');
  }

  const user = await User.create({
    name,
    email,
    password,
    phone: normalizedPhone,
    role: 'manager',
    assignedShop: assignedShop || null,
  });

  await recordAudit(req, {
    actionType: 'CREATE_USER',
    module: 'users',
    recordId: user._id,
    recordType: 'Manager',
    newData: user.toPublicJSON(),
    remarks: `Manager ${user.name} created`,
    shopId: assignedShop || null,
  });

  res.status(201).json(ApiResponse.created('Manager created', user.toPublicJSON()));
});

const listManagers = asyncHandler(async (req, res) => {
  const managers = await User.find({ role: 'manager' })
    .populate('assignedShop', 'name address')
    .select('-password')
    .sort({ createdAt: -1 });
  res.json(ApiResponse.ok('Managers fetched', managers));
});

const updateManager = asyncHandler(async (req, res) => {
  const manager = await User.findById(req.params.id);
  if (!manager || manager.role !== 'manager') throw new ApiError(404, 'Manager not found.');
  const oldData = manager.toPublicJSON();

  const { name, phone, email, assignedShop, isActive } = req.body;
  if (name !== undefined) manager.name = name;
  if (phone !== undefined) manager.phone = normalizePhone(phone);
  if (assignedShop !== undefined) manager.assignedShop = assignedShop;
  if (isActive !== undefined) manager.isActive = isActive;
  if (email !== undefined) {
    const exists = await User.findOne({ email: email.toLowerCase(), _id: { $ne: manager._id } });
    if (exists) throw new ApiError(409, 'Email already in use.');
    manager.email = email;
  }
  await manager.save();
  await manager.populate('assignedShop', 'name address');

  await recordAudit(req, {
    actionType: 'UPDATE_USER',
    module: 'users',
    recordId: manager._id,
    recordType: 'Manager',
    oldData,
    newData: manager.toPublicJSON(),
    remarks: 'Manager updated',
  });

  res.json(ApiResponse.ok('Manager updated', manager.toPublicJSON()));
});

module.exports = {
  login,
  previewLogin,
  logout,
  getProfile,
  updateProfile,
  changePassword,
  registerManager,
  listManagers,
  updateManager,
};
