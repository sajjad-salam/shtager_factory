import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../telegram_backup.dart';
import '../ui.dart';
import 'customers_screen.dart';
import 'new_receipt_screen.dart';
import 'receipt_view_screen.dart';

class CustomerDetailScreen extends StatelessWidget {
  final String customerId;
  const CustomerDetailScreen({super.key, required this.customerId});

  @override
  Widget build(BuildContext context) {
    final store = AppStore.instance;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final c = store.customerById(customerId);
        if (c == null) return const Scaffold(body: SizedBox());
        final bal = store.balanceOf(c.id);
        final taken = store.takenBy(c.id);
        final receipts = store.receiptsOf(c.id);
        final payments = store.paymentsOf(c.id);
        final events = <(DateTime, Object)>[
          for (final r in receipts) (r.date, r),
          for (final p in payments) (p.date, p),
        ]..sort((a, b) => b.$1.compareTo(a.$1));

        return Scaffold(
          appBar: AppBar(
            title: Text(c.name),
            actions: [
              IconButton(
                tooltip: 'تعديل',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => showCustomerForm(context, existing: c),
              ),
              PopupMenuButton<String>(
                onSelected: (v) async {
                  if (v == 'delete') {
                    final ok = await confirm(context, 'حذف ${c.name}؟',
                        'راح تنحذف كل وصولاته ودفعاته. ما تكدر ترجعها إلا من نسخة التليجرام.');
                    if (ok) {
                      await store.deleteCustomer(c.id);
                      if (context.mounted) Navigator.pop(context);
                    }
                  }
                },
                itemBuilder: (_) => const [PopupMenuItem(value: 'delete', child: Text('حذف الخلفة'))],
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(bal >= 0 ? 'المبلغ اللي عليه' : 'المبلغ اللي إله',
                        style: TextStyle(color: Colors.grey.shade600)),
                    MoneyText(bal.abs() < 0.0001 ? 0 : bal, size: 28),
                    if (c.phone.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(children: [
                        Icon(Icons.chat_outlined, size: 16, color: Colors.grey.shade600),
                        const SizedBox(width: 6),
                        Text(c.phone, textDirection: TextDirection.ltr, style: TextStyle(color: Colors.grey.shade700)),
                      ]),
                    ],
                    if (c.notes.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(c.notes, style: TextStyle(color: Colors.grey.shade700)),
                    ],
                    const SizedBox(height: 16),
                    Row(children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => NewReceiptScreen(customerId: c.id))),
                          icon: const Icon(Icons.receipt_long),
                          label: const Text('وصل جديد'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _addPayment(context, c),
                          icon: const Icon(Icons.payments_outlined),
                          label: const Text('تسجيل دفعة'),
                        ),
                      ),
                    ]),
                  ]),
                ),
              ),
              if (taken.isNotEmpty) ...[
                const SectionTitle('الكميات المأخوذة'),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final e in taken.entries)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8EB)),
                      ),
                      child: RichText(
                        text: TextSpan(
                          style: const TextStyle(fontFamily: 'Plex', color: Colors.black87, fontSize: 14),
                          children: [
                            TextSpan(text: '${e.key}  '),
                            TextSpan(
                                text: '${fmtNum(e.value.$1)} ${e.value.$2}',
                                style: const TextStyle(fontWeight: FontWeight.w700, color: brand)),
                          ],
                        ),
                      ),
                    ),
                ]),
              ],
              SectionTitle('الحركات (${events.length})'),
              if (events.isEmpty)
                const EmptyState(icon: Icons.history, title: 'ما كو حركات بعد'),
              for (final e in events) ...[
                if (e.$2 is Receipt) _ReceiptRow(e.$2 as Receipt) else _PaymentRow(e.$2 as Payment),
                const SizedBox(height: 8),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _addPayment(BuildContext context, Customer c) async {
    final amount = TextEditingController();
    final notes = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text('دفعة من ${c.name}'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: amount,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'المبلغ', suffixText: 'د.ع'),
          ),
          const SizedBox(height: 10),
          TextField(controller: notes, decoration: const InputDecoration(labelText: 'ملاحظة (اختياري)')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('إلغاء')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
            onPressed: () => Navigator.pop(d, true),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    final v = parseNum(amount.text);
    if (ok != true || v <= 0) return;
    await AppStore.instance.addPayment(c.id, v, notes.text);
    if (context.mounted) toast(context, 'انسجلت دفعة ${fmtMoney(v)}');
    final err = await TelegramBackup.instance.backupNow(reason: 'دفعة ${fmtMoney(v)} من ${c.name}');
    if (err != null && context.mounted && AppStore.instance.settings.telegramReady) {
      toast(context, 'ما انرسلت النسخة للتليجرام: $err', error: true);
    }
  }
}

class _ReceiptRow extends StatelessWidget {
  final Receipt r;
  const _ReceiptRow(this.r);

  @override
  Widget build(BuildContext context) => Card(
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          onTap: () => Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => ReceiptViewScreen(receiptId: r.id))),
          leading: const CircleAvatar(
            backgroundColor: Color(0xFFFDECEA),
            foregroundColor: debtColor,
            child: Icon(Icons.receipt_long, size: 20),
          ),
          title: Text('وصل #${r.number}', style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(
            '${fmtDate(r.date)}  •  ${r.items.map((i) => '${i.productName} ${fmtNum(i.qty)}').join('، ')}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(fmtMoney(r.total), style: const TextStyle(fontWeight: FontWeight.w700)),
            if (r.paid > 0)
              Text('واصل ${fmtNum(r.paid)}', style: const TextStyle(fontSize: 11, color: okColor)),
          ]),
        ),
      );
}

class _PaymentRow extends StatelessWidget {
  final Payment p;
  const _PaymentRow(this.p);

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          leading: const CircleAvatar(
            backgroundColor: Color(0xFFE5F4EC),
            foregroundColor: okColor,
            child: Icon(Icons.payments_outlined, size: 20),
          ),
          title: const Text('دفعة', style: TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text([fmtDateTime(p.date), if (p.notes.isNotEmpty) p.notes].join('  •  ')),
          trailing: Text('- ${fmtMoney(p.amount)}',
              style: const TextStyle(fontWeight: FontWeight.w700, color: okColor)),
          onLongPress: () async {
            final ok = await confirm(context, 'حذف الدفعة؟', 'دفعة ${fmtMoney(p.amount)} بتاريخ ${fmtDate(p.date)}');
            if (ok) await AppStore.instance.deletePayment(p.id);
          },
        ),
      );
}
