const mongoose = require('mongoose');

const qaleenSizeSchema = new mongoose.Schema(
  { height: { type: Number, required: true }, width: { type: Number, required: true }, pieces: { type: Number, required: true, min: 1 } },
  { _id: false }
);

const carpetPieceSchema = new mongoose.Schema(
  {
    width: { type: Number, required: true },
    height: { type: Number, required: true },
    area: { type: Number, default: 0 },
    color: { type: String, default: '' },
    image: { type: String, default: '' },
  },
  { _id: false }
);

const colorStockSchema = new mongoose.Schema(
  {
    color: { type: String, required: true, trim: true },
    sets: { type: Number, default: 0, min: 0 },
    pieces: { type: Number, default: 0, min: 0 },
  },
  { _id: false }
);

const productSchema = new mongoose.Schema(
  {
    name: { type: String, required: true, trim: true },
    sku: { type: String, default: '', trim: true },
    barcode: { type: String, default: '', trim: true },
    category: { type: mongoose.Schema.Types.ObjectId, ref: 'Category', default: null },
    brand: { type: String, default: '' },
    supplier: { type: String, default: '' },
    productType: { type: String, enum: ['carpet', 'qaleen', 'meter'], default: 'qaleen' },

    carpetWidth: { type: Number, default: 0 },
    carpetHeight: { type: Number, default: 0 },
    carpetPieces: { type: Number, default: 0 },
    carpetPiecesData: { type: [carpetPieceSchema], default: [] },
    costPerSqft: { type: Number, default: 0 },

    costPerPiece: { type: Number, default: 0 },
    qaleenSizes: { type: [qaleenSizeSchema], default: [] },

    meterLength: { type: Number, default: 0 },
    costPerMeter: { type: Number, default: 0 },

    costPrice: { type: Number, required: true, min: 0, default: 0 },
    sellingPrice: { type: Number, min: 0, default: 0 },
    quantity: { type: Number, required: true, min: 0, default: 0 },
    lowStockThreshold: { type: Number, default: 5 },
    color: { type: String, default: '' },
    size: { type: String, default: '' },
    description: { type: String, default: '' },
    images: { type: [String], default: [] },
    colorStocks: { type: [colorStockSchema], default: [] },
    shop: { type: mongoose.Schema.Types.ObjectId, ref: 'Shop', required: true },
    isDeleted: { type: Boolean, default: false },
    deletedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User', default: null },
    deletedAt: { type: Date, default: null },
    deleteReason: { type: String, default: '' },
  },
  { timestamps: true }
);

productSchema.index({ shop: 1, isDeleted: 1 });
productSchema.index({ name: 'text', sku: 'text', barcode: 'text' });

module.exports = mongoose.model('Product', productSchema);
