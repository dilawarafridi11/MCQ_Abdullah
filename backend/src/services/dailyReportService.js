const PDFDocument = require('pdfkit');
const Sale = require('../models/Sale');
const Expense = require('../models/Expense');
const InventoryLog = require('../models/InventoryLog');
const Product = require('../models/Product');
const Shop = require('../models/Shop');
const config = require('../config');
const { sendMail } = require('./emailService');
const { startOfDay, endOfDay } = require('../utils/stats');

const currency = (n) => `Rs. ${Number(n || 0).toLocaleString('en-PK')}`;

const COLORS = {
  navy: '#1B2A41',
  gold: '#C9A227',
  goldLight: '#EFE3B2',
  text: '#23303C',
  muted: '#64748B',
  white: '#FFFFFF',
  line: '#E2E8F0',
  zebra: '#F6F4EE',
  soft: '#F6F8FA',
  green: '#1E8E5A',
  red: '#C0392B',
  bandText: '#C9D4E4',
};

const buildDailyReport = async () => {
  const now = new Date();
  const dayStart = startOfDay(now);
  const dayEnd = endOfDay(now);

  const [sales, expenses, inventoryLogs, shops, lowStockProducts] = await Promise.all([
    Sale.find({ isDeleted: false, createdAt: { $gte: dayStart, $lte: dayEnd } })
      .populate('shop', 'name')
      .populate('createdBy', 'name')
      .sort({ createdAt: -1 }),
    Expense.find({ isDeleted: false, expenseDate: { $gte: dayStart, $lte: dayEnd } })
      .populate('shop', 'name')
      .sort({ expenseDate: -1 }),
    InventoryLog.find({ date: { $gte: dayStart, $lte: dayEnd } })
      .populate('shop', 'name')
      .populate('performedBy', 'name')
      .populate('product', 'name')
      .sort({ date: -1 }),
    Shop.find({ isDeleted: false }),
    Product.find({ isDeleted: false, $expr: { $lte: ['$quantity', '$lowStockThreshold'] } })
      .populate('shop', 'name')
      .sort({ quantity: 1 }),
  ]);

  const totalSales = sales.reduce((s, r) => s + r.totalAmount, 0);
  const totalExpenses = expenses.reduce((s, r) => s + r.amount, 0);
  const totalProfit = sales.reduce((s, r) => s + r.profit, 0);
  const stockInLogs = inventoryLogs.filter((l) => l.actionType === 'stock_in');
  const stockOutLogs = inventoryLogs.filter((l) => l.actionType === 'stock_out');

  const shopSections = shops
    .map((shop) => {
      const shopId = String(shop._id);
      const sSales = sales.filter((s) => s.shop && String(s.shop._id) === shopId);
      const sExpenses = expenses.filter((e) => e.shop && String(e.shop._id) === shopId);
      const sLogs = inventoryLogs.filter((l) => l.shop && String(l.shop._id) === shopId);
      const sLow = lowStockProducts.filter((p) => p.shop && String(p.shop._id) === shopId);
      const sIn = sLogs.filter((l) => l.actionType === 'stock_in');
      const sOut = sLogs.filter((l) => l.actionType === 'stock_out');
      return {
        shop,
        summary: {
          salesCount: sSales.length,
          totalSales: sSales.reduce((s, r) => s + r.totalAmount, 0),
          expensesCount: sExpenses.length,
          totalExpenses: sExpenses.reduce((s, r) => s + r.amount, 0),
          totalProfit: sSales.reduce((s, r) => s + r.profit, 0),
          stockInCount: sIn.length,
          stockInQty: sIn.reduce((s, l) => s + l.quantity, 0),
          stockOutCount: sOut.length,
          stockOutQty: sOut.reduce((s, l) => s + l.quantity, 0),
          lowStockCount: sLow.length,
          totalTransactions: sSales.length + sExpenses.length + sLogs.length,
        },
        sales: sSales,
        expenses: sExpenses,
        inventoryLogs: sLogs,
        lowStockProducts: sLow,
      };
    })
    .sort((a, b) => (a.shop.name || '').localeCompare(b.shop.name || ''));

  return {
    date: now,
    summary: {
      totalSales,
      totalExpenses,
      totalProfit,
      salesCount: sales.length,
      expensesCount: expenses.length,
      totalStockIn: stockInLogs.length,
      totalStockOut: stockOutLogs.length,
      totalTransactions: sales.length + expenses.length + inventoryLogs.length,
      shopsCount: shops.length,
      lowStockCount: lowStockProducts.length,
    },
    sales,
    expenses,
    inventoryLogs,
    lowStockProducts,
    shopSections,
  };
};

// ---------------------------------------------------------------------------
// PDF rendering
// ---------------------------------------------------------------------------

const fmtLongDate = (d) =>
  new Date(d).toLocaleDateString('en-PK', {
    weekday: 'long',
    year: 'numeric',
    month: 'long',
    day: 'numeric',
  });

const fmtDateTime = (d) =>
  new Date(d).toLocaleString('en-PK', {
    day: '2-digit',
    month: 'short',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  });

const renderDailyReportPDF = (report) => {
  const dateStr = fmtLongDate(report.date);
  const generatedAt = fmtDateTime(new Date());

  return new Promise((resolve, reject) => {
    const doc = new PDFDocument({
      size: 'A4',
      margin: 40,
      bufferPages: true,
      info: {
        Title: `MCQ Daily Report — ${dateStr}`,
        Author: 'MCQ Business Management System',
      },
    });
    const chunks = [];
    doc.on('data', (c) => chunks.push(c));
    doc.on('end', () => resolve(Buffer.concat(chunks)));
    doc.on('error', reject);

    drawExecutive(doc, report, dateStr, generatedAt);
    for (const sec of report.shopSections || []) {
      drawShopSection(doc, sec);
    }

    // Page-number footers (drawn after all content so page count is known).
    const range = doc.bufferedPageRange();
    for (let i = 0; i < range.count; i++) {
      doc.switchToPage(i);
      drawFooter(doc, i + 1, range.count);
    }

    doc.end();
  });
};

const drawExecutive = (doc, report, dateStr, generatedAt) => {
  // ---- BRAND HEADER BAND ----
  const bandH = 78;
  doc.rect(0, 0, 595.28, bandH).fill(COLORS.navy);
  doc.fillColor(COLORS.gold).font('Helvetica-Bold').fontSize(8.5).text('MUALLIM CARPETS', 40, 15);
  doc.fillColor(COLORS.white).font('Helvetica-Bold').fontSize(20).text('DAILY BUSINESS REPORT', 40, 28);
  doc.fillColor(COLORS.bandText).font('Helvetica').fontSize(10).text(dateStr, 40, 52);
  doc.fillColor(COLORS.bandText).font('Helvetica').fontSize(8.5);
  doc.text(`Generated: ${generatedAt}`, 0, 52, { width: 515, align: 'right' });
  doc.rect(40, bandH - 4, 515, 3).fill(COLORS.gold);

  doc.y = bandH + 18;
  sectionTitle(doc, 'Executive Summary');

  const sum = report.summary;
  kpiCard(doc, 40, doc.y, 120, 54, 'Total Sales', currency(sum.totalSales));
  kpiCard(doc, 161, doc.y, 120, 54, 'Net Profit', currency(sum.totalProfit), {
    color: sum.totalProfit >= 0 ? COLORS.green : COLORS.red,
  });
  kpiCard(doc, 282, doc.y, 120, 54, 'Total Expenses', currency(sum.totalExpenses));
  kpiCard(doc, 403, doc.y, 152, 54, 'Transactions', `${sum.totalTransactions}`);
  doc.y += 64;
  kpiCard(doc, 40, doc.y, 120, 54, 'Sales', `${sum.salesCount}`);
  kpiCard(doc, 161, doc.y, 120, 54, 'Expenses', `${sum.expensesCount}`);
  kpiCard(doc, 282, doc.y, 120, 54, 'Stock In', `${sum.totalStockIn}`);
  kpiCard(doc, 403, doc.y, 152, 54, 'Stock Out', `${sum.totalStockOut}`);
  doc.y += 70;

  // ---- SHOP PERFORMANCE OVERVIEW ----
  sectionTitle(doc, 'Shop Performance Overview');
  const headers = ['Shop', 'Sales', 'Expenses', 'Net Profit', 'Stock In', 'Stock Out', 'Low Stock'];
  const rows = (report.shopSections || []).map((sec) => [
    sec.shop.name || '-',
    currency(sec.summary.totalSales),
    currency(sec.summary.totalExpenses),
    currency(sec.summary.totalProfit),
    `${sec.summary.stockInCount}`,
    `${sec.summary.stockOutCount}`,
    `${sec.summary.lowStockCount}`,
  ]);
  drawTable(doc, headers, rows);

  doc.fillColor(COLORS.muted).font('Helvetica').fontSize(8).text(
    `No activity today for the remaining ${(report.shopSections || []).length} shop(s).`,
    40,
    doc.y,
    { width: 515 }
  );
};

const drawShopSection = (doc, sec) => {
  doc.addPage();
  const shop = sec.shop;

  // ---- SHOP HEADER BAND ----
  const bandH = 72;
  doc.rect(0, 0, 595.28, bandH).fill(COLORS.navy);
  doc.fillColor(COLORS.gold).font('Helvetica-Bold').fontSize(8).text('MUALLIM CARPETS — SHOP SECTION', 40, 13);
  doc.fillColor(COLORS.white).font('Helvetica-Bold').fontSize(17).text((shop.name || 'Shop').toUpperCase(), 40, 26);
  const meta = [shop.address, shop.contactNumber].filter(Boolean).join('   \u2022   ');
  doc.fillColor(COLORS.bandText).font('Helvetica').fontSize(8.5).text(meta || '\u00a0', 40, 47);
  doc.rect(40, bandH - 4, 515, 3).fill(COLORS.gold);

  const sum = sec.summary;
  let kpiY = bandH + 16;

  kpiCard(doc, 40, kpiY, 165, 52, 'Total Sales', currency(sum.totalSales));
  kpiCard(doc, 215, kpiY, 165, 52, 'Total Expenses', currency(sum.totalExpenses));
  kpiCard(doc, 390, kpiY, 165, 52, 'Net Profit', currency(sum.totalProfit), {
    color: sum.totalProfit >= 0 ? COLORS.green : COLORS.red,
  });
  kpiCard(doc, 40, kpiY + 62, 165, 52, 'Stock In', `${sum.stockInCount} moves (${sum.stockInQty} qty)`);
  kpiCard(doc, 215, kpiY + 62, 165, 52, 'Stock Out', `${sum.stockOutCount} moves (${sum.stockOutQty} qty)`);
  kpiCard(doc, 390, kpiY + 62, 165, 52, 'Low Stock', `${sum.lowStockCount} alerts`);

  doc.y = kpiY + 62 + 66;

  // ---- SALES TABLE ----
  sectionTitle(doc, `Sales (${sum.salesCount})`);
  if (sec.sales.length > 0) {
    const headers = ['#', 'Invoice', 'Customer', 'Payment', 'Profit', 'Amount'];
    const rows = sec.sales.map((s, i) => [
      `${i + 1}`,
      s.invoiceNo,
      s.customerName || '-',
      (s.paymentMethod || 'cash').toUpperCase(),
      currency(s.profit),
      currency(s.totalAmount),
    ]);
    drawTable(doc, headers, rows);
  } else {
    emptyNote(doc, 'No sales recorded today.');
  }

  // ---- EXPENSES TABLE ----
  sectionTitle(doc, `Expenses (${sum.expensesCount})`);
  if (sec.expenses.length > 0) {
    const headers = ['#', 'Category', 'Description', 'Amount'];
    const rows = sec.expenses.map((e, i) => [
      `${i + 1}`,
      (e.category || '').toUpperCase(),
      (e.description || '-').slice(0, 45),
      currency(e.amount),
    ]);
    drawTable(doc, headers, rows);
  } else {
    emptyNote(doc, 'No expenses recorded today.');
  }

  // ---- INVENTORY TABLE ----
  sectionTitle(doc, `Inventory Transactions (${sec.inventoryLogs.length})`);
  if (sec.inventoryLogs.length > 0) {
    const headers = ['#', 'Type', 'Product', 'Qty', 'By'];
    const rows = sec.inventoryLogs.map((l, i) => [
      `${i + 1}`,
      l.actionType === 'stock_in' ? 'STOCK IN' : 'STOCK OUT',
      (l.product && l.product.name) || l.productName || '-',
      `${l.quantity}`,
      (l.performedBy && l.performedBy.name) || '-',
    ]);
    drawTable(doc, headers, rows);
  } else {
    emptyNote(doc, 'No inventory movements today.');
  }

  // ---- LOW STOCK TABLE ----
  sectionTitle(doc, `Low Stock Alerts (${sum.lowStockCount})`);
  if (sec.lowStockProducts.length > 0) {
    const headers = ['#', 'Product', 'Stock', 'Threshold'];
    const rows = sec.lowStockProducts.map((p, i) => [
      `${i + 1}`,
      p.name,
      `${p.quantity}`,
      `${p.lowStockThreshold}`,
    ]);
    drawTable(doc, headers, rows);
  } else {
    emptyNote(doc, 'No low stock alerts.');
  }
};

const emptyNote = (doc, text) => {
  doc.fillColor(COLORS.muted).font('Helvetica').fontSize(8.5).text(text, 40, doc.y, { width: 515 });
  doc.moveDown(0.3);
};

const sectionTitle = (doc, text) => {
  doc.moveDown(0.35);
  const y = doc.y;
  doc.rect(40, y + 2, 3, 11).fill(COLORS.gold);
  doc.fillColor(COLORS.navy).font('Helvetica-Bold').fontSize(11.5).text(text, 50, y);
  doc.moveDown(0.1);
  doc.moveTo(40, doc.y).lineTo(555, doc.y).lineWidth(0.7).strokeColor(COLORS.line).stroke();
  doc.moveDown(0.4);
};

const kpiCard = (doc, x, y, w, h, label, value, { color = COLORS.navy, fontSize = 13 } = {}) => {
  doc.save();
  doc.roundedRect(x, y, w, h, 6).lineWidth(0.8).strokeColor(COLORS.line).fillColor(COLORS.soft).fillAndStroke();
  doc.fillColor(COLORS.muted).font('Helvetica-Bold').fontSize(7).text(label.toUpperCase(), x + 10, y + 9, {
    width: w - 20,
    lineBreak: false,
    ellipsis: true,
  });
  doc.fillColor(color).font('Helvetica-Bold').fontSize(fontSize).text(value, x + 10, y + 24, {
    width: w - 20,
    lineBreak: false,
    ellipsis: true,
  });
  doc.restore();
};

const drawFooter = (doc, page, totalPages) => {
  const h = doc.page.height;
  doc.save();
  const footerY = h - 52; // must stay above page bottom margin (h - 40 = 801.9) or pdfkit wraps to a new page
  doc.moveTo(40, footerY - 4).lineTo(555, footerY - 4).lineWidth(0.6).strokeColor(COLORS.goldLight).stroke();
  doc.fillColor(COLORS.muted).font('Helvetica').fontSize(7.5);
  doc.text('MUALLIM CARPETS — MCQ Business Management System', 40, footerY, { width: 350, lineBreak: false });
  doc.text(`Page ${page} of ${totalPages}`, 0, footerY, { width: 515, align: 'right' });
  doc.restore();
};

const drawTable = (doc, headers, rows, { fontSize = 7.5, rowH = 15 } = {}) => {
  const x0 = 40;
  const tableW = 515;
  const colWidths = computeColWidths(headers, rows, tableW);
  const headerH = 16;

  const drawHeader = (yy) => {
    doc.save();
    doc.rect(x0, yy, tableW, headerH).fill(COLORS.navy);
    doc.fillColor(COLORS.white).font('Helvetica-Bold').fontSize(fontSize);
    let x = x0;
    headers.forEach((h, i) => {
      doc.text(h, x + 5, yy + 5, { width: colWidths[i] - 10, lineBreak: false, ellipsis: true });
      x += colWidths[i];
    });
    doc.restore();
    return yy + headerH;
  };

  let ty = drawHeader(doc.y);

  for (let r = 0; r < rows.length; r++) {
    if (ty + rowH > 758) {
      doc.addPage();
      ty = 48;
      ty = drawHeader(ty);
    }
    if (r % 2 === 1) {
      doc.save();
      doc.rect(x0, ty, tableW, rowH).fill(COLORS.zebra);
      doc.restore();
    }
    doc.font('Helvetica').fontSize(fontSize);
    let x = x0;
    for (let i = 0; i < rows[r].length; i++) {
      const align = i === rows[r].length - 1 ? 'right' : 'left';
      doc.fillColor(COLORS.text).text(String(rows[r][i] ?? ''), x + 5, ty + 4.5, {
        width: colWidths[i] - 10,
        align,
        lineBreak: false,
        ellipsis: true,
      });
      x += colWidths[i];
    }
    ty += rowH;
    doc.save();
    doc.moveTo(x0, ty).lineTo(x0 + tableW, ty).lineWidth(0.4).strokeColor(COLORS.line).stroke();
    doc.restore();
  }
  doc.moveDown(0.2);
};

const computeColWidths = (headers, rows, totalWidth) => {
  const lengths = headers.map((h, i) => {
    const headerLen = h.length;
    const maxRow = rows.reduce((m, r) => Math.max(m, String(r[i] ?? '').length), 0);
    return Math.max(headerLen, maxRow);
  });
  const padded = lengths.map((len) => Math.max(36, Math.min(110, len + 6)));
  const sum = padded.reduce((a, b) => a + b, 0);
  const widths = padded.map((w) => Math.max(36, Math.round((w / sum) * totalWidth)));
  const diff = totalWidth - widths.reduce((a, b) => a + b, 0);
  widths[widths.length - 1] += diff;
  return widths;
};

const generateDailyReportPDF = async () => {
  const report = await buildDailyReport();
  return renderDailyReportPDF(report);
};

const sendDailyReportEmail = async () => {
  try {
    if (!config.email.enabled) {
      console.log('[DailyReport] Skipped — SMTP not configured.');
      return;
    }
    const recipient = config.email.to;
    if (!recipient) {
      console.log('[DailyReport] Skipped — REPORT_RECIPIENT_EMAIL not set.');
      return;
    }
    console.log('[DailyReport] Generating PDF report...');
    const pdfBuffer = await generateDailyReportPDF();
    const now = new Date();
    const dateStr = now.toISOString().slice(0, 10);

    await sendMail({
      to: recipient,
      subject: `MCQ Daily Report — ${dateStr}`,
      html: `<p>Hi Admin,</p>
<p>Please find attached the daily data report for <strong>${dateStr}</strong>.</p>
<p>This report includes:</p>
<ul>
  <li>Executive summary for all shops</li>
  <li>Shop-wise details for each branch and the warehouse (sales, expenses, inventory movements &amp; low stock)</li>
</ul>
<p>Best regards,<br/>MCQ Business Management System</p>`,
      attachments: [
        {
          filename: `MCQ_Daily_Report_${dateStr}.pdf`,
          content: pdfBuffer,
          contentType: 'application/pdf',
        },
      ],
    });
    console.log('[DailyReport] Email sent successfully.');
  } catch (err) {
    console.error('[DailyReport] Error:', err.message);
  }
};

module.exports = { buildDailyReport, generateDailyReportPDF, renderDailyReportPDF, sendDailyReportEmail };