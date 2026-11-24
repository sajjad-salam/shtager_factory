import 'package:flutter/material.dart';

import '../incoming_share_service.dart';
import '../models.dart';
import '../store.dart';
import '../telegram_backup.dart';
import '../ui.dart';

class IncomingReceiptViewScreen extends StatefulWidget {
  const IncomingReceiptViewScreen({
    super.key,
    required this.receiptId,
    this.justCreated = false,
  });

  final String receiptId;
  final bool justCreated;

  @override
  State<IncomingReceiptViewScreen> createState() =>
      _IncomingReceiptViewScreenState();
}

class _IncomingReceiptViewScreenState extends State<IncomingReceiptViewScreen> {
  final store = AppStore.instance;
  bool _busy = false;

  IncomingReceipt? get _receipt {
    for (final receipt in store.incomingReceipts) {
      if (receipt.id == widget.receiptId) return receipt;
    }
    return null;
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (error) {
      if (mounted) toast(context, '$error', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final receipt = _receipt;
    if (receipt == null) {
      return const Scaffold(body: Center(child: Text('الوصل غير موجود')));
    }
    final center = store.centerName(receipt.factoryId);
    return Scaffold(
      appBar: AppBar(
        title: Text('وصل شراء #${receipt.number}'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value != 'delete') return;
              final ok = await confirm(
                context,
                'حذف الوصل؟',
                'راح ينحذف هذا الوصل من المشتريات.',
              );
              if (!ok) return;
              await store.deleteIncomingReceipt(receipt.id);
              TelegramBackup.instance.backupNow(
                reason: 'حذف وصل شراء #${receipt.number}',
              );
              if (context.mounted) Navigator.pop(context);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'delete', child: Text('حذف الوصل')),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpace.page, 8, AppSpace.page, 30),
        children: [
          if (widget.justCreated)
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: okColor.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(AppRadius.button),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle_outline, color: okColor),
                  SizedBox(width: 10),
                  Text('انحفظ الوصل وصار ضمن نسخة التليجرام'),
                ],
              ),
            ),
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: appSurface,
              borderRadius: BorderRadius.circular(AppRadius.tile),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'وصل شراء',
                          style: TextStyle(fontSize: 12, color: appMuted),
                        ),
                        Text(
                          '#${receipt.number}',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: brand,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 13,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: brand.withValues(alpha: .1),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text(
                        receipt.category.label,
                        style: const TextStyle(
                          color: brand,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                _row('الجهة', center),
                _row('التاريخ', fmtDateTime(receipt.date)),
                _row('المبلغ', fmtMoney(receipt.amount), strong: true),
                if (receipt.notes.isNotEmpty) ...[
                  const Divider(height: 26),
                  const Text(
                    'الملاحظات',
                    style: TextStyle(fontSize: 12, color: appMuted),
                  ),
                  const SizedBox(height: 5),
                  Text(receipt.notes, style: const TextStyle(height: 1.6)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _busy
                ? null
                : () => _run(() => shareIncomingToWhatsApp(receipt)),
            icon: const Icon(Icons.chat_outlined),
            label: const Text('إرسال على واتساب'),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy
                      ? null
                      : () => _run(() => shareIncomingGeneric(receipt)),
                  icon: const Icon(Icons.ios_share_outlined),
                  label: const Text('مشاركة'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy
                      ? null
                      : () => _run(() async {
                          final path = await saveIncomingToDevice(receipt);
                          if (!mounted) return;
                          toast(this.context, 'انحفظ في $path');
                        }),
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('حفظ PDF'),
                ),
              ),
            ],
          ),
          if (_busy) ...[
            const SizedBox(height: 16),
            const LinearProgressIndicator(),
          ],
        ],
      ),
    );
  }

  Widget _row(String label, String value, {bool strong = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: appMuted)),
        Text(
          value,
          style: TextStyle(
            fontSize: strong ? 18 : 15,
            fontWeight: strong ? FontWeight.w700 : FontWeight.w600,
            color: strong ? debtColor : appInk,
          ),
        ),
      ],
    ),
  );
}
