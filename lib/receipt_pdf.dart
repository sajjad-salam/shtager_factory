import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'models.dart';
import 'store.dart';

pw.Font? _regular;
pw.Font? _bold;

Future<void> _loadFonts() async {
  _regular ??= pw.Font.ttf(await rootBundle.load('assets/fonts/IBMPlexSansArabic-Regular.ttf'));
  _bold ??= pw.Font.ttf(await rootBundle.load('assets/fonts/IBMPlexSansArabic-Bold.ttf'));
}

const _brand = PdfColor.fromInt(0xFF1F4E5F);
const _brandLight = PdfColor.fromInt(0xFFE6EFF2);
const _muted = PdfColor.fromInt(0xFF6B7280);
const _line = PdfColor.fromInt(0xFFD5DDE1);

/// يبني ملف PDF للوصل (حجم A5) بالعربي ومن اليمين لليسار.
Future<Uint8List> buildReceiptPdf(Receipt r) async {
  await _loadFonts();
  final store = AppStore.instance;
  final s = store.settings;
  final customer = store.customerById(r.customerId);
  final prevBalance = store.balanceOf(r.customerId, excludingReceiptId: r.id) -
      // الرصيد السابق = كل شيء قبل هذا الوصل فقط
      _laterActivity(r);
  final newBalance = prevBalance + r.remaining;

  final doc = pw.Document(title: 'وصل رقم ${r.number}', author: s.shopName);

  pw.Widget cell(String t, {bool bold = false, PdfColor? color, pw.TextAlign align = pw.TextAlign.center}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        child: pw.Text(t,
            textAlign: align,
            style: pw.TextStyle(fontSize: 10, fontWeight: bold ? pw.FontWeight.bold : null, color: color)),
      );

  pw.Widget summaryRow(String label, String value, {bool strong = false}) => pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: strong
            ? const pw.BoxDecoration(color: _brand, borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)))
            : null,
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(label,
                style: pw.TextStyle(
                    fontSize: strong ? 12 : 10,
                    fontWeight: strong ? pw.FontWeight.bold : null,
                    color: strong ? PdfColors.white : _muted)),
            pw.Text(value,
                style: pw.TextStyle(
                    fontSize: strong ? 12 : 10,
                    fontWeight: pw.FontWeight.bold,
                    color: strong ? PdfColors.white : PdfColors.black)),
          ],
        ),
      );

  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a5,
      margin: const pw.EdgeInsets.all(28),
      textDirection: pw.TextDirection.rtl,
      theme: pw.ThemeData.withFont(base: _regular!, bold: _bold!),
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          // الترويسة
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(s.shopName,
                        style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: _brand)),
                    if (s.shopPhone.isNotEmpty)
                      pw.Text('هاتف: ${s.shopPhone}', style: const pw.TextStyle(fontSize: 9, color: _muted)),
                    if (s.shopAddress.isNotEmpty)
                      pw.Text(s.shopAddress, style: const pw.TextStyle(fontSize: 9, color: _muted)),
                  ],
                ),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: const pw.BoxDecoration(
                    color: _brandLight, borderRadius: pw.BorderRadius.all(pw.Radius.circular(6))),
                child: pw.Column(children: [
                  pw.Text('وصل', style: const pw.TextStyle(fontSize: 9, color: _muted)),
                  pw.Text('#${r.number}',
                      textDirection: pw.TextDirection.ltr,
                      style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: _brand)),
                ]),
              ),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Container(height: 2, color: _brand),
          pw.SizedBox(height: 10),

          // معلومات الخلفة والتاريخ
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.RichText(
                text: pw.TextSpan(children: [
                  const pw.TextSpan(text: 'السيد: ', style: pw.TextStyle(fontSize: 10, color: _muted)),
                  pw.TextSpan(
                      text: customer?.name ?? '—',
                      style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                ]),
              ),
              pw.Text(fmtDateTime(r.date), style: const pw.TextStyle(fontSize: 9, color: _muted)),
            ],
          ),
          pw.SizedBox(height: 10),

          // جدول المنتجات
          pw.Table(
            border: pw.TableBorder.all(color: _line, width: 0.6),
            columnWidths: const {
              // جدول الـ pdf ما ينقلب تلقائياً، فنرتب الأعمدة من اليسار: المبلغ ... ت
              0: pw.FlexColumnWidth(2.6),
              1: pw.FlexColumnWidth(2.2),
              2: pw.FlexColumnWidth(2),
              3: pw.FlexColumnWidth(3),
              4: pw.FixedColumnWidth(22),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: _brand),
                children: [
                  cell('المبلغ', bold: true, color: PdfColors.white),
                  cell('السعر', bold: true, color: PdfColors.white),
                  cell('العدد', bold: true, color: PdfColors.white),
                  cell('المادة', bold: true, color: PdfColors.white),
                  cell('ت', bold: true, color: PdfColors.white),
                ],
              ),
              for (var i = 0; i < r.items.length; i++)
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: i.isOdd ? const PdfColor.fromInt(0xFFF6F8F9) : null),
                  children: [
                    cell(fmtNum(r.items[i].total), bold: true),
                    cell(fmtNum(r.items[i].unitPrice)),
                    cell('${fmtNum(r.items[i].qty)} ${r.items[i].unit}'),
                    cell(r.items[i].productName, bold: true, align: pw.TextAlign.right),
                    cell('${i + 1}'),
                  ],
                ),
            ],
          ),
          pw.SizedBox(height: 12),

          // الملخص
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                flex: 5,
                child: pw.Column(children: [
                  summaryRow('مجموع الوصل', fmtMoney(r.total), strong: true),
                  pw.SizedBox(height: 3),
                  summaryRow('الواصل', fmtMoney(r.paid)),
                  summaryRow('الباقي من الوصل', fmtMoney(r.remaining)),
                  pw.Container(height: 0.6, color: _line, margin: const pw.EdgeInsets.symmetric(vertical: 3)),
                  summaryRow('الحساب السابق', fmtMoney(prevBalance)),
                  summaryRow('الحساب الكلي', fmtMoney(newBalance)),
                ]),
              ),
              pw.SizedBox(width: 12),
              pw.Expanded(
                flex: 3,
                child: r.notes.isEmpty
                    ? pw.SizedBox()
                    : pw.Container(
                        padding: const pw.EdgeInsets.all(8),
                        decoration: pw.BoxDecoration(
                            border: pw.Border.all(color: _line),
                            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4))),
                        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                          pw.Text('ملاحظات', style: const pw.TextStyle(fontSize: 8, color: _muted)),
                          pw.Text(r.notes, style: const pw.TextStyle(fontSize: 9)),
                        ]),
                      ),
              ),
            ],
          ),
          pw.Spacer(),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(children: [
                pw.Text('توقيع المستلم', style: const pw.TextStyle(fontSize: 9, color: _muted)),
                pw.SizedBox(height: 22),
                pw.Container(width: 110, height: 0.6, color: _muted),
              ]),
              pw.Text('نشكر تعاملكم معنا', style: const pw.TextStyle(fontSize: 9, color: _muted)),
            ],
          ),
        ],
      ),
    ),
  );

  return doc.save();
}

/// صافي حركة الخلفة بعد تاريخ هذا الوصل (وصولات ودفعات لاحقة)،
/// حتى يكون "الحساب السابق" صحيحاً حتى لو أعدنا طباعة وصل قديم.
double _laterActivity(Receipt r) {
  final store = AppStore.instance;
  double v = 0;
  for (final o in store.receipts) {
    if (o.customerId == r.customerId && o.number > r.number) v += o.remaining;
  }
  for (final p in store.payments) {
    if (p.customerId == r.customerId && !p.date.isBefore(r.date)) v -= p.amount;
  }
  return v;
}

String receiptFileName(Receipt r) {
  final c = AppStore.instance.customerById(r.customerId);
  final name = (c?.name ?? 'customer').replaceAll(RegExp(r'[\\/:*?"<>|\s]+'), '_');
  return 'وصل_${r.number}_$name.pdf';
}
