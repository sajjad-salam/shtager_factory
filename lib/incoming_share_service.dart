import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'incoming_receipt_pdf.dart';
import 'models.dart';
import 'store.dart';

const _native = MethodChannel('shtager/native');

String incomingReceiptMessage(IncomingReceipt receipt) {
  final store = AppStore.instance;
  final center = store.centerName(receipt.factoryId);
  return 'وصل شراء رقم ${receipt.number} - ${store.settings.shopName}\n'
      'الجهة: $center\n'
      '${receipt.supplier.isNotEmpty ? 'من: ${receipt.supplier}\n' : ''}'
      'النوع: ${receipt.category.label}\n'
      'المبلغ: ${fmtMoney(receipt.amount)}';
}

Future<String> _writeTemp(IncomingReceipt receipt, Uint8List bytes) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/receipts/${incomingReceiptFileName(receipt)}');
  await file.parent.create(recursive: true);
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}

Future<void> shareIncomingToWhatsApp(IncomingReceipt receipt) async {
  final bytes = await buildIncomingReceiptPdf(receipt);
  if (!kIsWeb && Platform.isAndroid) {
    final path = await _writeTemp(receipt, bytes);
    final opened = await _native.invokeMethod<bool>('shareToWhatsApp', {
      'path': path,
      'text': incomingReceiptMessage(receipt),
      'phone': '',
    });
    if (opened == true) return;
  }
  await shareIncomingGeneric(receipt, bytes: bytes);
}

Future<void> shareIncomingGeneric(
  IncomingReceipt receipt, {
  Uint8List? bytes,
}) async {
  bytes ??= await buildIncomingReceiptPdf(receipt);
  final name = incomingReceiptFileName(receipt);
  final file = kIsWeb
      ? XFile.fromData(bytes, name: name, mimeType: 'application/pdf')
      : XFile(
          await _writeTemp(receipt, bytes),
          name: name,
          mimeType: 'application/pdf',
        );
  await SharePlus.instance.share(
    ShareParams(
      files: [file],
      text: incomingReceiptMessage(receipt),
      fileNameOverrides: [name],
    ),
  );
}

Future<String> saveIncomingToDevice(IncomingReceipt receipt) async {
  final bytes = await buildIncomingReceiptPdf(receipt);
  final name = incomingReceiptFileName(receipt);
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
    final path = await _writeTemp(receipt, bytes);
    return await _native.invokeMethod<String>('saveToDownloads', {
          'path': path,
          'name': name,
        }) ??
        path;
  }
  final dir = await getApplicationDocumentsDirectory();
  final file = File('${dir.path}/Shtager/$name');
  await file.parent.create(recursive: true);
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}
