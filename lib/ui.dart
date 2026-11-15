import 'package:flutter/material.dart';

import 'store.dart';
import 'telegram_backup.dart';

const brand = Color(0xFF1F4E5F);
const debtColor = Color(0xFFB3261E);
const okColor = Color(0xFF1E7B4B);

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: brand, primary: brand);
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    fontFamily: 'Plex',
    scaffoldBackgroundColor: const Color(0xFFF4F6F7),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFFF4F6F7),
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      titleTextStyle: TextStyle(fontFamily: 'Plex', fontSize: 20, fontWeight: FontWeight.w700, color: brand),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFE2E8EB)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFD5DDE1)),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontFamily: 'Plex', fontSize: 15, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontFamily: 'Plex', fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
  );
}

void toast(BuildContext context, String msg, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? debtColor : null,
      behavior: SnackBarBehavior.floating,
    ));
}

Future<bool> confirm(BuildContext context, String title, String body, {String ok = 'حذف'}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: debtColor, minimumSize: const Size(0, 40)),
          onPressed: () => Navigator.pop(c, true),
          child: Text(ok),
        ),
      ],
    ),
  );
  return r == true;
}

/// يبين حالة النسخ الاحتياطي على التليجرام، وبالضغط عليه ينسخ هسه.
class BackupIndicator extends StatelessWidget {
  const BackupIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppStore.instance;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final ready = store.settings.telegramReady;
        final pending = store.backupPending;
        final icon = !ready
            ? Icons.cloud_off_outlined
            : pending
                ? Icons.cloud_upload_outlined
                : Icons.cloud_done_outlined;
        final color = !ready
            ? Colors.grey
            : pending
                ? Colors.orange.shade800
                : okColor;
        final tip = !ready
            ? 'النسخ على التليجرام غير مضبوط'
            : pending
                ? 'توجد تغييرات لم تُرسل — اضغط للإرسال'
                : 'آخر نسخة: ${store.lastBackupAt != null ? fmtDateTime(store.lastBackupAt!) : '—'}';
        return IconButton(
          tooltip: tip,
          icon: Icon(icon, color: color),
          onPressed: () async {
            if (!ready) {
              toast(context, 'اضبط بوت التليجرام من صفحة الإعدادات');
              return;
            }
            toast(context, 'جاري الإرسال للتليجرام...');
            final err = await TelegramBackup.instance.backupNow(reason: 'نسخ يدوي');
            if (context.mounted) {
              toast(context, err ?? 'تم حفظ نسخة على التليجرام ✓', error: err != null);
            }
          },
        );
      },
    );
  }
}

class MoneyText extends StatelessWidget {
  final double value;
  final double size;
  final bool colored;
  const MoneyText(this.value, {super.key, this.size = 15, this.colored = true});

  @override
  Widget build(BuildContext context) {
    final color = !colored
        ? null
        : value > 0.0001
            ? debtColor
            : value < -0.0001
                ? okColor
                : Colors.grey.shade700;
    return Text(fmtMoney(value),
        style: TextStyle(fontSize: size, fontWeight: FontWeight.w700, color: color));
  }
}

class SectionTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const SectionTitle(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
        child: Row(children: [
          Expanded(
            child: Text(text,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.grey.shade700)),
          ),
          ?trailing,
        ]),
      );
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;
  const EmptyState({super.key, required this.icon, required this.title, this.subtitle, this.action});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(subtitle!, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600)),
            ],
            if (action != null) ...[const SizedBox(height: 16), action!],
          ]),
        ),
      );
}
