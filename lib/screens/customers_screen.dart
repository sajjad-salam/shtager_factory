import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../ui.dart';
import 'customer_detail_screen.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final store = AppStore.instance;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final list = store.customers
            .where((c) => _q.isEmpty || c.name.contains(_q) || c.phone.contains(_q))
            .toList()
          ..sort((a, b) => store.balanceOf(b.id).compareTo(store.balanceOf(a.id)));

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
          children: [
            _SummaryCard(),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'بحث بالاسم أو الرقم',
                    prefixIcon: Icon(Icons.search),
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() => _q = v.trim()),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: () => showCustomerForm(context),
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('خلفة'),
              ),
            ]),
            const SizedBox(height: 12),
            if (store.customers.isEmpty)
              EmptyState(
                icon: Icons.people_alt_outlined,
                title: 'ما كو خلفات بعد',
                subtitle: 'ضيف أول خلفة حتى تبدي تطلع وصولات',
                action: FilledButton.icon(
                  onPressed: () => showCustomerForm(context),
                  icon: const Icon(Icons.person_add_alt_1),
                  label: const Text('إضافة خلفة'),
                ),
              )
            else if (list.isEmpty)
              const EmptyState(icon: Icons.search_off, title: 'ما كو نتائج')
            else
              for (final c in list) ...[
                CustomerTile(customer: c),
                const SizedBox(height: 8),
              ],
          ],
        );
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final store = AppStore.instance;
    final debtors = store.customers.where((c) => store.balanceOf(c.id) > 0.0001).length;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: brand,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('مجموع المبالغ على الخلفات', style: TextStyle(color: Colors.white70, fontSize: 13)),
        const SizedBox(height: 4),
        Text(fmtMoney(store.totalOutstanding),
            style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        Row(children: [
          _pill('${store.customers.length} خلفة'),
          const SizedBox(width: 8),
          _pill('$debtors عليهم مبالغ'),
          const SizedBox(width: 8),
          _pill('${store.receipts.length} وصل'),
        ]),
      ]),
    );
  }

  Widget _pill(String t) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(20)),
        child: Text(t, style: const TextStyle(color: Colors.white, fontSize: 12)),
      );
}

class CustomerTile extends StatelessWidget {
  final Customer customer;
  const CustomerTile({super.key, required this.customer});

  @override
  Widget build(BuildContext context) {
    final store = AppStore.instance;
    final bal = store.balanceOf(customer.id);
    final count = store.receipts.where((r) => r.customerId == customer.id).length;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => CustomerDetailScreen(customerId: customer.id)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(children: [
            CircleAvatar(
              backgroundColor: brand.withValues(alpha: 0.1),
              foregroundColor: brand,
              child: Text(customer.name.isEmpty ? '?' : customer.name.characters.first,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(customer.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                Text(
                  [if (customer.phone.isNotEmpty) customer.phone, '$count وصل'].join('  •  '),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              MoneyText(bal),
              Text(bal > 0.0001 ? 'عليه' : bal < -0.0001 ? 'له' : 'مسدد',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            ]),
          ]),
        ),
      ),
    );
  }
}

/// نافذة إضافة / تعديل خلفة. ترجع الخلفة المحفوظة.
Future<Customer?> showCustomerForm(BuildContext context, {Customer? existing}) {
  final name = TextEditingController(text: existing?.name);
  final phone = TextEditingController(text: existing?.phone);
  final notes = TextEditingController(text: existing?.notes);
  final formKey = GlobalKey<FormState>();

  return showModalBottomSheet<Customer>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (c) => Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(c).viewInsets.bottom + 20),
      child: Form(
        key: formKey,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(existing == null ? 'إضافة خلفة' : 'تعديل الخلفة',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          TextFormField(
            controller: name,
            autofocus: existing == null,
            decoration: const InputDecoration(labelText: 'الاسم', prefixIcon: Icon(Icons.person_outline)),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'اكتب الاسم' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: phone,
            keyboardType: TextInputType.phone,
            textDirection: TextDirection.ltr,
            decoration: const InputDecoration(
              labelText: 'رقم الواتساب (اختياري)',
              hintText: '07xx xxx xxxx',
              prefixIcon: Icon(Icons.chat_outlined),
              helperText: 'إذا انضاف، الوصل ينرسل له مباشرة بالواتساب',
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: notes,
            decoration: const InputDecoration(labelText: 'ملاحظات (اختياري)', prefixIcon: Icon(Icons.notes)),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final store = AppStore.instance;
              Customer saved;
              if (existing == null) {
                saved = await store.addCustomer(name.text, phone.text, notes.text);
              } else {
                existing
                  ..name = name.text.trim()
                  ..phone = phone.text.trim()
                  ..notes = notes.text.trim();
                await store.updateCustomer(existing);
                saved = existing;
              }
              if (c.mounted) Navigator.pop(c, saved);
            },
            child: const Text('حفظ'),
          ),
        ]),
      ),
    ),
  );
}
