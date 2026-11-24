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
              PeriodSelector(
                value: _period,
                onChanged: (p) => setState(() => _period = p),
              ),
              const SizedBox(height: 16),
              HeroProfitCard(
                report: report,
                title: 'الربح',
                accent: centerColor(id),
              ),
              if (id != kOtherProductsId) ...[
                const SizedBox(height: 12),
                _miniTile(
                  'الشتايكر المباع',
                  '${fmtNum(stats.stygerQty)} ${stygerUnit()}',
                  Icons.inventory_outlined,
                ),
              ],
              const SizedBox(height: 16),
              trendCard(report),
              const SizedBox(height: 14),
              topCustomersCard(context, report),
              const SizedBox(height: 14),
              purchasesByCategoryCard(report),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => IncomingScreen(initialCenterId: id),
                  ),
                ),
                icon: const Icon(Icons.list_alt_rounded),
                label: const Text('المشتريات'),
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
            label: const Text('وصل شراء'),
          ),
        );
      },
    );
  }

  Widget _miniTile(String label, String value, IconData icon) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: appSurface,
      borderRadius: BorderRadius.circular(AppRadius.card),
    ),
    child: Row(
      children: [
        Icon(icon, color: brand),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 15, color: appInk),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: appInk,
          ),
        ),
      ],
    ),
  );
}
