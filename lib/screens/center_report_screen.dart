import 'package:flutter/material.dart';

import '../charts.dart';
import '../models.dart';
import '../reports.dart';
import '../store.dart';
import '../ui.dart';
import 'factory_actions.dart';
import 'incoming_screen.dart';
import 'report_widgets.dart';

/// تقرير جهة وحدة: معمل، أو «معامل أخرى»، أو «منتجات أخرى».
class CenterReportScreen extends StatefulWidget {
  const CenterReportScreen({
    super.key,
    required this.centerId,
    this.period = ReportPeriod.all,
  });

  final String centerId;
  final ReportPeriod period;

  @override
  State<CenterReportScreen> createState() => _CenterReportScreenState();
}

class _CenterReportScreenState extends State<CenterReportScreen> {
  final store = AppStore.instance;
  late ReportPeriod _period = widget.period;

  bool get _isFactory => store.factoryById(widget.centerId) != null;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final id = widget.centerId;
        if (!store.centerIds.contains(id)) {
          return const Scaffold(body: SizedBox());
        }
        final report = Report.build(store, period: _period, centerId: id);
        final stats = report.centers[id]!;
        final factory = store.factoryById(id);
        return Scaffold(
          appBar: AppBar(
            title: Text(store.centerName(id)),
            actions: [
              const BackupIndicator(),
              if (factory != null)
                PopupMenuButton<String>(
                  tooltip: 'إدارة المعمل',
                  onSelected: (value) async {
                    if (value == 'rename') {
                      await renameFactoryFlow(context, factory);
                    } else if (value == 'delete') {
                      final deleted = await deleteFactoryFlow(context, factory);
                      if (deleted && context.mounted) Navigator.pop(context);
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'rename',
                      child: ListTile(
                        leading: Icon(Icons.edit_outlined),
                        title: Text('تعديل الاسم'),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        leading: Icon(Icons.delete_outline, color: debtColor),
                        title: Text('حذف المعمل'),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.page,
              4,
              AppSpace.page,
              110,
            ),
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Icon(centerIcon(id), size: 18, color: appMuted),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        centerHint(id),
                        style: const TextStyle(fontSize: 12, color: appMuted),
                      ),
                    ),
                  ],
                ),
              ),
              PeriodSelector(
                value: _period,
                onChanged: (p) => setState(() => _period = p),
              ),
              const SizedBox(height: 16),
              HeroProfitCard(
                report: report,
                title: 'ربح ${store.centerName(id)}',
                accent: centerColor(id),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (id != kOtherProductsId)
                    Expanded(
                      child: _miniTile(
                        'الشتايكر المباع',
                        '${fmtNum(stats.stygerQty)} ${stygerUnit()}',
                        Icons.inventory_outlined,
                      ),
                    ),
                  if (id != kOtherProductsId) const SizedBox(width: 10),
                  Expanded(
                    child: _miniTile(
                      'وصولات بيع',
                      '${stats.salesCount}',
                      Icons.receipt_long_outlined,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _miniTile(
                      'وصولات شراء',
                      '${stats.purchaseCount}',
                      Icons.shopping_bag_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              trendCard(report, subtitle: 'مبيعات ومشتريات هذه الجهة'),
              const SizedBox(height: 14),
              topCustomersCard(context, report),
              if (id == kOtherProductsId) ...[
                const SizedBox(height: 14),
                topProductsCard(report),
              ],
              const SizedBox(height: 14),
              purchasesByCategoryCard(report),
              const SizedBox(height: 14),
              topSuppliersCard(report),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => IncomingScreen(initialCenterId: id),
                  ),
                ),
                icon: const Icon(Icons.list_alt_rounded),
                label: const Text('كل مشتريات هذه الجهة'),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => NewIncomingReceiptScreen(centerId: id),
              ),
            ),
            icon: const Icon(Icons.add_rounded),
            label: Text(_isFactory ? 'صرف على المعمل' : 'وصل شراء'),
          ),
        );
      },
    );
  }

  Widget _miniTile(String label, String value, IconData icon) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: appSurface,
      borderRadius: BorderRadius.circular(AppRadius.card),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: brand),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: appInk,
            ),
          ),
        ),
        Text(label, style: const TextStyle(fontSize: 11, color: appMuted)),
      ],
    ),
  );
}
