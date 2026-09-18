const PDFDocument = require('pdfkit');
const Shop = require('../models/Shop');
const config = require('../config');

const GRAPH_VERSION = 'v21.0';

const currency = (n) => `Rs. ${Number(n || 0).toLocaleString('en-PK')}`;

const fmtDate = (d) =>
  new Date(d).toLocaleString('en-PK', {
    day: '2-digit',
    month: 'short',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  });

// Converts a local phone number (e.g. "03001234567") into international E.164
// format without the leading "+" (e.g. "923001234567"), which WhatsApp expects.
const normalizePhone = (phone, countryCode = '92') => {
  const digits = (phone || '').replace(/\D+/g, '');
  if (!digits) return '';
  let normalized = digits;
  if (digits.startsWith('0')) normalized = countryCode + digits.slice(1);
  return /^\d{10,15}$/.test(normalized) ? normalized : '';
};

const generateSaleReceiptPDF = async (sale) => {
  const shop = sale.shop && sale.shop.name ? sale.shop : await Shop.findById(sale.shop).lean();
  const shopName = (shop && shop.name) || 'Muallim Carpets';

  return new Promise((resolve, reject) => {
    const doc = new PDFDocument({ size: 'A4', margin: 40 });
    const chunks = [];
    doc.on('data', (c) => chunks.push(c));
    doc.on('end', () => resolve(Buffer.concat(chunks)));
    doc.on('error', reject);

    // Header
    doc.fontSize(20).font('Helvetica-Bold').fillColor('#111111').text('MUALLIM CARPETS', { align: 'center' });
    doc.fontSize(10).font('Helvetica').fillColor('#555555').text('Sale Receipt / Invoice', { align: 'center' });
    doc.fontSize(9).text(shopName, { align: 'center' });
    doc.moveDown(0.5);
    doc.moveTo(40, doc.y).lineTo(555, doc.y).stroke('#D4AF37');
    doc.moveDown(0.8);

    // Invoice meta
    doc.fontSize(10).font('Helvetica-Bold');
    doc.text(`Invoice No: ${sale.invoiceNo}`, 40, doc.y);
    doc.text(`Date: ${fmtDate(sale.createdAt || new Date())}`, 300, doc.y - 12);
    doc.moveDown(0.6);
    doc.font('Helvetica').fillColor('#333333');
    doc.text(`Customer: ${sale.customerName || 'Walk-in Customer'}`);
    if (sale.customerPhone) doc.text(`Phone: ${sale.customerPhone}`);
    doc.text(`Payment: ${(sale.paymentMethod || 'cash').toUpperCase()}`);
    doc.moveDown(0.8);

    // Items table
    const x0 = 40;
    const tableW = 515;
    const headers = ['Product', 'Qty', 'Unit Price', 'Total'];
    const cols = [225, 70, 120, 100];
    const colWidths = cols.map((w) => (tableW * w) / tableW);
    const rows = (sale.items || []).map((it) => [
      it.productName || '-',
      `${it.quantity}`,
      currency(it.unitPrice),
      currency(it.totalAmount),
    ]);

    doc.font('Helvetica-Bold').fontSize(9).fillColor('#111111');
    let x = x0;
    headers.forEach((h, i) => {
      doc.text(h, x + 4, doc.y, { width: colWidths[i] - 8 });
      x += colWidths[i];
    });
    doc.moveDown(0.1);
    doc.moveTo(x0, doc.y).lineTo(x0 + tableW, doc.y).stroke('#CCCCCC');
    doc.moveDown(0.3);

    doc.font('Helvetica').fontSize(9).fillColor('#333333');
    for (const row of rows) {
      if (doc.y > 750) doc.addPage();
      x = x0;
      row.forEach((cell, i) => {
        doc.text(cell, x + 4, doc.y, { width: colWidths[i] - 8 });
        x += colWidths[i];
      });
      doc.moveDown(0.25);
    }
    doc.moveTo(x0, doc.y).lineTo(x0 + tableW, doc.y).stroke('#DDDDDD');
    doc.moveDown(0.8);

    // Totals
    const totals = [
      ['Subtotal', currency(sale.subtotal)],
      ...(sale.discount > 0 ? [['Discount', `- ${currency(sale.discount)}`]] : []),
      ['Total', currency(sale.totalAmount)],
      ['Paid', currency(sale.paidAmount)],
      ...(sale.dueAmount > 0 ? [['Due', currency(sale.dueAmount)]] : [['Due', currency(0)]]),
    ];
    doc.font('Helvetica').fontSize(10).fillColor('#333333');
    for (const [label, value] of totals) {
      doc.font(label === 'Total' ? 'Helvetica-Bold' : 'Helvetica')
        .fillColor(label === 'Total' ? '#111111' : '#333333');
      doc.text(label, 300, doc.y);
      doc.text(value, 430, doc.y - 11, { width: 165, align: 'right' });
      if (label === 'Total' || (label === 'Paid')) doc.moveDown(0.2);
    }

    if (sale.notes) {
      doc.moveDown(0.6);
      doc.font('Helvetica').fontSize(9).fillColor('#666666').text(`Notes: ${sale.notes}`);
    }

    doc.moveDown(1.2);
    doc.moveTo(40, doc.y).lineTo(555, doc.y).stroke('#D4AF37');
    doc.moveDown(0.4);
    doc.fontSize(8).font('Helvetica').fillColor('#888888').text(
      'Thank you for shopping with Muallim Carpets!',
      { align: 'center' }
    );

    doc.end();
  });
};

const uploadMedia = async (buffer, filename) => {
  const form = new FormData();
  form.append('messaging_product', 'whatsapp');
  form.append('type', 'application/pdf');
  form.append('file', new Blob([buffer], { type: 'application/pdf' }), filename);

  const res = await fetch(`https://graph.facebook.com/${GRAPH_VERSION}/${config.whatsapp.phoneId}/media`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${config.whatsapp.token}` },
    body: form,
    signal: AbortSignal.timeout(20000),
  });
  const json = await res.json();
  if (!res.ok || !json.id) {
    throw new Error(json.error ? json.error.message : 'Media upload failed');
  }
  return json.id;
};

const sendDocumentMessage = async (to, mediaId, filename, caption) => {
  const res = await fetch(`https://graph.facebook.com/${GRAPH_VERSION}/${config.whatsapp.phoneId}/messages`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${config.whatsapp.token}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      messaging_product: 'whatsapp',
      to,
      type: 'document',
      document: { id: mediaId, filename, caption },
    }),
    signal: AbortSignal.timeout(20000),
  });
  const json = await res.json();
  if (!res.ok) {
    throw new Error(json.error ? json.error.message : 'WhatsApp message send failed');
  }
  return json.messages && json.messages[0];
};

/**
 * Generates the sale receipt PDF and sends it to the customer's WhatsApp.
 * Returns a status object — it never throws, so a WhatsApp failure can never
 * break the sale itself.
 */
const sendWhatsAppReceipt = async (sale, phone) => {
  if (!config.whatsapp.enabled || !config.whatsapp.receiptsEnabled) {
    return { attempted: false, sent: false, reason: 'not_configured', error: null };
  }

  const to = normalizePhone(phone, config.whatsapp.countryCode);
  if (!to) {
    return { attempted: true, sent: false, reason: 'invalid_phone', error: 'Invalid WhatsApp phone number.' };
  }

  try {
    const filename = `Invoice_${sale.invoiceNo}.pdf`;
    const buffer = await generateSaleReceiptPDF(sale);
    const mediaId = await uploadMedia(buffer, filename);
    await sendDocumentMessage(to, mediaId, filename, `Invoice ${sale.invoiceNo} - Muallim Carpets. Thank you!`);
    return { attempted: true, sent: true, reason: 'sent', error: null };
  } catch (err) {
    return { attempted: true, sent: false, reason: 'error', error: err.message };
  }
};

module.exports = { sendWhatsAppReceipt, generateSaleReceiptPDF, normalizePhone };