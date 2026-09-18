process.env.PORT = 5066;
const connectDB = require('./src/config/db');
const app = require('./src/app');

const base = 'http://localhost:5066/api';
let token = '';

async function req(method, path, body, auth = true) {
  const headers = { 'Content-Type': 'application/json' };
  if (auth && token) headers.Authorization = `Bearer ${token}`;
  const res = await fetch(base + path, {
    method,
    headers,
    body: body ? JSON.stringify(body) : undefined,
  });
  const data = await res.json();
  return { status: res.status, data };
}

async function main() {
  await connectDB();
  const server = app.listen(5066, async () => {
    try {
      let r = await req('GET', '/health', null, false);
      console.log('health:', r.status, r.data.message);

      r = await req('POST', '/auth/login', { email: 'admin@muallimcarpets.com', password: 'Admin@123' }, false);
      console.log('admin login:', r.status, r.data.data.user.role);
      token = r.data.data.token;

      r = await req('GET', '/dashboard');
      console.log('dashboard cards:', r.status, JSON.stringify(r.data.data.cards));

      r = await req('GET', '/products?limit=3');
      console.log('products:', r.status, 'total=', r.data.data.total);

      r = await req('GET', '/audit?limit=5');
      console.log('audit logs (admin):', r.status, 'total=', r.data.data.total);

      r = await req('GET', '/reports?period=month');
      console.log('report:', r.status, JSON.stringify({ sales: r.data.data.sales, profit: r.data.data.profit }));

      r = await req('GET', '/analytics');
      console.log('analytics (admin, should be 200):', r.status);

      // Admin is view-only: mutations must be rejected with 403.
      r = await req('POST', '/products', { name: 'Should Fail', sellingPrice: 10 });
      console.log('admin POST /products (should be 403):', r.status);

      const firstProduct = (await req('GET', '/products?limit=1')).data.data.products?.[0];
      if (firstProduct) {
        const pid = firstProduct._id ?? firstProduct.id;
        r = await req('DELETE', `/products/${pid}`);
        console.log('admin DELETE /products (should be 403):', r.status);
      }

      const firstSale = (await req('GET', '/sales?limit=1')).data.data.sales?.[0];
      if (firstSale) {
        console.log(
          'admin sale has profit (should be true):',
          typeof firstSale.profit === 'number' && firstSale.profit !== undefined
        );
        console.log(
          'admin sale item has costPrice (should be true):',
          Array.isArray(firstSale.items) && firstSale.items.some((i) => i.costPrice !== undefined)
        );
      }

      // Manager login - should be scoped
      const ml = await req('POST', '/auth/login', { email: 'israr@muallimcarpets.com', password: 'Manager@123' }, false);
      token = ml.data.data.token;
      console.log('manager login:', ml.status, 'assignedShop=', ml.data.data.user.assignedShop?.name);

      r = await req('GET', '/products?limit=3');
      console.log('manager products total:', r.data.data.total);

      r = await req('GET', '/audit');
      console.log('manager audit access (should be 403):', r.status);

      r = await req('GET', '/notifications/unread-count');
      console.log('manager unread notifications:', r.status, r.data.data.count);

      // Manager mutations are allowed (operational role).
      const testProduct = {
        name: `Test Product ${Date.now()}`,
        sellingPrice: 99,
        costPrice: 40,
        sku: `TST${Date.now()}`,
      };
      r = await req('POST', '/products', testProduct);
      const createdId = r.data.data?._id ?? r.data.data?.id;
      console.log('manager POST /products (should be 201):', r.status, 'id=', createdId);

      // Manager dashboard: operational KPIs only, no financials.
      r = await req('GET', '/dashboard');
      const mc = r.data.data.cards || {};
      const leaky = Object.keys(mc).filter((k) =>
        ['revenue', 'profit', 'expenseTotal', 'monthlyRevenue', 'monthlyProfit', 'yearlyRevenue', 'yearlyProfit'].includes(k)
      );
      console.log(
        'manager dashboard cards (no financial leak, should be true):',
        leaky.length === 0 && 'todayOrders' in mc && 'customerCount' in mc && 'stockInToday' in mc
      );

      // Manager sales: profit and costPrice must be masked.
      r = await req('GET', '/sales?limit=1');
      const msale = r.data.data.sales?.[0];
      if (msale) {
        console.log(
          'manager sale has profit (should be false):',
          msale.profit !== undefined
        );
        console.log(
          'manager sale item has costPrice (should be false):',
          Array.isArray(msale.items) && msale.items.some((i) => i.costPrice !== undefined)
        );
      }

      // Financial/analytics modules are admin-only.
      r = await req('GET', '/reports?period=month');
      console.log('manager /reports (should be 403):', r.status);

      r = await req('GET', '/analytics');
      console.log('manager /analytics (should be 403):', r.status);

      if (createdId) {
        r = await req('DELETE', `/products/${createdId}`);
        console.log('manager DELETE /products (should be 200):', r.status);
      }

      console.log('ALL TESTS DONE');
      process.exit(0);
    } catch (e) {
      console.error('TEST ERROR:', e.message);
      process.exit(1);
    }
  });
}

main();
