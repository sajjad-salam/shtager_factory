import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shtager/models.dart';
import 'package:shtager/reports.dart';
import 'package:shtager/store.dart';

ReceiptItem _item(Product p, double qty) => ReceiptItem(
  productId: p.id,
  productName: p.name,
  unit: p.unit,
  qty: qty,
  unitPrice: p.price,
  factoryMade: p.factoryMade,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'sales split: Styger to chosen factory, rest to other products',
    () async {
      SharedPreferences.setMockInitialValues({});
      final s = AppStore.instance;
      await s.load();
      final styger = s.products.firstWhere((p) => p.id == 'p_staiger');
      final foam = s.products.firstWhere((p) => p.id == 'p_foam');
      expect(styger.factoryMade, isTrue);
      expect(foam.factoryMade, isFalse);
      styger.price = 12500;
      foam.price = 8000;

      final f1 = s.factories.single;
      final f2 = await s.addFactory('معمل ٢');
      final c = await s.addCustomer('أبو حيدر', '', '');

      final mixed = await s.addReceipt(
        customerId: c.id,
        items: [_item(styger, 10), _item(foam, 2)],
        factoryId: f1.id,
      );
      expect(mixed.factoryTotal, 125000);
      expect(mixed.otherProductsTotal, 16000);
      await s.addReceipt(
        customerId: c.id,
        items: [_item(styger, 4)],
        factoryId: f2.id,
      );
      await s.addReceipt(
        customerId: c.id,
        items: [_item(styger, 3)],
        factoryId: kOtherFactoriesId,
      );
      final foamOnly = await s.addReceipt(
        customerId: c.id,
        items: [_item(foam, 1)],
        factoryId: f1.id, // يُتجاهل لأن الوصل ما بيه شتايكر
      );
      expect(foamOnly.factoryId, '');

      await s.addIncomingReceipt(
        factoryId: f1.id,
        category: IncomingCategory.cement,
        amount: 50000,
        supplier: 'أسمنت كربلاء',
      );
      await s.addIncomingReceipt(
        factoryId: f2.id,
        category: IncomingCategory.workers,
        amount: 20000,
      );
      await s.addIncomingReceipt(
        factoryId: kOtherFactoriesId,
        category: IncomingCategory.goods,
        amount: 30000,
        supplier: 'أسمنت كربلاء',
      );
      await s.addIncomingReceipt(
        factoryId: kOtherProductsId,
        category: IncomingCategory.goods,
        amount: 10000,
      );

      final r = Report.build(s);
      expect(r.centers.keys.toList(), [
        f1.id,
        f2.id,
        kOtherFactoriesId,
        kOtherProductsId,
      ]);
      expect(r.centers[f1.id]!.sales, 125000);
      expect(r.centers[f1.id]!.profit, 75000);
      expect(r.centers[f1.id]!.stygerQty, 10);
      expect(r.centers[f2.id]!.sales, 50000);
      expect(r.centers[f2.id]!.profit, 30000);
      expect(r.centers[kOtherFactoriesId]!.sales, 37500);
      expect(r.centers[kOtherFactoriesId]!.profit, 7500);
      expect(r.centers[kOtherProductsId]!.sales, 24000);
      expect(r.centers[kOtherProductsId]!.profit, 14000);
      expect(r.totalSales, s.totalSales);
      expect(r.profit, s.estimatedProfit);
      expect(r.salesCount, 4);
      expect(r.topCustomers.single.value, s.totalSales);
      expect(r.topSuppliers.first.label, 'أسمنت كربلاء');
      expect(r.topSuppliers.first.value, 80000);
      expect(r.activeSources.first.id, f1.id);
      expect(s.suppliersFor().first, 'أسمنت كربلاء');

      // تقرير جهة وحدة
      final only = Report.build(s, centerId: f2.id);
      expect(only.centers.keys.single, f2.id);
      expect(only.totalSales, 50000);
      expect(only.topCustomers.single.value, 50000);

      // الحفظ والاسترجاع يحتفظ بالمعمل والمورد
      s.importDb(s.exportDb());
      expect(Report.build(s).centers[f2.id]!.sales, 50000);
      expect(s.incomingReceipts.where((p) => p.supplier.isNotEmpty).length, 2);

      // حذف معمل: مشترياته تنحذف، ومبيعاته تنتقل لـ«معامل أخرى»
      final balanceBefore = s.balanceOf(c.id);
      await s.deleteFactory(f2.id);
      expect(s.balanceOf(c.id), balanceBefore);
      final after = Report.build(s);
      expect(after.centers.containsKey(f2.id), isFalse);
      expect(after.centers[kOtherFactoriesId]!.sales, 87500);
      expect(after.totalPurchases, 90000);
    },
  );

  test('period filter keeps only receipts inside the period', () async {
    SharedPreferences.setMockInitialValues({});
    final s = AppStore.instance;
    await s.load();
    final now = DateTime(2026, 11, 24);
    final styger = s.products.first..price = 1000;
    final r = await s.addReceipt(
      customerId: 'x',
      items: [_item(styger, 1)],
      factoryId: s.factories.first.id,
    );
    s.importDb({
      ...s.exportDb(),
      'receipts': [
        {...r.toJson(), 'date': '2026-11-10T10:00:00.000'},
        {...r.toJson(), 'id': 'old', 'date': '2026-01-05T10:00:00.000'},
      ],
    }, save: false);
    expect(Report.build(s, now: now).totalSales, 2000);
    expect(
      Report.build(s, period: ReportPeriod.month, now: now).totalSales,
      1000,
    );
    expect(Report.build(s, now: now).months.last.sales, 1000);
  });

  test('legacy sales migrate to the first factory', () async {
    final legacy = {
      'app': 'shtager',
      'version': 2,
      'products': [
        {'id': 'p_staiger', 'name': 'شتايكر', 'unit': 'قطعة', 'price': 1},
        {'id': 'p_foam', 'name': 'فوم', 'unit': 'لوح', 'price': 1},
      ],
      'factories': [
        {'id': 'factory_main', 'name': 'المعمل الرئيسي'},
      ],
      'receipts': [
        {
          'id': 'a',
          'number': 1,
          'customerId': 'c',
          'date': '2026-10-01T10:00:00.000',
          'items': [
            {
              'productId': 'p_staiger',
              'productName': 'شتايكر',
              'unit': 'قطعة',
              'qty': 5,
              'unitPrice': 1000,
            },
          ],
        },
        {
          'id': 'b',
          'number': 2,
          'customerId': 'c',
          'date': '2026-10-02T10:00:00.000',
          'items': [
            {
              'productId': 'p_foam',
              'productName': 'فوم',
              'unit': 'لوح',
              'qty': 1,
              'unitPrice': 500,
            },
          ],
        },
      ],
    };
    SharedPreferences.setMockInitialValues({'db_v1': jsonEncode(legacy)});
    final s = AppStore.instance;
    await s.load();
    expect(s.products.first.factoryMade, isTrue);
    expect(s.products.last.factoryMade, isFalse);
    expect(s.receipts.first.factoryId, 'factory_main');
    expect(s.receipts.last.factoryId, '');
    final r = Report.build(s);
    expect(r.centers['factory_main']!.sales, 5000);
    expect(r.centers[kOtherProductsId]!.sales, 500);
  });
}
