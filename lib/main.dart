import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'screens/customers_screen.dart';
import 'screens/new_receipt_screen.dart';
import 'screens/prices_screen.dart';
import 'screens/receipts_screen.dart';
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
      home: const HomeShell(),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;

  static const _titles = ['الخلفات', 'الوصولات', 'الأسعار', 'الإعدادات'];

  @override
  Widget build(BuildContext context) {
    final pages = const [
      CustomersScreen(),
      ReceiptsScreen(),
      PricesScreen(),
      SettingsScreen(),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _tab == 0 ? AppStore.instance.settings.shopName : _titles[_tab],
        ),
        actions: const [BackupIndicator(), SizedBox(width: 8)],
      ),
      body: IndexedStack(index: _tab, children: pages),
      floatingActionButton: _tab <= 1
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const NewReceiptScreen()),
              ),
              icon: const Icon(Icons.receipt_long),
              label: const Text('وصل جديد'),
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
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'الإعدادات',
          ),
        ],
      ),
    );
  }
}
