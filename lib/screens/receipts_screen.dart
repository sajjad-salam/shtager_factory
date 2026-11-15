import 'package:flutter/material.dart';

import '../store.dart';
import '../ui.dart';
import 'receipt_view_screen.dart';

class ReceiptsScreen extends StatefulWidget {
  const ReceiptsScreen({super.key});

  @override
  State<ReceiptsScreen> createState() => _ReceiptsScreenState();
}

class _ReceiptsScreenState extends State<ReceiptsScreen> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final store = AppStore.instance;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final list = store.receipts.where((r) {
          if (_q.isEmpty) return true;
          final name = store.customerById(r.customerId)?.name ?? '';
          return name.contains(_q) || '${r.number}' == _q;
        }).toList()
          ..sort((a, b) => b.date.compareTo(a.date));

        final now = DateTime.now();
        final todayTotal = store.receipts
            .where((r) => r.date.year == now.year && r.date.month == now.month && r.date.day == now.day)
            .fold<double>(0, (s, r) => s + r.total);

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(children: [
                  const Icon(Icons.today, color: brand),
                  const SizedBox(width: 10),
                  const Expanded(child: Text('مبيعات اليوم')),
                  Text(fmtMoney(todayTotal), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                ]),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              decoration: const InputDecoration(
                hintText: 'بحث باسم الخلفة أو رقم الوصل',
                prefixIcon: Icon(Icons.search),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _q = v.trim()),
            ),
            const SizedBox(height: 12),
            if (store.receipts.isEmpty)
              const EmptyState(
                icon: Icons.receipt_long_outlined,
                title: 'ما كو وصولات بعد',
                subtitle: 'اضغط "وصل جديد" حتى تطلع أول وصل',
              ),
            for (final r in list) ...[
              Card(
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  onTap: () => Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => ReceiptViewScreen(receiptId: r.id))),
                  leading: CircleAvatar(
                    backgroundColor: brand.withValues(alpha: 0.1),
                    foregroundColor: brand,
                    child: Text('${r.number}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                  ),
                  title: Text(store.customerById(r.customerId)?.name ?? '—',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(
                    '${fmtDate(r.date)}  •  ${r.items.map((i) => '${i.productName} ${fmtNum(i.qty)}').join('، ')}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Text(fmtMoney(r.total), style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ],
        );
      },
    );
  }
}
