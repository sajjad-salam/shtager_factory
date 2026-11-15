import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../telegram_backup.dart';
import '../ui.dart';
import 'customers_screen.dart';
import 'receipt_view_screen.dart';

class NewReceiptScreen extends StatefulWidget {
  final String? customerId;
  const NewReceiptScreen({super.key, this.customerId});

  @override
  State<NewReceiptScreen> createState() => _NewReceiptScreenState();
}

class _NewReceiptScreenState extends State<NewReceiptScreen> {
  final store = AppStore.instance;
  String? _customerId;
  final Map<String, TextEditingController> _qty = {};
  final Map<String, double> _priceOverride = {};
  final _paid = TextEditingController();
  final _notes = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _customerId = widget.customerId;
    for (final p in store.activeProducts) {
      _qty[p.id] = TextEditingController()..addListener(() => setState(() {}));
    }
    _paid.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    for (final c in _qty.values) {
      c.dispose();
    }
    _paid.dispose();
    _notes.dispose();
    super.dispose();
  }

  double _priceOf(Product p) => _priceOverride[p.id] ?? p.price;
  double _qtyOf(Product p) => parseNum(_qty[p.id]?.text ?? '');

  List<ReceiptItem> get _items => [
        for (final p in store.activeProducts)
          if (_qtyOf(p) > 0)
            ReceiptItem(
              productId: p.id,
              productName: p.name,
              unit: p.unit,
              qty: _qtyOf(p),
              unitPrice: _priceOf(p),
            ),
      ];

  double get _total => _items.fold(0, (s, i) => s + i.total);

  void _bump(Product p, double d) {
    final v = (_qtyOf(p) + d).clamp(0, 1e9);
    _qty[p.id]!.text = v == 0 ? '' : fmtNum(v).replaceAll(',', '');
  }

  Future<void> _pickCustomer() async {
    final id = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _CustomerPicker(),
    );
    if (id != null) setState(() => _customerId = id);
  }

  Future<void> _editPrice(Product p) async {
    final c = TextEditingController(text: fmtNum(_priceOf(p)).replaceAll(',', ''));
    final v = await showDialog<double>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text('سعر ${p.name} لهذا الوصل'),
        content: TextField(
          controller: c,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            suffixText: 'د.ع',
            helperText: 'السعر الأساسي ${fmtMoney(p.price)} — يتغير من صفحة الأسعار',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('إلغاء')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
            onPressed: () => Navigator.pop(d, parseNum(c.text)),
            child: const Text('تم'),
          ),
        ],
      ),
    );
    if (v != null) setState(() => v == p.price ? _priceOverride.remove(p.id) : _priceOverride[p.id] = v);
  }

  Future<void> _save() async {
    if (_customerId == null) {
      toast(context, 'اختار الخلفة أولاً', error: true);
      return;
    }
    final items = _items;
    if (items.isEmpty) {
      toast(context, 'حدد عدد منتج واحد على الأقل', error: true);
      return;
    }
    setState(() => _saving = true);
    final r = await store.addReceipt(
      customerId: _customerId!,
      items: items,
      paid: parseNum(_paid.text),
      notes: _notes.text,
    );
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => ReceiptViewScreen(receiptId: r.id, justCreated: true)),
    );
    // نرسل قاعدة البيانات الجديدة للتليجرام بالخلفية.
    TelegramBackup.instance.backupNow(reason: 'وصل جديد #${r.number}', receipt: r);
  }

  @override
  Widget build(BuildContext context) {
    final customer = _customerId == null ? null : store.customerById(_customerId!);
    final products = store.activeProducts;
    final total = _total;
    final paid = parseNum(_paid.text);
    final prevBal = customer == null ? 0.0 : store.balanceOf(customer.id);

    return Scaffold(
      appBar: AppBar(title: Text('وصل جديد #${store.nextReceiptNumber}')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Card(
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              onTap: widget.customerId == null ? _pickCustomer : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              leading: const Icon(Icons.person, color: brand),
              title: Text(customer?.name ?? 'اختار الخلفة',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: customer == null ? Colors.grey.shade600 : null)),
              subtitle: customer == null ? null : Text('الحساب السابق: ${fmtMoney(prevBal)}'),
              trailing: widget.customerId == null ? const Icon(Icons.expand_more) : null,
            ),
          ),
          const SectionTitle('المنتجات والأعداد'),
          if (products.isEmpty)
            const EmptyState(icon: Icons.sell_outlined, title: 'ما كو منتجات', subtitle: 'ضيف منتجات من صفحة الأسعار'),
          for (final p in products) ...[
            _productRow(p),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 8),
          TextField(
            controller: _paid,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'المبلغ الواصل الآن (اختياري)',
              suffixText: 'د.ع',
              prefixIcon: Icon(Icons.payments_outlined),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _notes,
            decoration: const InputDecoration(labelText: 'ملاحظات (اختياري)', prefixIcon: Icon(Icons.notes)),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Color(0xFFE2E8EB))),
          ),
          child: Row(children: [
            Expanded(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('الإجمالي', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                Text(fmtMoney(total), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: brand)),
                if (customer != null)
                  Text('الحساب بعد الوصل: ${fmtMoney(prevBal + total - paid)}',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
              ]),
            ),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.check),
              label: const Text('حفظ الوصل'),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _productRow(Product p) {
    final q = _qtyOf(p);
    final price = _priceOf(p);
    final overridden = _priceOverride.containsKey(p.id);
    final active = q > 0;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: active ? brand : const Color(0xFFE2E8EB), width: active ? 1.5 : 1),
      ),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            InkWell(
              onTap: () => _editPrice(p),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  '${fmtMoney(price)} / ${p.unit}${overridden ? ' (معدل)' : ''}',
                  style: TextStyle(
                    fontSize: 12,
                    color: overridden ? Colors.orange.shade800 : Colors.grey.shade600,
                    decoration: TextDecoration.underline,
                    decorationStyle: TextDecorationStyle.dotted,
                  ),
                ),
              ),
            ),
            if (active)
              Text('= ${fmtMoney(q * price)}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: brand)),
          ]),
        ),
        IconButton.filledTonal(onPressed: () => _bump(p, -1), icon: const Icon(Icons.remove)),
        SizedBox(
          width: 68,
          child: TextField(
            controller: _qty[p.id],
            textAlign: TextAlign.center,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            decoration: const InputDecoration(hintText: '0', isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 10)),
          ),
        ),
        IconButton.filled(onPressed: () => _bump(p, 1), icon: const Icon(Icons.add)),
      ]),
    );
  }
}

class _CustomerPicker extends StatefulWidget {
  const _CustomerPicker();

  @override
  State<_CustomerPicker> createState() => _CustomerPickerState();
}

class _CustomerPickerState extends State<_CustomerPicker> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final store = AppStore.instance;
    final list = store.customers.where((c) => _q.isEmpty || c.name.contains(_q)).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.75,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(context).viewInsets.bottom),
        child: Column(children: [
          Row(children: [
            Expanded(
              child: TextField(
                autofocus: true,
                decoration: const InputDecoration(hintText: 'بحث عن خلفة', prefixIcon: Icon(Icons.search), isDense: true),
                onChanged: (v) => setState(() => _q = v.trim()),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: () async {
                final c = await showCustomerForm(context);
                if (c != null && context.mounted) Navigator.pop(context, c.id);
              },
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('جديد'),
            ),
          ]),
          const SizedBox(height: 8),
          Expanded(
            child: list.isEmpty
                ? const EmptyState(icon: Icons.people_alt_outlined, title: 'ما كو خلفات', subtitle: 'اضغط "جديد" وضيف خلفة')
                : ListView.builder(
                    itemCount: list.length,
                    itemBuilder: (_, i) {
                      final c = list[i];
                      return ListTile(
                        leading: CircleAvatar(child: Text(c.name.characters.first)),
                        title: Text(c.name),
                        subtitle: Text('عليه ${fmtMoney(store.balanceOf(c.id))}'),
                        onTap: () => Navigator.pop(context, c.id),
                      );
                    },
                  ),
          ),
        ]),
      ),
    );
  }
}
