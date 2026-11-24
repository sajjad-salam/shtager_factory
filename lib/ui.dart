import 'package:flutter/material.dart';

import 'store.dart';
import 'telegram_backup.dart';

const brand = Color(0xFF1F4E5F);
const debtColor = Color(0xFFB3261E);
const okColor = Color(0xFF1E7B4B);
const appBackground = Color(0xFFFFFFFF);
const appSurface = Color(0xFFF4F5F5);
const appBorder = Color(0xFFE3E7E8);
const appInk = Color(0xFF172126);
const appMuted = Color(0xFF66757C);

class AppSpace {
  static const page = 20.0;
  static const gap = 12.0;
  static const section = 28.0;
}

class AppRadius {
  static const card = 20.0;
  static const tile = 24.0;
  static const button = 16.0;
  static const pill = 999.0;
}

/// Tracks the numeric field that currently owns the keyboard so the app can
/// show one shared Iraqi-dinar shortcut directly above the system keyboard.
class NumericKeyboardController extends ChangeNotifier {
  NumericKeyboardController._();

  static final instance = NumericKeyboardController._();
  TextEditingController? _activeController;

  bool get isActive => _activeController != null;

  void activate(TextEditingController controller) {
    if (identical(_activeController, controller)) return;
    _activeController = controller;
    notifyListeners();
  }

  void deactivate(TextEditingController controller) {
    if (!identical(_activeController, controller)) return;
    _activeController = null;
    notifyListeners();
  }

  void appendTripleZero() {
    final controller = _activeController;
    if (controller == null) return;
    appendTripleZeroTo(controller);
  }
}

/// Inserts 000 at the cursor (or replaces the selected range) and keeps the
/// caret immediately after the inserted digits.
void appendTripleZeroTo(TextEditingController controller) {
  final value = controller.value;
  final selection = value.selection;
  final start = selection.isValid ? selection.start : value.text.length;
  final end = selection.isValid ? selection.end : value.text.length;
  final updated = value.text.replaceRange(start, end, '000');
  controller.value = value.copyWith(
    text: updated,
    selection: TextSelection.collapsed(offset: start + 3),
    composing: TextRange.empty,
  );
}

/// Wrap every amount/quantity field with this target. It leaves the original
/// field untouched and only announces focus to the shared keyboard accessory.
class NumericKeyboardTarget extends StatelessWidget {
  const NumericKeyboardTarget({
    super.key,
    required this.controller,
    required this.child,
  });

  final TextEditingController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) => Focus(
    onFocusChange: (focused) {
      if (focused) {
        NumericKeyboardController.instance.activate(controller);
      } else {
        NumericKeyboardController.instance.deactivate(controller);
      }
    },
    child: child,
  );
}

/// Global input accessory shown immediately above the native keyboard.
class NumericKeyboardAccessoryHost extends StatelessWidget {
  const NumericKeyboardAccessoryHost({super.key, required this.child});

  static const height = 52.0;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final controller = NumericKeyboardController.instance;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final media = MediaQuery.of(context);
        final keyboard = media.viewInsets.bottom;
        final visible = keyboard > 0 && controller.isActive;
        final effectiveInsets = visible
            ? media.viewInsets.copyWith(bottom: keyboard + height)
            : media.viewInsets;
        return Stack(
          fit: StackFit.expand,
          children: [
            MediaQuery(
              data: media.copyWith(viewInsets: effectiveInsets),
              child: child,
            ),
            if (visible)
              Positioned(
                left: 0,
                right: 0,
                bottom: keyboard,
                height: height,
                child: Material(
                  color: appSurface,
                  elevation: 8,
                  shadowColor: Colors.black26,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        Semantics(
                          button: true,
                          label: 'إضافة ثلاثة أصفار',
                          child: InkWell(
                            onTap: controller.appendTripleZero,
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              constraints: const BoxConstraints(
                                minWidth: 76,
                                minHeight: 44,
                              ),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: brand.withValues(alpha: .11),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                '+000',
                                textDirection: TextDirection.ltr,
                                style: TextStyle(
                                  color: brand,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'إضافة ثلاثة أصفار',
                            style: TextStyle(color: appMuted, fontSize: 12),
                          ),
                        ),
                        TextButton(
                          onPressed: () =>
                              FocusManager.instance.primaryFocus?.unfocus(),
                          child: const Text('تم'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Keeps a page's primary bottom action above both the native keyboard and the
/// optional +000 accessory. Use this in Scaffold.bottomNavigationBar.
class KeyboardSafeActionBar extends StatelessWidget {
  const KeyboardSafeActionBar({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 12),
    this.decoration,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Decoration? decoration;

  @override
  Widget build(BuildContext context) {
    final controller = NumericKeyboardController.instance;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final keyboard = MediaQuery.viewInsetsOf(context).bottom;
        return AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: EdgeInsets.only(bottom: keyboard),
          child: SafeArea(
            top: false,
            child: Container(
              padding: padding,
              decoration:
                  decoration ??
                  const BoxDecoration(
                    color: appBackground,
                    border: Border(top: BorderSide(color: appBorder)),
                  ),
              child: child,
            ),
          ),
        );
      },
    );
  }
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: brand,
    primary: brand,
    surface: appBackground,
  );
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    fontFamily: 'Plex',
    scaffoldBackgroundColor: appBackground,
    appBarTheme: const AppBarTheme(
      backgroundColor: appBackground,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
        fontFamily: 'Plex',
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: appInk,
      ),
    ),
    cardTheme: CardThemeData(
      color: appSurface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.button),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.button),
        borderSide: const BorderSide(color: appBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.button),
        borderSide: const BorderSide(color: brand, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.button),
        ),
        textStyle: const TextStyle(
          fontFamily: 'Plex',
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.button),
        ),
        textStyle: const TextStyle(
          fontFamily: 'Plex',
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: appBackground,
      surfaceTintColor: Colors.transparent,
      indicatorColor: brand.withValues(alpha: 0.12),
      height: 68,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontFamily: 'Plex',
          fontSize: 12,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w400,
          color: states.contains(WidgetState.selected) ? brand : appMuted,
        ),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: appBackground,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
  );
}

void toast(BuildContext context, String msg, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? debtColor : null,
        behavior: SnackBarBehavior.floating,
      ),
    );
}

Future<bool> confirm(
  BuildContext context,
  String title,
  String body, {
  String ok = 'حذف',
}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c, false),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: debtColor,
            minimumSize: const Size(0, 40),
          ),
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
            final err = await TelegramBackup.instance.backupNow(
              reason: 'نسخ يدوي',
            );
            if (context.mounted) {
              toast(
                context,
                err ?? 'تم حفظ نسخة على التليجرام ✓',
                error: err != null,
              );
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
    return Text(
      fmtMoney(value),
      style: TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w700,
        color: color,
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const SectionTitle(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
    child: Row(
      children: [
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade700,
            ),
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ),
    ),
  );
}
