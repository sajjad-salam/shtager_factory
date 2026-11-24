import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'models.dart';
import 'receipt_pdf.dart';
import 'store.dart';

const _native = MethodChannel('shtager/native');

/// يحول رقم عراقي مثل 07701234567 إلى 9647701234567 (صيغة الواتساب الدولية).
String normalizeWhatsApp(String phone) {
  const ar = '٠١٢٣٤٥٦٧٨٩';
  var p = phone;
  for (var i = 0; i < 10; i++) {
    p = p.replaceAll(ar[i], '$i');
  }
  p = p.replaceAll(RegExp(r'[^0-9]'), '');
  if (p.startsWith('00')) p = p.substring(2);
  if (p.startsWith('0')) p = '964${p.substring(1)}';
  if (p.length == 10 && p.startsWith('7')) p = '964$p';
  return p;
}

String receiptMessage(Receipt r) {
  final s = AppStore.instance.settings;
  final c = AppStore.instance.customerById(r.customerId);
  return 'وصل رقم ${r.number} - ${s.shopName}\n'
      'السيد: ${c?.name ?? ''}\n'
      'المبلغ: ${fmtMoney(r.total)}\n'
      'الحساب الكلي: ${fmtMoney(AppStore.instance.balanceOf(r.customerId))}';
}

/// يكتب ملف الوصل بمجلد مؤقت حتى نقدر نشاركه.
Future<String> _writeTemp(Receipt r, Uint8List bytes) async {
  final dir = await getTemporaryDirectory();
  final f = File('${dir.path}/receipts/${receiptFileName(r)}');
  await f.parent.create(recursive: true);
  await f.writeAsBytes(bytes, flush: true);
  return f.path;
}

enum WhatsAppResult { sentDirect, openedShareSheet }

/// يرسل الوصل للواتساب. إذا الخلفة عنده رقم، يفتح محادثته مباشرة
/// ومعها ملف الـ PDF. وإلا يفتح قائمة المشاركة حتى تختار الشخص بنفسك.
Future<WhatsAppResult> shareReceiptToWhatsApp(
  Receipt r, {
  bool forceChooser = false,
}) async {
  final bytes = await buildReceiptPdf(r);
  final text = receiptMessage(r);
  final phone = normalizeWhatsApp(
    AppStore.instance.customerById(r.customerId)?.phone ?? '',
  );

  if (!kIsWeb && Platform.isAndroid) {
    final path = await _writeTemp(r, bytes);
    final ok = await _native.invokeMethod<bool>('shareToWhatsApp', {
      'path': path,
      'text': text,
      'phone': forceChooser ? '' : phone,
    });
    if (ok == true) {
      return phone.isNotEmpty && !forceChooser
          ? WhatsAppResult.sentDirect
          : WhatsAppResult.openedShareSheet;
    }
  }
  await shareReceiptGeneric(r, bytes: bytes);
  return WhatsAppResult.openedShareSheet;
}

/// مشاركة عامة (أي تطبيق: واتساب، تليجرام، بلوتوث...)
Future<void> shareReceiptGeneric(Receipt r, {Uint8List? bytes}) async {
  bytes ??= await buildReceiptPdf(r);
  final name = receiptFileName(r);
  final XFile file;
  if (kIsWeb) {
    file = XFile.fromData(bytes, name: name, mimeType: 'application/pdf');
  } else {
    file = XFile(
      await _writeTemp(r, bytes),
      name: name,
      mimeType: 'application/pdf',
    );
  }
  await SharePlus.instance.share(
    ShareParams(
      files: [file],
      text: receiptMessage(r),
      fileNameOverrides: [name],
    ),
  );
}

/// يحفظ الوصل بمجلد التنزيلات (Download/Shtager) ويرجع مكان الحفظ.
Future<String> saveReceiptToDevice(Receipt r) async {
  final bytes = await buildReceiptPdf(r);
  final name = receiptFileName(r);
  if (kIsWeb) {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(bytes, name: name, mimeType: 'application/pdf')],
        fileNameOverrides: [name],
        downloadFallbackEnabled: true,
      ),
    );
    return name;
  }
  if (Platform.isAndroid) {
    final path = await _writeTemp(r, bytes);
    final saved = await _native.invokeMethod<String>('saveToDownloads', {
      'path': path,
      'name': name,
    });
    return saved ?? path;
  }
  final dir = await getApplicationDocumentsDirectory();
  final f = File('${dir.path}/Shtager/$name');
  await f.parent.create(recursive: true);
  await f.writeAsBytes(bytes, flush: true);
  return f.path;
}
