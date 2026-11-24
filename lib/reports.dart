// محرك التقارير: يوزع كل سطر بيع وكل وصل شراء على جهته.
//
// القاعدة:
// - سطر الشتايكر (factoryMade) يروح للمعمل المختار بالوصل، أو «معامل أخرى».
// - أي منتج ثاني يروح إلى «منتجات أخرى».
// - وصل الشراء يروح للجهة المكتوبة بيه.
// الربح التقديري لكل جهة = مبيعاتها − مشترياتها.

import 'models.dart';
import 'store.dart';

enum ReportPeriod { month, quarter, year, all }

extension ReportPeriodInfo on ReportPeriod {
  String get label => switch (this) {
    ReportPeriod.month => 'هذا الشهر',
    ReportPeriod.quarter => 'آخر ٣ أشهر',
    ReportPeriod.year => 'هذه السنة',
    ReportPeriod.all => 'الكل',
  };

  /// بداية الفترة، أو null للكل.
  DateTime? start(DateTime now) => switch (this) {
    ReportPeriod.month => DateTime(now.year, now.month),
    ReportPeriod.quarter => DateTime(now.year, now.month - 2),
    ReportPeriod.year => DateTime(now.year),
    ReportPeriod.all => null,
  };
}

class CenterStats {
  CenterStats(this.id);

  final String id;
  double sales = 0;
  double purchases = 0;

  /// كمية الشتايكر المباعة (للمعامل و«معامل أخرى» فقط).
  double stygerQty = 0;
  final Set<String> _saleReceipts = {};
  int purchaseCount = 0;

  int get salesCount => _saleReceipts.length;
  double get profit => sales - purchases;

  /// هامش الربح من المبيعات، أو null إذا ماكو مبيعات.
  double? get margin => sales > 0 ? profit / sales : null;
  bool get isEmpty => sales == 0 && purchases == 0;
}

class RankItem {
  const RankItem(this.id, this.label, this.value, {this.sub});

  final String id;
  final String label;
  final double value;
  final String? sub;
}

class MonthPoint {
  MonthPoint(this.month);

  final DateTime month;
  double sales = 0;
  double purchases = 0;
  double get profit => sales - purchases;
}

const arabicMonths = [
  'كانون الثاني',
  'شباط',
  'آذار',
  'نيسان',
  'أيار',
  'حزيران',
  'تموز',
  'آب',
  'أيلول',
  'تشرين الأول',
  'تشرين الثاني',
  'كانون الأول',
];

/// أسماء قصيرة لمحور الرسم (تشرين وكانون يتكررون فنميزهم بالرقم).
const shortArabicMonths = [
  'ك٢',
  'شباط',
  'آذار',
  'نيسان',
  'أيار',
  'حزيران',
  'تموز',
  'آب',
  'أيلول',
  'ت١',
  'ت٢',
  'ك١',
];

class Report {
  Report._(this.period, this.centerId);

  final ReportPeriod period;

  /// إذا محدد، التقرير يخص جهة وحدة فقط.
  final String? centerId;

  final Map<String, CenterStats> centers = {};
  final List<MonthPoint> months = [];
  final Map<IncomingCategory, double> purchasesByCategory = {};
  List<RankItem> topCustomers = [];
  List<RankItem> topProducts = [];
  List<RankItem> topSuppliers = [];
  int salesCount = 0;
  int purchaseCount = 0;

  double get totalSales => centers.values.fold(0, (s, c) => s + c.sales);
  double get totalPurchases =>
      centers.values.fold(0, (s, c) => s + c.purchases);
  double get profit => totalSales - totalPurchases;
  bool get isEmpty => salesCount == 0 && purchaseCount == 0;

  /// الجهات اللي يطلع منها شتايكر مرتبة حسب الكمية (أنشط المعامل).
  List<CenterStats> get activeSources =>
      centers.values
          .where((c) => c.id != kOtherProductsId && c.stygerQty > 0)
          .toList()
        ..sort((a, b) => b.stygerQty.compareTo(a.stygerQty));

  static Report build(
    AppStore store, {
    ReportPeriod period = ReportPeriod.all,
    String? centerId,
    DateTime? now,
  }) {
    final today = now ?? DateTime.now();
    final from = period.start(today);
    final report = Report._(period, centerId);
    for (final id in store.centerIds) {
      if (centerId == null || id == centerId) {
        report.centers[id] = CenterStats(id);
      }
    }
    for (var i = 5; i >= 0; i--) {
      report.months.add(MonthPoint(DateTime(today.year, today.month - i)));
    }
    MonthPoint? monthOf(DateTime d) {
      for (final m in report.months) {
        if (m.month.year == d.year && m.month.month == d.month) return m;
      }
      return null;
    }

    bool inPeriod(DateTime d) => from == null || !d.isBefore(from);

    final byCustomer = <String, double>{};
    final byProduct = <String, (double amount, double qty, String unit)>{};
    final saleReceiptIds = <String>{};

    for (final r in store.receipts) {
      final source = stygerSourceOf(store, r);
      final month = monthOf(r.date);
      final active = inPeriod(r.date);
      for (final item in r.items) {
        final center = item.factoryMade ? source : kOtherProductsId;
        final stats = report.centers[center];
        if (stats == null) continue;
        month?.sales += item.total;
        if (!active) continue;
        stats.sales += item.total;
        stats._saleReceipts.add(r.id);
        if (item.factoryMade) stats.stygerQty += item.qty;
        saleReceiptIds.add(r.id);
        byCustomer[r.customerId] = (byCustomer[r.customerId] ?? 0) + item.total;
        final prev = byProduct[item.productName];
        byProduct[item.productName] = (
          (prev?.$1 ?? 0) + item.total,
          (prev?.$2 ?? 0) + item.qty,
          item.unit,
        );
      }
    }
    report.salesCount = saleReceiptIds.length;

    final bySupplier = <String, (double amount, int count)>{};
    for (final p in store.incomingReceipts) {
      final center = purchaseCenterOf(store, p);
      final stats = report.centers[center];
      if (stats == null) continue;
      monthOf(p.date)?.purchases += p.amount;
      if (!inPeriod(p.date)) continue;
      stats.purchases += p.amount;
      stats.purchaseCount++;
      report.purchaseCount++;
      report.purchasesByCategory[p.category] =
          (report.purchasesByCategory[p.category] ?? 0) + p.amount;
      final supplier = p.supplier.trim();
      if (supplier.isNotEmpty) {
        final prev = bySupplier[supplier];
        bySupplier[supplier] = (
          (prev?.$1 ?? 0) + p.amount,
          (prev?.$2 ?? 0) + 1,
        );
      }
    }

    report.topCustomers = [
      for (final e in byCustomer.entries)
        RankItem(
          e.key,
          store.customerById(e.key)?.name ?? '—',
          e.value,
          sub: 'عليه حالياً ${fmtMoney(store.balanceOf(e.key))}',
        ),
    ]..sort((a, b) => b.value.compareTo(a.value));
    report.topProducts = [
      for (final e in byProduct.entries)
        RankItem(
          e.key,
          e.key,
          e.value.$1,
          sub: '${fmtNum(e.value.$2)} ${e.value.$3}',
        ),
    ]..sort((a, b) => b.value.compareTo(a.value));
    report.topSuppliers = [
      for (final e in bySupplier.entries)
        RankItem(e.key, e.key, e.value.$1, sub: '${e.value.$2} وصل'),
    ]..sort((a, b) => b.value.compareTo(a.value));
    return report;
  }
}

/// الجهة اللي يُحسب عليها شتايكر الوصل.
String stygerSourceOf(AppStore store, Receipt r) {
  if (r.factoryId == kOtherFactoriesId) return kOtherFactoriesId;
  if (store.factoryById(r.factoryId) != null) return r.factoryId;
  if (r.factoryId.isEmpty && store.factories.isNotEmpty) {
    return store.factories.first.id;
  }
  return kOtherFactoriesId;
}

/// الجهة اللي يُحسب عليها وصل الشراء.
String purchaseCenterOf(AppStore store, IncomingReceipt p) {
  if (p.factoryId == kOtherFactoriesId || p.factoryId == kOtherProductsId) {
    return p.factoryId;
  }
  if (store.factoryById(p.factoryId) != null) return p.factoryId;
  return kOtherFactoriesId;
}

/// تنسيق مختصر للمحاور: ٢٥٠ ألف، ١٫٥ مليون.
String fmtCompact(num v) {
  final a = v.abs();
  String trim(double x) =>
      x.toStringAsFixed(x >= 10 ? 0 : 1).replaceAll(RegExp(r'\.0$'), '');
  final sign = v < 0 ? '-' : '';
  if (a >= 1e9) return '$sign${trim(a / 1e9)} مليار';
  if (a >= 1e6) return '$sign${trim(a / 1e6)} مليون';
  if (a >= 1e3) return '$sign${trim(a / 1e3)} ألف';
  return '$sign${fmtNum(a)}';
}
