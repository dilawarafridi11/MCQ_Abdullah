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
  const shopName = (shop && shop.name) || 'Hayat Foam';
  const GOLD = '#D4AF37';
  const INK = '#1A1A2E';
  const MUTED = '#6B7280';
  const LIGHT = '#F7F4EA';
  const LINE = '#E5E5EA';

  return new Promise((resolve, reject) => {
    const doc = new PDFDocument({ size: 'A4', margin: 28 });
    const chunks = [];
    doc.on('data', (c) => chunks.push(c));
    doc.on('end', () => resolve(Buffer.concat(chunks)));
    doc.on('error', reject);

    const margin = 28;
    const width = 595.28 - margin * 2;

    // ---- Bordered shell ----
    doc.roundedRect(margin, margin, width, 20, 10).fill(INK);
    doc.rect(margin, margin + 20, width, 1).fill(GOLD);

    // ---- Header ----
    doc.roundRect(margin, margin + 22, width, 78, 0).fill('#FFFFFF');
    doc.font('Helvetica-Bold').fontSize(20).fillColor(INK).text('HAYAT FOAM', margin + 22, margin + 34);
    doc.font('Helvetica').fontSize(9).fillColor(MUTED).text('PREMIUM FOAM & MATTRESS SOLUTIONS', margin + 22, margin + 62, { characterSpacing: 1 });
    doc.font('Helvetica').fontSize(10).fillColor(MUTED).text(shopName, margin + 22, margin + 76);
    doc.font('Helvetica-Bold').fontSize(13).fillColor(GOLD).text('INVOICE', width / 2 + margin - 30, margin + 34, { characterSpacing: 2 });
    doc.font('Helvetica-Bold').fontSize(12).fillColor(INK).text(sale.invoiceNo, width / 2 + margin - 30, margin + 52);
    doc.font('Helvetica').fontSize(9).fillColor(MUTED).text(fmtDate(sale.createdAt || new Date()), width / 2 + margin - 30, margin + 74);
    doc.rect(margin, margin + 100, width, 1).fill(LINE);
    doc.y = margin + 116;

    // ---- Customer & payment ----
    doc.font('Helvetica').fontSize(8).fillColor(MUTED).text('BILLED TO', { characterSpacing: 1.4 });
    doc.moveDown(0.3);
    doc.font('Helvetica-Bold').fontSize(11).fillColor(INK).text(sale.customerName || 'Walk-in Customer');
    if (sale.customerPhone) {
      doc.font('Helvetica').fontSize(9).fillColor(MUTED).text(sale.customerPhone);
    }
    doc.moveDown(0.6);
    doc.font('Helvetica').fontSize(8).fillColor(MUTED).text('PAYMENT', { characterSpacing: 1.4 });
    doc.moveDown(0.3);
    doc.font('Helvetica-Bold').fontSize(9).fillColor(GOLD);
    const method = (sale.paymentMethod || 'cash').toUpperCase();
    const pw = doc.widthOfString(method) + 14;
    doc.roundRect(margin, doc.y - 9, pw + 8, 14, 7).stroke(GOLD);
    doc.text(method, margin + 4, doc.y);
    doc.y += 6;

    if (sale.createdBy && sale.createdBy.name) {
      doc.moveDown(0.5);
      doc.font('Helvetica').fontSize(8).fillColor(MUTED).text('HANDLED BY', { characterSpacing: 1.4 });
      doc.moveDown(0.3);
      doc.font('Helvetica').fontSize(9).fillColor(MUTED).text(sale.createdBy.name);
    }

    doc.moveDown(1);
    doc.rect(margin, doc.y, width, 1).fill(LINE);
    doc.y += 8;

    // ---- Items table ----
    const x0 = margin;
    const tableW = width;
    const cols = [tableW * 0.46, tableW * 0.16, tableW * 0.19, tableW * 0.19];
    const headers = ['PRODUCT', 'QTY', 'UNIT PRICE', 'TOTAL'];
    doc.fillColor(GOLD).rect(x0, doc.y, tableW, 22).fill();
    let x = x0;
    headers.forEach((h, i) => {
      doc.font('Helvetica-Bold').fontSize(8.5).fillColor(INK);
      doc.text(h, x + 8, doc.y + 7, { width: cols[i] - 8, align: i === 0 ? 'left' : 'right' });
      x += cols[i];
    });
    doc.y += 24;

    const drawRow = (cells, { font = 'Helvetica', size = 9, color = INK, bg = null, padTop = 5, padBottom = 5, indent = 0 }) => {
      if (doc.y > 740) doc.addPage();
      if (bg) { doc.fillColor(bg).rect(x0, doc.y - 2, tableW, 20).fill(); }
      doc.font(font).fontSize(size).fillColor(color);
      x = x0;
      cells.forEach((cell, i) => {
        doc.text(cell, x + 8 + indent, doc.y, { width: cols[i] - 8 - indent, align: i === 0 ? 'left' : 'right' });
        x += cols[i];
      });
      doc.moveDown(1);
    };

    (sale.items || []).forEach((it, idx) => {
      const even = idx % 2 === 0 ? LIGHT : '#FFFFFF';
      const units = currency(it.unitPrice);
      if (it.foamQty || it.pillowQty || it.coverQty) {
        drawRow([it.productName || '-', '', '', ''], { font: 'Helvetica-Bold', size: 9.5, bg: even });
        if (it.foamQty) {
          drawRow([`    · Foam`, `${it.foamQty}`, units, currency(it.foamQty * it.unitPrice)], { bg: even, color: '#555555', size: 8.5, indent: 0 });
        }
        if (it.pillowQty) {
          drawRow([`    · Pillows`, `${it.pillowQty}`, units, currency(it.pillowQty * it.unitPrice)], { bg: even, color: '#555555', size: 8.5 });
        }
        if (it.coverQty) {
          drawRow([`    · Foam Covers`, `${it.coverQty}`, units, currency(it.coverQty * it.unitPrice)], { bg: even, color: '#555555', size: 8.5 });
        }
        doc.rect(x0, doc.y + 2, tableW, 0.6).fill(LINE);
        doc.y += 8;
      } else {
        drawRow([it.productName || '-', `${it.quantity}`, units, currency(it.totalAmount)], { bg: even });
      }
    });

    doc.rect(x0, doc.y + 4, tableW, 0.8).fill(GOLD);
    doc.y += 16;

    // ---- Totals ----
    const totals = [
      ['Subtotal', currency(sale.subtotal), false],
      ...(sale.discount > 0 ? [['Discount', `- ${currency(sale.discount)}`, false]] : []),
      ['Total', currency(sale.totalAmount), true],
      ['Paid', currency(sale.paidAmount), false],
      ['Due', currency(sale.dueAmount), sale.dueAmount > 0],
    ];
    for (const [label, value, strong] of totals) {
      doc.font(strong ? 'Helvetica-Bold' : 'Helvetica').fontSize(strong ? 12 : 10.5);
      doc.fillColor(strong ? INK : MUTED).text(label.toUpperCase(), x0 + 300, doc.y, { width: 120, align: 'right' });
      doc.fillColor(strong ? GOLD : INK).text(value, x0 + 300, doc.y - 11, { width: tableW - 300, align: 'right' });
      doc.moveDown(0.5);
    }

    if (sale.notes) {
      doc.moveDown(0.6);
      doc.fillColor(MUTED).font('Helvetica').fontSize(9);
      doc.text(`Notes: ${sale.notes}`);
    }

    doc.moveDown(1.2);
    doc.roundedRect(margin, doc.y, width, 34, 8).fill(INK);
    doc.fillColor(GOLD).font('Helvetica-Bold').fontSize(10).text('THANK YOU FOR SHOPPING WITH HAYAT FOAM!', margin + 14, doc.y - 13, { width: width - 28, align: 'center', characterSpacing: 1 });
    doc.fillColor('#BBBBBB').font('Helvetica').fontSize(8).text('Invoice generated by MCQ Business Management System', margin + 14, doc.y + 12, { width: width - 28, align: 'center' });

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
    await sendDocumentMessage(to, mediaId, filename, `Invoice ${sale.invoiceNo} - Hayat Foam. Thank you!`);
    return { attempted: true, sent: true, reason: 'sent', error: null };
  } catch (err) {
    return { attempted: true, sent: false, reason: 'error', error: err.message };
  }
};

module.exports = { sendWhatsAppReceipt, generateSaleReceiptPDF, normalizePhone };