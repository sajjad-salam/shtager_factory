import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../store.dart';
import '../telegram_backup.dart';
import '../ui.dart';

const _devPhone = '07748820206';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final store = AppStore.instance;
  late final _shopName = TextEditingController(text: store.settings.shopName);
  late final _shopPhone = TextEditingController(text: store.settings.shopPhone);
  late final _shopAddress = TextEditingController(
    text: store.settings.shopAddress,
  );
  late final _token = TextEditingController(text: store.settings.botToken);
  late final _chatId = TextEditingController(text: store.settings.chatId);
  bool _busy = false;
  bool _showToken = false;

  Future<void> _saveAll() async {
    final s = store.settings;
    s.shopName = _shopName.text.trim().isEmpty
        ? 'معمل الشتايكر'
        : _shopName.text.trim();
    s.shopPhone = _shopPhone.text.trim();
    s.shopAddress = _shopAddress.text.trim();
    s.botToken = _token.text.trim();
    s.chatId = _chatId.text.trim();
    await store.saveSettings();
  }

  Future<void> _task(Future<String> Function() f) async {
    setState(() => _busy = true);
    try {
      await _saveAll();
      final msg = await f();
      if (mounted) toast(context, msg);
    } catch (e) {
      if (mounted) toast(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
        children: [
          const SectionTitle('معلومات المعمل (تطلع بالوصل)'),
          TextField(
            controller: _shopName,
            decoration: const InputDecoration(labelText: 'اسم المعمل'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _shopPhone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'رقم الهاتف'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _shopAddress,
            decoration: const InputDecoration(labelText: 'العنوان'),
          ),
          const SizedBox(height: 10),
          FilledButton.tonal(
            onPressed: () async {
              await _saveAll();
              if (context.mounted) toast(context, 'انحفظت المعلومات ✓');
            },
            child: const Text('حفظ المعلومات'),
          ),

          const SectionTitle('النسخ الاحتياطي على التليجرام'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'طريقة الضبط:',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '١. بالتليجرام افتح @BotFather وأرسل /newbot وسوي بوت جديد.\n'
                    '٢. انسخ التوكن (Token) اللي ينطيك ياه والصقه هنا.\n'
                    '٣. افتح البوت مالك واضغط Start (أو أرسل له أي رسالة).\n'
                    '٤. اضغط "جلب Chat ID" وبعدين "نسخ الآن".\n'
                    'كل وصل بيع أو شراء وكل دفعة راح تنرسل نسخة منها للبوت وتتثبت بالمحادثة.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade800,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _token,
            obscureText: !_showToken,
            textDirection: TextDirection.ltr,
            decoration: InputDecoration(
              labelText: 'Bot Token',
              hintText: '123456:ABC-DEF...',
              suffixIcon: IconButton(
                icon: Icon(
                  _showToken ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: () => setState(() => _showToken = !_showToken),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _chatId,
                  textDirection: TextDirection.ltr,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Chat ID'),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: _busy
                    ? null
                    : () => _task(() async {
                        final id = await TelegramBackup.instance.detectChatId();
                        _chatId.text = id;
                        await _saveAll();
                        return 'تم جلب Chat ID: $id';
                      }),
                child: const Text('جلب Chat ID'),
              ),
            ],
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('إرسال ملفات PDF للوصولات للبوت أيضاً'),
            value: store.settings.sendPdfToTelegram,
            onChanged: (v) async {
              store.settings.sendPdfToTelegram = v;
              await store.saveSettings();
            },
          ),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy
                      ? null
                      : () => _task(
                          () async =>
                              'متصل بالبوت ${await TelegramBackup.instance.testConnection()} ✓',
                        ),
                  icon: const Icon(Icons.wifi_tethering),
                  label: const Text('فحص الاتصال'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _busy
                      ? null
                      : () => _task(() async {
                          final err = await TelegramBackup.instance.backupNow(
                            reason: 'نسخ يدوي',
                          );
                          if (err != null) throw err;
                          return 'تم حفظ نسخة على التليجرام ✓';
                        }),
                  icon: const Icon(Icons.cloud_upload),
                  label: const Text('نسخ الآن'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            store.lastBackupAt == null
                ? 'ما انسوت نسخة بعد'
                : 'آخر نسخة: ${fmtDateTime(store.lastBackupAt!)}${store.backupPending ? '  (توجد تغييرات بعدها لم تُرسل)' : ''}',
            style: TextStyle(
              fontSize: 12,
              color: store.backupPending
                  ? Colors.orange.shade800
                  : Colors.grey.shade600,
            ),
          ),
          if (store.lastBackupError != null)
            Text(
              'آخر خطأ: ${store.lastBackupError}',
              style: const TextStyle(fontSize: 12, color: debtColor),
            ),

          const SectionTitle('استرجاع البيانات'),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: debtColor),
            onPressed: _busy ? null : _restore,
            icon: const Icon(Icons.restore),
            label: const Text('استرجاع آخر نسخة من التليجرام'),
          ),
          const SizedBox(height: 6),
          Text(
            'يستخدم إذا ضاع الجهاز أو انمسح التطبيق: ضيف التوكن و Chat ID نفسهم واضغط استرجاع.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          if (_busy)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: LinearProgressIndicator(),
            ),

          const SectionTitle('معلومات مطور البرنامج'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      'assets/images/logo.png',
                      width: 56,
                      height: 56,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'اسم المبرمج: مهندس سجاد سلام',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        InkWell(
                          onTap: () async {
                            await Clipboard.setData(
                              const ClipboardData(text: _devPhone),
                            );
                            if (context.mounted) {
                              toast(context, 'تم نسخ الرقم ✓');
                            }
                          },
                          child: const Row(
                            children: [
                              Text('رقم الهاتف للتواصل: '),
                              Text(
                                _devPhone,
                                textDirection: TextDirection.ltr,
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                              SizedBox(width: 6),
                              Icon(Icons.copy, size: 16),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _restore() async {
    setState(() => _busy = true);
    try {
      await _saveAll();
      final data = await TelegramBackup.instance.fetchLatestBackup();
      setState(() => _busy = false);
      if (!mounted) return;
      final n = (data['customers'] as List?)?.length ?? 0;
      final m = (data['receipts'] as List?)?.length ?? 0;
      final incoming = (data['incomingReceipts'] as List?)?.length ?? 0;
      final at = DateTime.tryParse(data['exportedAt'] as String? ?? '');
      final ok = await confirm(
        context,
        'استرجاع النسخة؟',
        'النسخة بتاريخ ${at != null ? fmtDateTime(at) : '—'}\nفيها $n خلفة و$m وصل بيع و$incoming وصل شراء.\n'
            'البيانات الحالية على الجهاز راح تتبدل بيها.',
        ok: 'استرجاع',
      );
      if (!ok) return;
      store.importDb(data);
      _shopName.text = store.settings.shopName;
      _shopPhone.text = store.settings.shopPhone;
      _shopAddress.text = store.settings.shopAddress;
      await store.setBackupState(pending: false, at: at);
      if (mounted) toast(context, 'تم الاسترجاع ✓');
    } catch (e) {
      if (mounted) toast(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
