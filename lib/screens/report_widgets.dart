import 'package:flutter/material.dart';

import '../charts.dart';
import '../models.dart';
import '../reports.dart';
import '../store.dart';
import '../ui.dart';
import 'customer_detail_screen.dart';

/// ألوان تصنيفات المشتريات بترتيب ثابت (مفحوص لعمى الألوان).
Color categoryColor(IncomingCategory c) => switch (c) {
  IncomingCategory.cement => const Color(0xFF2A78D6),
  IncomingCategory.gravel => const Color(0xFFEB6834),
  IncomingCategory.sand => const Color(0xFF1BAF7A),
  IncomingCategory.workers => const Color(0xFFEDA100),
  IncomingCategory.goods => const Color(0xFFE87BA4),
  IncomingCategory.other => const Color(0xFF008300),
};

String stygerUnit() {
  for (final p in AppStore.instance.products) {
    if (p.factoryMade) return p.unit;
  }
  return 'قطعة';
}

/// بطاقة الربح الرئيسية.
class HeroProfitCard extends StatelessWidget {
  const HeroProfitCard({
    super.key,
    required this.report,
    required this.title,
    this.accent,
  });

  final Report report;
  final String title;

  /// لون الجهة (يظهر كشريط صغير) بتقرير المعمل.
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final profit = report.profit;
    final margin = report.totalSales > 0 ? profit / report.totalSales : null;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: brand,
        borderRadius: BorderRadius.circular(AppRadius.tile),
        boxShadow: [
          BoxShadow(
            color: brand.withValues(alpha: .18),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (accent != null) ...[
                LegendDot(accent!, size: 12),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  report.period.label,
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          FittedBox(
            alignment: AlignmentDirectional.centerStart,
            fit: BoxFit.scaleDown,
            child: Text(
              fmtMoney(profit),
              style: TextStyle(
                color: profit >= 0 ? Colors.white : const Color(0xFFFFD5D1),
                fontSize: 32,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (margin != null)
            Text(
              profit >= 0
                  ? 'هامش الربح ${(margin * 100).round()}% من المبيعات'
                  : 'المصروفات أكثر من المبيعات بهذه الفترة',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _stat(
                  'المبيعات',
                  report.totalSales,
                  '${_salesCount(report)} وصل',
                  Icons.arrow_upward_rounded,
                ),
              ),
              Container(
                width: 1,
                height: 46,
                color: Colors.white.withValues(alpha: .18),
              ),
              Expanded(
                child: _stat(
                  'المشتريات',
                  report.totalPurchases,
                  '${report.purchaseCount} وصل',
                  Icons.arrow_downward_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static int _salesCount(Report r) => r.centerId == null
      ? r.salesCount
      : r.centers.values.fold(0, (s, c) => s + c.salesCount);

  Widget _stat(String label, double amount, String sub, IconData icon) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            Icon(icon, color: Colors.white70, size: 19),
            const SizedBox(width: 7),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(color: Colors.white60, fontSize: 11),
                  ),
                  Text(
                    fmtMoney(amount),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    sub,
                    style: const TextStyle(color: Colors.white60, fontSize: 10),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

/// توزيع المبيعات على الجهات.
Widget salesShareCard(Report report) {
  final store = AppStore.instance;
  final segs = [
    for (final c in report.centers.values)
      ChartSegment(store.centerName(c.id), c.sales, centerColor(c.id)),
  ];
  return ChartCard(
    title: 'توزيع المبيعات',
    subtitle: 'حصة كل جهة من مجموع المبيعات — اضغط للتفاصيل',
    child: report.totalSales <= 0
        ? const ChartEmpty('ماكو مبيعات بهذه الفترة')
        : DonutChart(segments: segs, centerLabel: 'المبيعات'),
  );
}

Widget trendCard(Report report, {String? subtitle}) => ChartCard(
  title: 'آخر ٦ أشهر',
  subtitle: subtitle ?? 'المبيعات مقابل المشتريات — اضغط على أي شهر',
  child: report.months.every((m) => m.sales == 0 && m.purchases == 0)
      ? const ChartEmpty('ماكو حركة بآخر ٦ أشهر')
      : MonthlyTrendChart(months: report.months),
);

Widget topCustomersCard(BuildContext context, Report report) => ChartCard(
  title: 'أكثر الخلفات شراءً',
  subtitle: 'حسب مبلغ اللي أخذوه منك بهذه الفترة',
  child: report.topCustomers.isEmpty
      ? const ChartEmpty(
          'ماكو مبيعات للخلفات بهذه الفترة',
          icon: Icons.people_alt_outlined,
        )
      : RankedBars(
          items: report.topCustomers,
          color: (_) => salesSeriesColor,
          onTap: (item) {
            if (AppStore.instance.customerById(item.id) == null) return;
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => CustomerDetailScreen(customerId: item.id),
              ),
            );
          },
        ),
);

Widget activeFactoriesCard(Report report) {
  final store = AppStore.instance;
  final unit = stygerUnit();
  final items = [
    for (final c in report.activeSources)
      RankItem(
        c.id,
        store.centerName(c.id),
        c.stygerQty,
        sub: '${c.salesCount} وصل · ${fmtMoney(c.sales)}',
      ),
  ];
  return ChartCard(
    title: 'أنشط المعامل',
    subtitle: 'كمية الشتايكر المباعة من كل معمل',
    child: items.isEmpty
        ? const ChartEmpty(
            'ماكو شتايكر مباع بهذه الفترة',
            icon: Icons.factory_outlined,
          )
        : RankedBars(
            items: items,
            color: (i) => centerColor(i.id),
            valueText: (i) => '${fmtNum(i.value)} $unit',
          ),
  );
}

Widget topProductsCard(Report report) => ChartCard(
  title: 'المنتجات الأكثر مبيعاً',
  subtitle: 'حسب المبلغ، مع الكمية',
  child: report.topProducts.isEmpty
      ? const ChartEmpty('ماكو مبيعات بهذه الفترة', icon: Icons.sell_outlined)
      : RankedBars(items: report.topProducts, color: (_) => salesSeriesColor),
);

Widget purchasesByCategoryCard(Report report) {
  final entries = report.purchasesByCategory.entries.toList()
    ..sort((a, b) => a.key.index.compareTo(b.key.index));
  return ChartCard(
    title: 'وين تروح المصروفات؟',
    subtitle: 'المشتريات حسب النوع',
    child: entries.isEmpty
        ? const ChartEmpty(
            'ماكو مشتريات بهذه الفترة',
            icon: Icons.inventory_2_outlined,
          )
        : DonutChart(
            centerLabel: 'المشتريات',
            segments: [
              for (final e in entries)
                ChartSegment(e.key.label, e.value, categoryColor(e.key)),
            ],
          ),
  );
}

Widget topSuppliersCard(Report report) => ChartCard(
  title: 'أكثر الجهات اللي تشتري منها',
  subtitle: 'حسب المبلغ بهذه الفترة',
  child: report.topSuppliers.isEmpty
      ? const ChartEmpty(
          'اكتب «اشتريت من؟» بوصل الشراء حتى تطلع الجهات هنا',
          icon: Icons.storefront_outlined,
        )
      : RankedBars(
          items: report.topSuppliers,
          color: (_) => purchasesSeriesColor,
        ),
);
