import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/utils/formatters.dart';
import '../models/sale.dart';

/// Builds a premium A4 invoice PDF for a sale in-app (also used to share /
/// print the invoice without relying on WhatsApp).
class InvoicePdf {
  InvoicePdf._();

  static const PdfColor _gold = PdfColor.fromInt(0xFFD4AF37);
  static const PdfColor _ink = PdfColor.fromInt(0xFF1A1A2E);
  static const PdfColor _muted = PdfColor.fromInt(0xFF6B7280);
  static const PdfColor _mutedSoft = PdfColor.fromInt(0xFF9CA3AF);
  static const PdfColor _light = PdfColor.fromInt(0xFFF7F4EA);
  static const PdfColor _rowLight = PdfColor.fromInt(0xFFFBF8F1);
  static const PdfColor _line = PdfColor.fromInt(0xFFE5E5EA);

  static Future<Uint8List> build(Sale sale) async {
    final doc = pw.Document();

    final header = pw.Container(
      decoration: pw.BoxDecoration(
        color: _ink,
        borderRadius: const pw.BorderRadius.only(
          topLeft: pw.Radius.circular(14),
          topRight: pw.Radius.circular(14),
        ),
      ),
      padding: const pw.EdgeInsets.all(24),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'HAYAT FOAM',
                style: pw.TextStyle(
                  fontSize: 22,
                  fontWeight: pw.FontWeight.bold,
                  color: _gold,
                  letterSpacing: 2,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                'Premium Foam & Mattress Solutions',
                style: pw.TextStyle(fontSize: 9, color: PdfColors.grey300, letterSpacing: 1.4),
              ),
              pw.SizedBox(height: 8),
              if (sale.shopName.isNotEmpty)
                pw.Text(
                  sale.shopName,
                  style: const pw.TextStyle(fontSize: 11, color: PdfColors.white),
                ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Container(
                decoration: pw.BoxDecoration(
                  color: _gold,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                child: pw.Text(
                  'INVOICE',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: _ink,
                    letterSpacing: 3,
                  ),
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Text(
                sale.invoiceNo,
                style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                Formatters.dateTime(sale.createdAt),
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey400),
              ),
            ],
          ),
        ],
      ),
    );

    final customer = pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _label('BILLED TO'),
                pw.SizedBox(height: 6),
                pw.Text(
                  sale.customerName,
                  style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: _ink),
                ),
                if (sale.customerPhone.isNotEmpty) ...[
                  pw.SizedBox(height: 2),
                  pw.Text(sale.customerPhone, style: const pw.TextStyle(fontSize: 10, color: _muted)),
                ],
              ],
            ),
          ),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                _label('PAYMENT'),
                pw.SizedBox(height: 6),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: pw.BoxDecoration(
                    color: _light,
                    border: pw.Border.all(color: _gold),
                    borderRadius: pw.BorderRadius.circular(20),
                  ),
                  child: pw.Text(
                    sale.paymentMethod.toUpperCase(),
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      color: _gold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                if (sale.createdByName.isNotEmpty) ...[
                  pw.SizedBox(height: 8),
                  _label('HANDLED BY'),
                  pw.Text(sale.createdByName, style: const pw.TextStyle(fontSize: 10, color: _muted)),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    final itemsHeader = pw.Container(
      color: _gold,
      padding: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: pw.Row(
        children: [
          pw.Expanded(flex: 5, child: _headerCell('PRODUCT', align: pw.Alignment.centerLeft)),
          pw.Expanded(flex: 2, child: _headerCell('QTY')),
          pw.Expanded(flex: 3, child: _headerCell('UNIT PRICE')),
          pw.Expanded(flex: 3, child: _headerCell('TOTAL')),
        ],
      ),
    );

    final rows = <pw.Widget>[];
    for (var i = 0; i < sale.items.length; i++) {
      rows.add(_itemRow(sale.items[i], i));
    }

    final totals = pw.Container(
      padding: const pw.EdgeInsets.all(24),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            flex: 3,
            child: sale.notes.isNotEmpty
                ? pw.Container(
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      color: _light,
                      borderRadius: pw.BorderRadius.circular(8),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _label('NOTES'),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          sale.notes,
                          style: const pw.TextStyle(fontSize: 9, color: _muted),
                        ),
                      ],
                    ),
                  )
                : pw.SizedBox(),
          ),
          pw.Expanded(flex: 2, child: pw.SizedBox()),
          pw.Expanded(
            flex: 2,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                _totalRow('Subtotal', Formatters.currency(sale.subtotal)),
                if (sale.discount > 0) _totalRow('Discount', '- ${Formatters.currency(sale.discount)}'),
                pw.SizedBox(height: 4),
                pw.Container(
                  decoration: pw.BoxDecoration(
                    color: _gold,
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.end,
                    children: [
                      pw.Text(
                        'TOTAL',
                        style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: _ink),
                      ),
                      pw.SizedBox(width: 8),
                      pw.Text(
                        Formatters.currency(sale.totalAmount),
                        style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: _ink),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 6),
                _totalRow('Paid', Formatters.currency(sale.paidAmount), valueColor: PdfColors.green700),
                _totalRow(
                  'Due',
                  Formatters.currency(sale.dueAmount),
                  valueColor: sale.dueAmount > 0 ? PdfColors.red700 : PdfColors.green700,
                  bold: sale.dueAmount > 0,
                ),
              ],
            ),
          ),
        ],
      ),
    );

    final footer = pw.Container(
      decoration: pw.BoxDecoration(
        color: _ink,
        borderRadius: const pw.BorderRadius.only(
          bottomLeft: pw.Radius.circular(14),
          bottomRight: pw.Radius.circular(14),
        ),
      ),
      padding: const pw.EdgeInsets.all(16),
      child: pw.Column(
        children: [
          pw.Text(
            'Thank you for shopping with Hayat Foam!',
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: _gold,
              letterSpacing: 1.2,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'This invoice was generated by the MCQ Business Management System',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey400),
          ),
        ],
      ),
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(0),
        build: (ctx) => [
          pw.Container(
            margin: const pw.EdgeInsets.all(28),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: _gold, width: 1.6),
              borderRadius: pw.BorderRadius.circular(14),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                header,
                customer,
                pw.Container(height: 1, color: _line),
                pw.SizedBox(height: 10),
                itemsHeader,
                ...rows,
                pw.SizedBox(height: 8),
                pw.Container(height: 1, color: _line),
                totals,
                footer,
              ],
            ),
          ),
        ],
        footer: (ctx) => pw.Align(
          alignment: pw.Alignment.center,
          child: pw.Text(
            'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: _mutedSoft),
          ),
        ),
      ),
    );

    return doc.save();
  }

  static pw.Widget _label(String text) => pw.Text(
        text,
        style: pw.TextStyle(fontSize: 8, color: _mutedSoft, letterSpacing: 1.6),
      );

  static pw.Widget _headerCell(String text, {pw.Alignment align = pw.Alignment.centerRight}) => pw.Align(
        alignment: align,
        child: pw.Text(
          text,
          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: _ink, letterSpacing: 0.6),
        ),
      );

  static pw.Widget _itemRow(SaleItem item, int index) {
    final even = index.isEven;

    if (item.isFoam) {
      return pw.Container(
        color: even ? PdfColors.white : _rowLight,
        padding: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 6),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Text(item.productName, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: _ink)),
            pw.SizedBox(height: 4),
            if (item.foamQty > 0) _breakdownRow('Foam', item.foamQty, item.unitPrice),
            if (item.pillowQty > 0) _breakdownRow('Pillows', item.pillowQty, item.unitPrice),
            if (item.coverQty > 0) _breakdownRow('Foam Covers', item.coverQty, item.unitPrice),
            pw.SizedBox(height: 4),
            pw.Container(
              height: 1,
              color: _line,
              child: pw.SizedBox.shrink(),
            ),
          ],
        ),
      );
    }

    return pw.Container(
      color: even ? PdfColors.white : _rowLight,
      padding: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: pw.Row(
        children: [
          pw.Expanded(flex: 5, child: pw.Text(item.productName, style: const pw.TextStyle(fontSize: 10, color: _ink))),
          pw.Expanded(
            flex: 2,
            child: pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text('${item.quantity}', style: const pw.TextStyle(fontSize: 10, color: _ink)),
            ),
          ),
          pw.Expanded(
            flex: 3,
            child: pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(Formatters.currency(item.unitPrice), style: const pw.TextStyle(fontSize: 10, color: _ink)),
            ),
          ),
          pw.Expanded(
            flex: 3,
            child: pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                Formatters.currency(item.totalAmount),
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: _ink),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _breakdownRow(String label, int qty, double unitPrice) => pw.Row(
        children: [
          pw.Expanded(
            flex: 5,
            child: pw.Text('    · $label', style: const pw.TextStyle(fontSize: 9, color: _muted)),
          ),
          pw.Expanded(
            flex: 2,
            child: pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text('$qty', style: const pw.TextStyle(fontSize: 9, color: _muted)),
            ),
          ),
          pw.Expanded(
            flex: 3,
            child: pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(Formatters.currency(unitPrice), style: const pw.TextStyle(fontSize: 9, color: _muted)),
            ),
          ),
          pw.Expanded(
            flex: 3,
            child: pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                Formatters.currency(qty * unitPrice),
                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: _muted),
              ),
            ),
          ),
        ],
      );

  static pw.Widget _totalRow(String label, String value, {PdfColor? valueColor, bool bold = false}) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 4),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          children: [
            pw.Text(
              label.toUpperCase(),
              style: pw.TextStyle(
                fontSize: 10,
                color: _muted,
                fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
              ),
            ),
            pw.SizedBox(width: 14),
            pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 11,
                color: valueColor ?? _ink,
                fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
              ),
            ),
          ],
        ),
      );
}