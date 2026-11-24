import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'charts.dart';
import 'reports.dart';
import 'screens/center_report_screen.dart';
import 'screens/customers_screen.dart';
import 'screens/factory_actions.dart';
import 'screens/incoming_screen.dart';
import 'screens/new_receipt_screen.dart';
import 'screens/prices_screen.dart';
import 'screens/receipts_screen.dart';
import 'screens/report_widgets.dart';
import 'screens/settings_screen.dart';
import 'store.dart';
import 'telegram_backup.dart';
import 'ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppStore.instance.load();
  runApp(const ShtagerApp());
  // إذا بقت تغييرات ما انرسلت للتليجرام (مثلاً كان النت طافي) نرسلها هسه.
  TelegramBackup.instance.flushPending();
}

class ShtagerApp extends StatelessWidget {
  const ShtagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'معمل الشتايكر',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: buildTheme(),
      builder: (context, child) => NumericKeyboardAccessoryHost(
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: child ?? const SizedBox.shrink(),
        ),
      ),
      home: const MainDashboard(),
    );
  }
}

/// الصفحة الرئيسية: التقارير بالأعلى، ثم الأقسام والمعامل والرسوم.
class MainDashboard extends StatefulWidget {
  const MainDashboard({super.key});

  @override
  State<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends State<MainDashboard> {
  final store = AppStore.instance;
  ReportPeriod _period = ReportPeriod.all;

  void _openCenter(String id) => Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => CenterReportScreen(centerId: id, period: _period),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final report = Report.build(store, period: _period);
        final noData = store.receipts.isEmpty && store.incomingReceipts.isEmpty;
        return Scaffold(
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.page,
                12,
                AppSpace.page,
                30,
              ),
              children: [
                _header(),
                const SizedBox(height: 18),
                PeriodSelector(
                  value: _period,
                  onChanged: (p) => setState(() => _period = p),
                ),
                const SizedBox(height: 14),
                HeroProfitCard(report: report),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _SectionTile(
                        title: 'المبيعات',
                        icon: Icons.north_east_rounded,
                        color: okColor,
                        addLabel: 'بيع',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const SalesShell()),
                        ),
                        onAdd: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const NewReceiptScreen(),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _SectionTile(
                        title: 'المشتريات',
                        icon: Icons.south_west_rounded,
                        color: debtColor,
                        addLabel: 'شراء',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const IncomingScreen(),
                          ),
                        ),
                        onAdd: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const NewIncomingReceiptScreen(),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (noData) ...[_welcome(), const SizedBox(height: 16)],
                ChartCard(
                  title: 'ربح كل معمل',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ProfitCompareChart(
                        stats: report.centers.values.toList(),
                        onTap: _openCenter,
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final f = await addFactoryFlow(context);
                          if (f != null) setState(() {});
                        },
                        icon: const Icon(Icons.add_business_outlined),
                        label: const Text('إضافة معمل'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                trendCard(report),
                const SizedBox(height: 14),
                topCustomersCard(context, report),
                const SizedBox(height: 14),
                activeFactoriesCard(report),
                const SizedBox(height: 14),
                purchasesByCategoryCard(report),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _header() => Row(
    children: [
      Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: brand.withValues(alpha: .1),
          borderRadius: BorderRadius.circular(15),
        ),
        child: const Icon(Icons.factory_rounded, color: brand),
      ),
      const SizedBox(width: 11),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              store.settings.shopName,
              style: const TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w700,
                color: appInk,
              ),
            ),
          ],
        ),
      ),
      const BackupIndicator(),
      IconButton(
        tooltip: 'الإعدادات',
        onPressed: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const _SettingsPage())),
        icon: const Icon(Icons.settings_outlined),
      ),
    ],
  );

  Widget _welcome() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: brand.withValues(alpha: .07),
      borderRadius: BorderRadius.circular(AppRadius.card),
    ),
    child: const Row(
      children: [
        Icon(Icons.lightbulb_outline_rounded, color: brand),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            'سجّل أول وصل، والتقارير تطلع هنا.',
            style: TextStyle(fontSize: 13, height: 1.5),
          ),
        ),
      ],
    ),
  );
}

class _SectionTile extends StatelessWidget {
  const _SectionTile({
    required this.title,
    required this.icon,
    required this.color,
    required this.addLabel,
    required this.onTap,
    required this.onAdd,
  });

  final String title;
  final IconData icon;
  final Color color;
  final String addLabel;
  final VoidCallback onTap;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => Material(
    color: appSurface,
    borderRadius: BorderRadius.circular(AppRadius.tile),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.tile),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .11),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const Spacer(),
                const Icon(Icons.chevron_right_rounded, color: appMuted),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            FilledButton.tonalIcon(
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 40),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text('وصل $addLabel'),
            ),
          ],
        ),
      ),
    ),
  );
}

class _SettingsPage extends StatelessWidget {
  const _SettingsPage();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('الإعدادات')),
    body: const SettingsScreen(),
  );
}

/// قسم المبيعات: الخلفات، وصولات البيع، الأسعار.
class SalesShell extends StatefulWidget {
  const SalesShell({super.key});

  @override
  State<SalesShell> createState() => _SalesShellState();
}

class _SalesShellState extends State<SalesShell> {
  int _tab = 0;

  static const _titles = ['المبيعات', 'وصولات البيع', 'الأسعار'];

  @override
  Widget build(BuildContext context) {
    final pages = const [CustomersScreen(), ReceiptsScreen(), PricesScreen()];
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_tab]),
        actions: const [BackupIndicator(), SizedBox(width: 8)],
      ),
      body: IndexedStack(index: _tab, children: pages),
      floatingActionButton: _tab <= 1
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const NewReceiptScreen()),
              ),
              icon: const Icon(Icons.receipt_long),
              label: const Text('وصل بيع'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.people_alt_outlined),
            selectedIcon: Icon(Icons.people_alt),
            label: 'الخلفات',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'الوصولات',
          ),
          NavigationDestination(
            icon: Icon(Icons.sell_outlined),
            selectedIcon: Icon(Icons.sell),
            label: 'الأسعار',
          ),
        ],
      ),
    );
  }
}
