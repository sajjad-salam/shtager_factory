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

/// بطاقة الربح الرئيسية: رقم واحد كبير، وتحته البيع والصرف.
class HeroProfitCard extends StatelessWidget {
  const HeroProfitCard({
    super.key,
    required this.report,
    this.title = 'الربح',
    this.accent,
  });

  final Report report;
  final String title;

  /// لون المعمل بتقرير المعمل.
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final profit = report.profit;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: brand,
        borderRadius: BorderRadius.circular(AppRadius.tile),
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
              Text(
                title,
                style: const TextStyle(color: Colors.white70, fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 2),
          FittedBox(
            alignment: AlignmentDirectional.centerStart,
            fit: BoxFit.scaleDown,
            child: Text(
              fmtMoney(profit),
              style: TextStyle(
                color: profit >= 0 ? Colors.white : const Color(0xFFFFD5D1),
                fontSize: 34,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _stat(
                  'المبيعات',
                  report.totalSales,
                  Icons.arrow_upward_rounded,
                ),
              ),
              Container(
                width: 1,
                height: 38,
                color: Colors.white.withValues(alpha: .18),
              ),
              Expanded(
                child: _stat(
                  'المشتريات',
                  report.totalPurchases,
                  Icons.arrow_downward_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, double amount, IconData icon) => Padding(
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
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              FittedBox(
                alignment: AlignmentDirectional.centerStart,
                fit: BoxFit.scaleDown,
                child: Text(
                  fmtMoney(amount),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget trendCard(Report report) => ChartCard(
  title: 'آخر ٦ أشهر',
  child: report.months.every((m) => m.sales == 0 && m.purchases == 0)
      ? const ChartEmpty('ماكو شي بعد')
      : MonthlyTrendChart(months: report.months),
);

Widget topCustomersCard(BuildContext context, Report report) => ChartCard(
  title: 'أكثر الخلفات شراءً',
  child: report.topCustomers.isEmpty
      ? const ChartEmpty('ماكو شي بعد', icon: Icons.people_alt_outlined)
      : RankedBars(
          items: [
            for (final c in report.topCustomers)
              RankItem(c.id, c.label, c.value),
          ],
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
      RankItem(c.id, store.centerName(c.id), c.stygerQty),
  ];
  return ChartCard(
    title: 'الشتايكر المباع',
    child: items.isEmpty
        ? const ChartEmpty('ماكو شي بعد', icon: Icons.factory_outlined)
        : RankedBars(
            items: items,
            color: (i) => centerColor(i.id),
            valueText: (i) => '${fmtNum(i.value)} $unit',
          ),
  );
}

Widget purchasesByCategoryCard(Report report) {
  final entries = report.purchasesByCategory.entries.toList()
    ..sort((a, b) => a.key.index.compareTo(b.key.index));
  return ChartCard(
    title: 'المصروفات',
    child: entries.isEmpty
        ? const ChartEmpty('ماكو شي بعد', icon: Icons.inventory_2_outlined)
        : DonutChart(
            centerLabel: 'المجموع',
            segments: [
              for (final e in entries)
                ChartSegment(e.key.label, e.value, categoryColor(e.key)),
            ],
          ),
  );
}
