const mongoose = require('mongoose');

const balanceTransactionSchema = new mongoose.Schema(
  {
    amount: { type: Number, required: true, min: 0 },
    type: { type: String, enum: ['charge', 'payment'], required: true },
    note: { type: String, default: '' },
    date: { type: Date, default: Date.now },
    by: { type: mongoose.Schema.Types.ObjectId, ref: 'User', default: null },
  },
  { _id: false }
);

const customerSchema = new mongoose.Schema(
  {
    name: { type: String, required: true, trim: true },
    phone: { type: String, default: '', trim: true },
    email: { type: String, default: '', trim: true },
    address: { type: String, default: '' },
    city: { type: String, default: '' },
    notes: { type: String, default: '' },
    balance: { type: Number, default: 0, min: 0 },
    totalSpent: { type: Number, default: 0, min: 0 },
    purchaseCount: { type: Number, default: 0, min: 0 },
    lastPurchaseAt: { type: Date, default: null },
    transactions: { type: [balanceTransactionSchema], default: [] },
    shop: { type: mongoose.Schema.Types.ObjectId, ref: 'Shop', required: true },
    createdBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User', default: null },
    isDeleted: { type: Boolean, default: false },
    deletedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User', default: null },
    deletedAt: { type: Date, default: null },
    deleteReason: { type: String, default: '' },
  },
  { timestamps: true }
);

customerSchema.index({ shop: 1, isDeleted: 1 });
customerSchema.index({ shop: 1, phone: 1 });
customerSchema.index({ name: 'text', phone: 'text', email: 'text' });

module.exports = mongoose.model('Customer', customerSchema);
