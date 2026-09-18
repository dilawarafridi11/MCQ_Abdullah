/**
 * One-time data fix: carpet/meter products previously stored `costPrice`
 * as the TOTAL (qty * per-unit rate) instead of the per-unit rate.
 *
 * `costPrice` must be per-unit (per sqft / per meter) so that
 *   stock value = qty * costPrice   and   sale profit = (unitPrice - costPrice) * qty
 * are correct.
 *
 * Safe: only touches carpet/meter products with a stored rate > 0 whose
 * `costPrice` differs from that rate. Prints before/after for every change.
 */
require('dotenv').config({ path: require('path').join(__dirname, '..', '.env') });
const mongoose = require('mongoose');

const Product = require('../src/models/Product');

const fix = async () => {
  const uri = process.env.MONGO_URI;
  if (!uri) {
    console.error('MONGO_URI not found in backend/.env');
    process.exit(1);
  }
  await mongoose.connect(uri, { serverSelectionTimeoutMS: 20000 });
  console.log('Connected.');

  const updated = [];

  const carpets = await Product.find({ productType: 'carpet', costPerSqft: { $gt: 0 } });
  for (const p of carpets) {
    const rate = p.costPerSqft;
    const rounded = Math.abs(p.costPrice - rate) > 0.009;
    if (rounded) {
      updated.push(`Carpet    "${p.name}" (shop ${p.shop}) qty=${p.quantity} costPrice ${p.costPrice} -> ${rate}`);
      p.costPrice = rate;
      await p.save();
    }
  }

  const meters = await Product.find({ productType: 'meter', costPerMeter: { $gt: 0 } });
  for (const p of meters) {
    const rate = p.costPerMeter;
    if (Math.abs(p.costPrice - rate) > 0.009) {
      updated.push(`Meter     "${p.name}" (shop ${p.shop}) qty=${p.quantity} costPrice ${p.costPrice} -> ${rate}`);
      p.costPrice = rate;
      await p.save();
    }
  }

  console.log(`\nFixed ${updated.length} product(s):`);
  updated.forEach((l) => console.log('  ' + l));

  const still = await Product.find({ productType: { $in: ['carpet', 'meter'] } }).select('name productType quantity costPrice costPerSqft costPerMeter');
  console.log('\nAll carpet/meter products now:');
  still.forEach((p) => console.log(`  ${p.productType} "${p.name}" qty=${p.quantity} costPrice=${p.costPrice}`));

  await mongoose.disconnect();
  process.exit(0);
};

fix().catch((e) => {
  console.error('Fix failed:', e.message);
  process.exit(1);
});