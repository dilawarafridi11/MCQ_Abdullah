require('dotenv').config();
const connectDB = require('../config/db');
const config = require('../config');
const User = require('../models/User');
const Shop = require('../models/Shop');
const Category = require('../models/Category');
const Product = require('../models/Product');
const Sale = require('../models/Sale');
const Expense = require('../models/Expense');
const InventoryLog = require('../models/InventoryLog');
const AuditLog = require('../models/AuditLog');
const Notification = require('../models/Notification');

const CATEGORIES = [
  { name: 'Persian Carpets', description: 'Hand-knotted Persian masterpieces' },
  { name: 'Afghan Carpets', description: 'Authentic Afghan wool carpets' },
  { name: 'Turkish Carpets', description: 'Classic Turkish designs' },
  { name: 'Handmade Carpets', description: 'Premium handmade pieces' },
  { name: 'Machine Made Carpets', description: 'Affordable machine woven carpets' },
  { name: 'Prayer Rugs', description: 'Prayer mats and rugs' },
  { name: 'Luxury Carpets', description: 'Exclusive luxury carpets' },
];

const SHOPS = [
  { name: 'Branch 1', address: 'Main Bazaar, Peshawar', contactNumber: '+92 300 1111111' },
  { name: 'Branch 2', address: 'Kababian Street, Peshawar', contactNumber: '+92 300 2222222' },
  { name: 'Warehouse', address: 'Mall Road, Lahore', contactNumber: '+92 300 3333333' },
];

const MANAGERS = [
  { name: 'Israr', email: 'israr@muallimcarpets.com', phone: '+92 300 1112222' },
  { name: 'Farooq', email: 'farooq@muallimcarpets.com', phone: '+92 300 2223333' },
  { name: 'Dost Muhammad', email: 'dostmuhammad@muallimcarpets.com', phone: '+92 300 3334444' },
];

const PRODUCT_TEMPLATES = [
  { name: 'Persian Kashan Carpet 6x4', brand: 'Kashan', costPrice: 18000, sellingPrice: 25000, category: 'Persian Carpets', lowStockThreshold: 3 },
  { name: 'Persian Nain Carpet 8x5', brand: 'Nain', costPrice: 35000, sellingPrice: 48000, category: 'Persian Carpets', lowStockThreshold: 2 },
  { name: 'Afghan Kunduz Carpet 9x6', brand: 'Kunduz', costPrice: 22000, sellingPrice: 32000, category: 'Afghan Carpets', lowStockThreshold: 3 },
  { name: 'Afghan Beluch Runner 12x3', brand: 'Beluch', costPrice: 15000, sellingPrice: 21000, category: 'Afghan Carpets', lowStockThreshold: 3 },
  { name: 'Turkish Hereke Carpet 7x5', brand: 'Hereke', costPrice: 40000, sellingPrice: 55000, category: 'Turkish Carpets', lowStockThreshold: 2 },
  { name: 'Handmade Wool Carpet 6x4', brand: 'MC Custom', costPrice: 16000, sellingPrice: 23000, category: 'Handmade Carpets', lowStockThreshold: 4 },
  { name: 'Machine Made Carpet 8x10', brand: 'MC Modern', costPrice: 8000, sellingPrice: 12500, category: 'Machine Made Carpets', lowStockThreshold: 5 },
  { name: 'Silk Prayer Rug', brand: 'MC Silk', costPrice: 5000, sellingPrice: 8000, category: 'Prayer Rugs', lowStockThreshold: 6 },
  { name: 'Luxury Gold Border Carpet', brand: 'MC Lux', costPrice: 60000, sellingPrice: 85000, category: 'Luxury Carpets', lowStockThreshold: 1 },
];

const EXPENSE_CATEGORIES = ['rent', 'electricity', 'salary', 'fuel', 'internet', 'maintenance', 'marketing', 'other'];
const PAYMENT_METHODS = ['cash', 'bank', 'easypaisa', 'jazzcash'];

const rand = (min, max) => Math.floor(Math.random() * (max - min + 1)) + min;
const pick = (arr) => arr[rand(0, arr.length - 1)];
const daysAgo = (days) => new Date(Date.now() - days * 86400000);

const seed = async () => {
  await connectDB();

  await Promise.all([
    User.deleteMany({}),
    Shop.deleteMany({}),
    Category.deleteMany({}),
    Product.deleteMany({}),
    Sale.deleteMany({}),
    Expense.deleteMany({}),
    InventoryLog.deleteMany({}),
    AuditLog.deleteMany({}),
    Notification.deleteMany({}),
  ]);
  console.log('Cleared existing data');

  const admin = await User.create({
    name: config.admin.name,
    email: config.admin.email,
    password: config.admin.password,
    phone: '+92 300 0000000',
    role: 'admin',
  });
  console.log(`Admin created: ${admin.email} / ${config.admin.password}`);

  const categories = {};
  for (const c of CATEGORIES) {
    categories[c.name] = await Category.create(c);
  }

  const shops = [];
  for (let i = 0; i < SHOPS.length; i++) {
    const manager = await User.create({
      name: MANAGERS[i].name,
      email: MANAGERS[i].email,
      password: config.managerPassword,
      phone: MANAGERS[i].phone,
      role: 'manager',
    });
    const shop = await Shop.create({ ...SHOPS[i], manager: manager._id });
    manager.assignedShop = shop._id;
    await manager.save();
    shops.push(shop);
    console.log(`Manager created: ${manager.email} / ${config.managerPassword} -> ${shop.name}`);
  }

  const products = [];
  let idx = 0;
  for (const shop of shops) {
    for (const t of PRODUCT_TEMPLATES) {
      idx++;
      const qty = rand(5, 25);
      const product = await Product.create({
        name: t.name,
        sku: `SKU-${shop.name.replace(' ', '').slice(-1)}-${String(idx).padStart(3, '0')}`,
        barcode: `890${String(idx).padStart(10, '0')}`,
        category: categories[t.category]._id,
        brand: t.brand,
        supplier: `Supplier ${rand(1, 5)}`,
        costPrice: t.costPrice,
        sellingPrice: t.sellingPrice,
        quantity: qty,
        lowStockThreshold: t.lowStockThreshold,
        description: `${t.name} - premium quality carpet from Muallim Carpets.`,
        shop: shop._id,
      });
      products.push(product);
    }
  }
  console.log(`Created ${products.length} products`);

  // Sales over last 60 days
  let salesCount = 0;
  for (let day = 0; day < 60; day++) {
    const daily = rand(2, 8);
    for (let s = 0; s < daily; s++) {
      const shop = pick(shops);
      const product = pick(products.filter((p) => p.shop.toString() === shop._id.toString()));
      const qty = rand(1, 3);
      const discount = rand(0, 2) === 0 ? rand(0, 2000) : 0;
      const items = [{
        product: product._id,
        productName: product.name,
        quantity: qty,
        unitPrice: product.sellingPrice,
        totalAmount: product.sellingPrice * qty,
        costPrice: product.costPrice,
      }];
      const subtotal = product.sellingPrice * qty;
      const createdAt = daysAgo(day);
      await Sale.create({
        invoiceNo: `INV-${createdAt.getFullYear()}${String(createdAt.getMonth() + 1).padStart(2, '0')}${String(createdAt.getDate()).padStart(2, '0')}-${String(1000 + salesCount)}`,
        shop: shop._id,
        customerName: pick(['Walk-in Customer', 'Ahmad Raza', 'Sanaullah', 'Kamran', 'Usman', 'Faisal']),
        customerPhone: `03${rand(0, 9)}${rand(1000000, 9999999)}`,
        items,
        subtotal,
        discount,
        totalAmount: subtotal - discount,
        profit: (product.sellingPrice - product.costPrice) * qty,
        paymentMethod: pick(PAYMENT_METHODS),
        notes: '',
        createdBy: shop.manager,
        createdAt,
      });
      salesCount++;
    }
  }
  console.log(`Created ${salesCount} sales`);

  // Expenses over last 60 days
  let expCount = 0;
  for (let day = 0; day < 60; day++) {
    for (const shop of shops) {
      if (rand(0, 1) === 0) continue;
      const expenseDate = daysAgo(day);
      const amount = pick([3000, 5000, 8000, 12000, 15000, 20000, 25000, 35000, 5000]);
      await Expense.create({
        shop: shop._id,
        category: pick(EXPENSE_CATEGORIES),
        amount,
        expenseDate,
        description: `${pick(EXPENSE_CATEGORIES)} expense recorded`,
        createdBy: shop.manager,
      });
      expCount++;
    }
  }
  console.log(`Created ${expCount} expenses`);

  // Initial inventory logs
  for (const product of products) {
    await InventoryLog.create({
      shop: product.shop,
      product: product._id,
      productName: product.name,
      actionType: 'stock_in',
      quantity: product.quantity,
      previousStock: 0,
      newStock: product.quantity,
      supplier: product.supplier,
      reason: 'Initial stock',
      date: daysAgo(rand(10, 70)),
      performedBy: (await Shop.findById(product.shop)).manager,
    });
  }

  console.log('\nSeed complete!');
  console.log('=========================================');
  console.log(`Admin   : ${admin.email}  /  ${config.admin.password}`);
  MANAGERS.forEach((m, i) => {
    console.log(`${SHOPS[i].name} manager: ${m.email}  /  ${config.managerPassword}`);
  });
  console.log('=========================================');
  process.exit(0);
};

seed().catch((err) => {
  console.error('Seed failed:', err);
  process.exit(1);
});
