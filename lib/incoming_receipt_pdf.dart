import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'models.dart';
import 'store.dart';

pw.Font? _regular;
pw.Font? _bold;

Future<void> _loadFonts() async {
  _regular ??= pw.Font.ttf(
    await rootBundle.load('assets/fonts/IBMPlexSansArabic-Regular.ttf'),
  );
  _bold ??= pw.Font.ttf(
    await rootBundle.load('assets/fonts/IBMPlexSansArabic-Bold.ttf'),
  );
}

const _brand = PdfColor.fromInt(0xFF1F4E5F);
const _brandSoft = PdfColor.fromInt(0xFFE7F0F2);
const _muted = PdfColor.fromInt(0xFF66757C);
const _line = PdfColor.fromInt(0xFFDCE3E5);

Future<Uint8List> buildIncomingReceiptPdf(IncomingReceipt receipt) async {
  await _loadFonts();
  final store = AppStore.instance;
  final settings = store.settings;
  final center = store.centerName(receipt.factoryId);
  final doc = pw.Document(
    title: 'وصل شراء رقم ${receipt.number}',
    author: settings.shopName,
  );

  pw.Widget infoRow(String label, String value, {bool strong = false}) =>
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: const pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(color: _line, width: .7)),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              label,
              style: const pw.TextStyle(fontSize: 10, color: _muted),
            ),
            pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: strong ? 14 : 11,
                fontWeight: strong ? pw.FontWeight.bold : null,
                color: strong ? _brand : PdfColors.black,
              ),
            ),
          ],
        ),
      );

  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a5,
      margin: const pw.EdgeInsets.all(30),
      textDirection: pw.TextDirection.rtl,
      theme: pw.ThemeData.withFont(base: _regular!, bold: _bold!),
      build: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    settings.shopName,
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                      color: _brand,
                    ),
                  ),
                  if (settings.shopPhone.isNotEmpty)
                    pw.Text(
                      settings.shopPhone,
                      style: const pw.TextStyle(fontSize: 9, color: _muted),
                    ),
                  if (settings.shopAddress.isNotEmpty)
                    pw.Text(
                      settings.shopAddress,
                      style: const pw.TextStyle(fontSize: 9, color: _muted),
                    ),
                ],
              ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: const pw.BoxDecoration(
                  color: _brandSoft,
                  borderRadius: pw.BorderRadius.all(pw.Radius.circular(7)),
                ),
                child: pw.Column(
                  children: [
                    pw.Text(
                      'وصل شراء',
                      style: const pw.TextStyle(fontSize: 9, color: _muted),
                    ),
                    pw.Text(
                      '#${receipt.number}',
                      textDirection: pw.TextDirection.ltr,
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                        color: _brand,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Container(height: 2, color: _brand),
          pw.SizedBox(height: 16),
          pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: _line),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
            ),
            child: pw.Column(
              children: [
                infoRow('الجهة', center),
                if (receipt.supplier.isNotEmpty)
                  infoRow('اشتريت من', receipt.supplier),
                infoRow('نوع الصرف', receipt.category.label),
                infoRow('التاريخ', fmtDateTime(receipt.date)),
                infoRow('المبلغ', fmtMoney(receipt.amount), strong: true),
              ],
            ),
          ),
          if (receipt.notes.isNotEmpty) ...[
            pw.SizedBox(height: 16),
            pw.Text(
              'الملاحظات',
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 6),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: const pw.BoxDecoration(
                color: PdfColor.fromInt(0xFFF5F7F7),
                borderRadius: pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Text(
                receipt.notes,
                style: const pw.TextStyle(fontSize: 11),
              ),
            ),
          ],
          pw.Spacer(),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'توقيع المستلم',
                style: const pw.TextStyle(fontSize: 9, color: _muted),
              ),
              pw.Text(
                'توقيع الإدارة',
                style: const pw.TextStyle(fontSize: 9, color: _muted),
              ),
            ],
          ),
          pw.SizedBox(height: 24),
          pw.Container(height: .7, color: _line),
        ],
      ),
    ),
  );
  return doc.save();
}

String incomingReceiptFileName(IncomingReceipt receipt) {
  final center = AppStore.instance.centerName(receipt.factoryId);
  final name = center.replaceAll(RegExp(r'[\\/:*?"<>|\s]+'), '_');
  return 'شراء_${receipt.number}_$name.pdf';
}
