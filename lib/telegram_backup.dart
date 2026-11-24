import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'models.dart';
import 'incoming_receipt_pdf.dart';
import 'receipt_pdf.dart';
import 'store.dart';

/// النسخ الاحتياطي على بوت التليجرام.
/// كل نسخة تنرسل كملف JSON وتتثبت (pin) بالمحادثة، فالاسترجاع يجيب آخر ملف مثبت.
class TelegramBackup {
  TelegramBackup._();
  static final TelegramBackup instance = TelegramBackup._();

  bool _busy = false;

  AppSettings get _s => AppStore.instance.settings;
  String get _base => 'https://api.telegram.org/bot${_s.botToken.trim()}';

  Future<Map<String, dynamic>> _call(
    String method, [
    Map<String, String>? params,
  ]) async {
    final res = await http
        .post(Uri.parse('$_base/$method'), body: params ?? const {})
        .timeout(const Duration(seconds: 25));
    final j = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    if (j['ok'] != true) {
      throw TelegramError(j['description']?.toString() ?? 'خطأ غير معروف');
    }
    return j;
  }

  Future<int> _sendDocument(
    Uint8List bytes,
    String filename,
    String caption,
  ) async {
    final req = http.MultipartRequest('POST', Uri.parse('$_base/sendDocument'))
      ..fields['chat_id'] = _s.chatId.trim()
      ..fields['caption'] = caption
      ..files.add(
        http.MultipartFile.fromBytes('document', bytes, filename: filename),
      );
    final res = await http.Response.fromStream(
      await req.send().timeout(const Duration(seconds: 60)),
    );
    final j = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    if (j['ok'] != true) {
      throw TelegramError(j['description']?.toString() ?? 'فشل الإرسال');
    }
    return (j['result']['message_id'] as num).toInt();
  }

  String _stamp(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}'
      '_${d.hour.toString().padLeft(2, '0')}${d.minute.toString().padLeft(2, '0')}';

  /// يرسل قاعدة البيانات كاملة. يرجع null إذا نجح، أو رسالة الخطأ.
  Future<String?> backupNow({
    String? reason,
    Receipt? receipt,
    IncomingReceipt? incomingReceipt,
  }) async {
    final store = AppStore.instance;
    if (!_s.telegramReady) {
      await store.setBackupState(
        pending: true,
        error: 'بوت التليجرام غير مضبوط',
      );
      return 'بوت التليجرام غير مضبوط من الإعدادات';
    }
    if (_busy) return null;
    _busy = true;
    try {
      if (receipt != null && _s.sendPdfToTelegram) {
        final c = store.customerById(receipt.customerId);
        await _sendDocument(
          await buildReceiptPdf(receipt),
          receiptFileName(receipt),
          '🧾 وصل #${receipt.number} — ${c?.name ?? ''}\n'
          'المبلغ: ${fmtMoney(receipt.total)} | الواصل: ${fmtMoney(receipt.paid)}\n'
          'الحساب الكلي: ${fmtMoney(store.balanceOf(receipt.customerId))}',
        );
      }
      if (incomingReceipt != null && _s.sendPdfToTelegram) {
        final center = store.centerName(incomingReceipt.factoryId);
        await _sendDocument(
          await buildIncomingReceiptPdf(incomingReceipt),
          incomingReceiptFileName(incomingReceipt),
          'وصل شراء #${incomingReceipt.number} — $center\n'
          '${incomingReceipt.category.label} | ${fmtMoney(incomingReceipt.amount)}',
        );
      }
      final now = DateTime.now();
      final data = Uint8List.fromList(
        utf8.encode(
          const JsonEncoder.withIndent(' ').convert(store.exportDb()),
        ),
      );
      final msgId = await _sendDocument(
        data,
        'shtager_backup_${_stamp(now)}.json',
        '💾 نسخة احتياطية${reason != null ? ' — $reason' : ''}\n'
            'الخلفات: ${store.customers.length} | وصولات البيع: ${store.receipts.length}\n'
            'وصولات الشراء: ${store.incomingReceipts.length} | المعامل: ${store.factories.length}\n'
            'المبيعات: ${fmtMoney(store.totalSales)} | المشتريات: ${fmtMoney(store.totalPurchases)}',
      );
      try {
        await _call('pinChatMessage', {
          'chat_id': _s.chatId.trim(),
          'message_id': '$msgId',
          'disable_notification': 'true',
        });
      } catch (_) {
        // التثبيت مو ضروري للنسخ، فقط يسهل الاسترجاع.
      }
      await store.setBackupState(pending: false, at: now);
      return null;
    } catch (e) {
      final msg = e is TelegramError
          ? e.message
          : 'تعذر الاتصال بالتليجرام (تأكد من الإنترنت)';
      await store.setBackupState(pending: true, error: msg);
      return msg;
    } finally {
      _busy = false;
    }
  }

  /// يرسل نسخة إذا توجد تغييرات معلقة (مثلاً عند فتح التطبيق).
  Future<void> flushPending() async {
    if (AppStore.instance.backupPending && _s.telegramReady) {
      await backupNow(reason: 'تغييرات معلقة');
    }
  }

  /// يجيب معرف المحادثة من آخر رسالة أرسلتها للبوت.
  Future<String> detectChatId() async {
    final j = await _call('getUpdates');
    final list = (j['result'] as List).reversed;
    for (final u in list) {
      final m = u['message'] ?? u['my_chat_member'] ?? u['channel_post'];
      final chat = m?['chat'];
      if (chat != null) return '${chat['id']}';
    }
    throw TelegramError(
      'ما لكيت رسائل. افتح البوت بالتليجرام واضغط Start أو أرسل له أي رسالة، وبعدين جرب مرة ثانية.',
    );
  }

  Future<String> testConnection() async {
    final j = await _call('getMe');
    return '@${j['result']['username']}';
  }

  /// يجيب آخر نسخة مثبتة بالمحادثة ويرجعها كـ JSON (بدون ما يطبقها).
  Future<Map<String, dynamic>> fetchLatestBackup() async {
    final chat = await _call('getChat', {'chat_id': _s.chatId.trim()});
    final pinned = chat['result']['pinned_message'];
    final doc = pinned?['document'];
    if (doc == null) {
      throw TelegramError(
        'ما لكيت نسخة مثبتة بالمحادثة. إذا عندك ملف النسخة، ثبته (Pin) بالمحادثة وجرب مرة ثانية.',
      );
    }
    final f = await _call('getFile', {'file_id': doc['file_id'] as String});
    final path = f['result']['file_path'] as String;
    final res = await http
        .get(
          Uri.parse(
            'https://api.telegram.org/file/bot${_s.botToken.trim()}/$path',
          ),
        )
        .timeout(const Duration(seconds: 60));
    final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    if (data['app'] != 'shtager') {
      throw TelegramError('الملف المثبت مو نسخة احتياطية من هذا التطبيق');
    }
    return data;
  }
}

class TelegramError implements Exception {
  final String message;
  TelegramError(this.message);
  @override
  String toString() => message;
}
