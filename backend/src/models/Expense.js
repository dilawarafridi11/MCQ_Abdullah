const mongoose = require('mongoose');

const expenseSchema = new mongoose.Schema(
  {
    shop: { type: mongoose.Schema.Types.ObjectId, ref: 'Shop', required: true },
    category: {
      type: String,
      enum: [
        'rent',
        'electricity',
        'salary',
        'fuel',
        'internet',
        'maintenance',
        'marketing',
        'other',
      ],
      default: 'other',
    },
    amount: { type: Number, required: true, min: 0 },
    expenseDate: { type: Date, default: Date.now },
    description: { type: String, default: '' },
    createdBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    isDeleted: { type: Boolean, default: false },
    deletedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User', default: null },
    deletedAt: { type: Date, default: null },
    deleteReason: { type: String, default: '' },
  },
  { timestamps: true }
);

expenseSchema.index({ shop: 1, expenseDate: -1 });
expenseSchema.index({ isDeleted: 1 });

module.exports = mongoose.model('Expense', expenseSchema);
