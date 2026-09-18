// One-off backfill: build Customer + Supplier records from existing sales and
// product data so the new CRM modules are populated with real data.
//
// Usage: node src/scripts/backfillCustomersSuppliers.js
require('dotenv').config();
const connectDB = require('../config/db');
const Shop = require('../models/Shop');
const Sale = require('../models/Sale');
const Product = require('../models/Product');
const Customer = require('../models/Customer');
const Supplier = require('../models/Supplier');

const run = async () => {
  await connectDB();

  const shops = await Shop.find({ isDeleted: false });
  let customers = 0;
  let suppliers = 0;

  for (const shop of shops) {
    const saleGroups = await Sale.aggregate([
      { $match: { isDeleted: false, shop: shop._id } },
      {
        $group: {
          _id: {
            name: { $trim: { input: { $ifNull: ['$customerName', 'Walk-in Customer'] } } },
            phone: { $ifNull: ['$customerPhone', ''] },
          },
          totalSpent: { $sum: '$totalAmount' },
          purchaseCount: { $sum: 1 },
          lastPurchaseAt: { $max: '$createdAt' },
        },
      },
    ]);

    for (const g of saleGroups) {
      if (g._id.phone) {
        await Customer.findOneAndUpdate(
          { shop: shop._id, phone: g._id.phone, isDeleted: false },
          {
            $set: {
              name: g._id.name,
              phone: g._id.phone,
              shop: shop._id,
              createdBy: shop.manager,
              totalSpent: g.totalSpent,
              purchaseCount: g.purchaseCount,
              lastPurchaseAt: g.lastPurchaseAt,
            },
          },
          { upsert: true }
        );
        customers++;
      }
    }

    const supplierNames = await Product.distinct('supplier', {
      isDeleted: false,
      shop: shop._id,
      supplier: { $ne: '' },
    });
    for (const name of supplierNames) {
      await Supplier.findOneAndUpdate(
        { shop: shop._id, name, isDeleted: false },
        { $set: { name, shop: shop._id, createdBy: shop.manager } },
        { upsert: true }
      );
      suppliers++;
    }
  }

  console.log(`Backfill complete. Customers: ${customers}, Suppliers: ${suppliers}.`);
  process.exit(0);
};

run().catch((err) => {
  console.error('Backfill failed:', err);
  process.exit(1);
});
