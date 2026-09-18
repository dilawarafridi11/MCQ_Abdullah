/**
 * Wipes all application data from the target database, keeping ONLY the
 * "users" (admin + managers) and "shops" collections.
 *
 * Deleted collections:
 *   products, sales, customers, suppliers, categories, expenses,
 *   inventorylogs, notifications, auditlogs
 *
 * Usage (from the backend directory):
 *   set CONFIRM_DESTROY=YES && node scripts/wipe-production.js   (Windows)
 *   CONFIRM_DESTROY=YES node scripts/wipe-production.js          (Linux/Mac - production)
 *
 * The script reads MONGO_URI from the environment, and falls back to the
 * backend's .env file. To target PRODUCTION, run it ON the production server
 * where the production .env lives (or set MONGO_URI to the production URI).
 *
 * THIS IS IRREVERSIBLE. Run a mongodump backup first unless you are sure.
 */
require('dotenv').config();

const mongoose = require('mongoose');

const URI = process.env.MONGO_URI;
if (!URI) {
  console.error('MONGO_URI not set in environment or .env');
  process.exit(1);
}

// Collections to PRESERVE (not touched): users (admin + managers) and shops.
const KEEP = new Set(['users', 'shops']);

// Every collection known in this application.
const ALL = [
  'users',
  'shops',
  'products',
  'sales',
  'customers',
  'suppliers',
  'categories',
  'expenses',
  'inventorylogs',
  'notifications',
  'auditlogs',
];

const TO_DELETE = ALL.filter((c) => !KEEP.has(c));

async function main() {
  console.log('==================================================');
  console.log('  PRODUCTION DATA WIPE');
  console.log('==================================================');
  console.log('KEEPING (not touched):', [...KEEP].join(', '));
  console.log('DELETING             :', TO_DELETE.join(', '));
  console.log('');
  console.log('This targets the database at MONGO_URI.');
  console.log('Before you run it, confirm MONGO_URI points to PRODUCTION, not local.');
  console.log('Run mongodump FIRST unless you intentionally want no backup.');
  console.log('');

  if (process.env.CONFIRM_DESTROY !== 'YES' && !process.argv.includes('--yes')) {
    console.error('ABORTED. Re-run with CONFIRM_DESTROY=YES (and read the warnings).');
    process.exit(1);
  }

  await mongoose.connect(URI, { useNewUrlParser: true, useUnifiedTopology: true });
  const db = mongoose.connection.db;

  console.log('Connected. Deleting...');
  const results = [];
  for (const c of TO_DELETE) {
    if (!(await collectionExists(db, c))) {
      results.push(`${c}: collection does not exist (skipped)`);
      continue;
    }
    const r = await db.collection(c).deleteMany({});
    results.push(`${c}: ${r.deletedCount} document(s) deleted`);
  }

  console.log('\nDone.');
  results.forEach((line) => console.log('  ' + line));
  await mongoose.disconnect();
}

async function collectionExists(db, name) {
  const list = await db.listCollections({ name }).toArray();
  return list.length > 0;
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
