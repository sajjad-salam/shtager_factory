import 'package:flutter/material.dart';

import '../models.dart';
import '../share_service.dart';
import '../store.dart';
import '../telegram_backup.dart';
import '../ui.dart';

class ReceiptViewScreen extends StatefulWidget {
  final String receiptId;
  final bool justCreated;
  const ReceiptViewScreen({super.key, required this.receiptId, this.justCreated = false});

  @override
  State<ReceiptViewScreen> createState() => _ReceiptViewScreenState();
}

class _ReceiptViewScreenState extends State<ReceiptViewScreen> {
  bool _busy = false;

  Receipt? get _r {
    for (final r in AppStore.instance.receipts) {
      if (r.id == widget.receiptId) return r;
    }
    return null;
  }

  Future<void> _run(Future<void> Function() f) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await f();
    } catch (e) {
      if (mounted) toast(context, 'صار خطأ: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = AppStore.instance;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final r = _r;
        if (r == null) return const Scaffold(body: SizedBox());
        final c = store.customerById(r.customerId);
        final hasPhone = (c?.phone ?? '').trim().isNotEmpty;

        return Scaffold(
          appBar: AppBar(
            title: Text('وصل #${r.number}'),
            actions: [
              const BackupIndicator(),
              PopupMenuButton<String>(
                onSelected: (v) async {
                  if (v == 'delete') {
                    final ok = await confirm(context, 'حذف الوصل #${r.number}؟',
                        'راح ينشال مبلغه (${fmtMoney(r.total)}) من حساب ${c?.name ?? ''}.');
                    if (ok) {
                      await store.deleteReceipt(r.id);
                      TelegramBackup.instance.backupNow(reason: 'حذف وصل #${r.number}');
                      if (context.mounted) Navigator.pop(context);
                    }
                  }
                },
                itemBuilder: (_) => const [PopupMenuItem(value: 'delete', child: Text('حذف الوصل'))],
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              if (widget.justCreated)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5F4EC),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(children: [
                    Icon(Icons.check_circle, color: okColor),
                    SizedBox(width: 8),
                    Expanded(child: Text('انحفظ الوصل. هسه تكدر ترسله للخلفة.')),
                  ]),
                ),
              ReceiptPreview(receipt: r),
              const SizedBox(height: 16),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF1FA855)),
                onPressed: _busy
                    ? null
                    : () => _run(() async {
                          final res = await shareReceiptToWhatsApp(r);
                          if (mounted && res == WhatsAppResult.openedShareSheet && hasPhone) {
                            toast(this.context, 'ما لكيت واتساب، اختار التطبيق من القائمة');
                          }
                        }),
                icon: const Icon(Icons.send),
                label: Text(hasPhone ? 'إرسال لواتساب ${c!.name}' : 'مشاركة بالواتساب'),
              ),
              if (hasPhone) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _busy ? null : () => _run(() => shareReceiptToWhatsApp(r, forceChooser: true)),
                  icon: const Icon(Icons.people_outline),
                  label: const Text('إرسال لشخص ثاني بالواتساب'),
                ),
              ],
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : () => _run(() => shareReceiptGeneric(r)),
                    icon: const Icon(Icons.share_outlined),
                    label: const Text('مشاركة'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () => _run(() async {
                              final where = await saveReceiptToDevice(r);
                              if (mounted) toast(this.context, 'انحفظ الملف: $where');
                            }),
                    icon: const Icon(Icons.download_outlined),
                    label: const Text('حفظ PDF'),
                  ),
                ),
              ]),
              if (_busy) const Padding(padding: EdgeInsets.only(top: 12), child: LinearProgressIndicator()),
            ],
          ),
        );
      },
    );
  }
}

/// معاينة الوصل داخل التطبيق (نفس محتوى ملف الـ PDF).
class ReceiptPreview extends StatelessWidget {
  final Receipt receipt;
  const ReceiptPreview({super.key, required this.receipt});

  @override
  Widget build(BuildContext context) {
    final store = AppStore.instance;
    final s = store.settings;
    final r = receipt;
    final c = store.customerById(r.customerId);
    final grey = TextStyle(color: Colors.grey.shade600, fontSize: 12);

    Widget line(String a, String b, {bool strong = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(children: [
            Expanded(child: Text(a, style: strong ? const TextStyle(fontWeight: FontWeight.w700) : grey)),
            Text(b, style: TextStyle(fontWeight: FontWeight.w700, fontSize: strong ? 16 : 13)),
          ]),
        );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.shopName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: brand)),
                if (s.shopPhone.isNotEmpty) Text(s.shopPhone, style: grey),
              ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: brand.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
              child: Text('#${r.number}', style: const TextStyle(fontWeight: FontWeight.w700, color: brand, fontSize: 16)),
            ),
          ]),
          const Divider(height: 24, thickness: 2, color: brand),
          Row(children: [
            Expanded(
              child: Text.rich(TextSpan(children: [
                TextSpan(text: 'السيد: ', style: grey),
                TextSpan(text: c?.name ?? '—', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              ])),
            ),
            Text(fmtDateTime(r.date), style: grey),
          ]),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFD5DDE1)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: const BoxDecoration(
                  color: brand,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(7)),
                ),
                child: const Row(children: [
                  Expanded(flex: 3, child: Text('المادة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
                  Expanded(flex: 2, child: Text('العدد', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
                  Expanded(flex: 2, child: Text('السعر', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
                  Expanded(flex: 3, child: Text('المبلغ', textAlign: TextAlign.end, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
                ]),
              ),
              for (var i = 0; i < r.items.length; i++)
                Container(
                  color: i.isOdd ? const Color(0xFFF6F8F9) : null,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Row(children: [
                    Expanded(flex: 3, child: Text(r.items[i].productName, style: const TextStyle(fontWeight: FontWeight.w600))),
                    Expanded(flex: 2, child: Text('${fmtNum(r.items[i].qty)} ${r.items[i].unit}', textAlign: TextAlign.center)),
                    Expanded(flex: 2, child: Text(fmtNum(r.items[i].unitPrice), textAlign: TextAlign.center)),
                    Expanded(flex: 3, child: Text(fmtNum(r.items[i].total), textAlign: TextAlign.end, style: const TextStyle(fontWeight: FontWeight.w700))),
                  ]),
                ),
            ]),
          ),
          const SizedBox(height: 12),
          line('مجموع الوصل', fmtMoney(r.total), strong: true),
          line('الواصل', fmtMoney(r.paid)),
          line('الباقي من الوصل', fmtMoney(r.remaining)),
          const Divider(height: 16),
          line('الحساب الكلي الحالي للخلفة', fmtMoney(store.balanceOf(r.customerId))),
          if (r.notes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('ملاحظات: ${r.notes}', style: grey),
          ],
        ]),
      ),
    );
  }
}
