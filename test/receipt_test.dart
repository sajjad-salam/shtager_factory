import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shtager/models.dart';
import 'package:shtager/receipt_pdf.dart';
import 'package:shtager/share_service.dart';
import 'package:shtager/store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('balances, export/import and PDF', () async {
    SharedPreferences.setMockInitialValues({});
    final s = AppStore.instance;
    await s.load();
    s.settings.shopPhone = '07701234567';
    s.settings.shopAddress = 'بغداد - الشارع الصناعي';
    for (final p in s.products) {
      p.price = {
        'شتايكر': 12500,
        'فوم': 8000,
        'ماستيك': 35000,
        'زفت': 90000,
        'فلانكوت': 42000,
        'فلين': 3500,
      }[p.name]!.toDouble();
    }
    final c = await s.addCustomer('أبو علي الخلفة', '0770 123 4567', '');
    final p = s.products;
    final r1 = await s.addReceipt(
      customerId: c.id,
      items: [
        ReceiptItem(
          productId: p[0].id,
          productName: p[0].name,
          unit: p[0].unit,
          qty: 40,
          unitPrice: p[0].price,
        ),
      ],
      paid: 100000,
    );
    expect(s.balanceOf(c.id), 400000);
    await Future.delayed(const Duration(milliseconds: 5));
    final r2 = await s.addReceipt(
      customerId: c.id,
      items: [
        for (final x in p.take(4))
          ReceiptItem(
            productId: x.id,
            productName: x.name,
            unit: x.unit,
            qty: 3,
            unitPrice: x.price,
          ),
      ],
      notes: 'التسليم بموقع العمل',
    );
    await s.addPayment(c.id, 50000, '');
    expect(s.balanceOf(c.id), 400000 + r2.total - 50000);
    expect(s.takenBy(c.id)['شتايكر']!.$1, 43);
    expect(normalizeWhatsApp('0770 123 4567'), '9647701234567');
    expect(normalizeWhatsApp('+964 770 123 4567'), '9647701234567');
    expect(fmtNum(1234567.5), '1,234,567.5');

    final json = s.exportDb();
    s.importDb(json);
    expect(s.receipts.length, 2);
    expect(s.nextReceiptNumber, 3);

    final out = Platform.environment['PDF_OUT'];
    if (out != null) {
      await File('$out/r1.pdf').writeAsBytes(await buildReceiptPdf(r1));
      await File('$out/r2.pdf').writeAsBytes(await buildReceiptPdf(r2));
    }
  });
}
