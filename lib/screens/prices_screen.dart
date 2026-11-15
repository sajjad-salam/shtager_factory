import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../ui.dart';

/// صفحة تعديل أسعار المنتجات. الأسعار الجديدة تنطبق على الوصولات الجديدة فقط،
/// الوصولات القديمة تبقى بسعرها وقت ما انكتبت.
class PricesScreen extends StatefulWidget {
  const PricesScreen({super.key});

  @override
  State<PricesScreen> createState() => _PricesScreenState();
}

class _PricesScreenState extends State<PricesScreen> {
  final store = AppStore.instance;
  final Map<String, TextEditingController> _price = {};
  final Map<String, TextEditingController> _name = {};
  final Map<String, TextEditingController> _unit = {};
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  void _sync() {
    for (final p in store.products) {
      _price.putIfAbsent(p.id, () => _ctl(p.price == 0 ? '' : fmtNum(p.price).replaceAll(',', '')));
      _name.putIfAbsent(p.id, () => _ctl(p.name));
      _unit.putIfAbsent(p.id, () => _ctl(p.unit));
    }
  }

  TextEditingController _ctl(String t) =>
      TextEditingController(text: t)..addListener(() => mounted && !_dirty ? setState(() => _dirty = true) : null);

  Future<void> _save() async {
    for (final p in store.products) {
      p.price = parseNum(_price[p.id]!.text);
      if (_name[p.id]!.text.trim().isNotEmpty) p.name = _name[p.id]!.text.trim();
      p.unit = _unit[p.id]!.text.trim();
    }
    await store.saveProducts();
    setState(() => _dirty = false);
    if (mounted) {
      FocusScope.of(context).unfocus();
      toast(context, 'انحفظت الأسعار ✓');
    }
  }

  Future<void> _add() async {
    final name = TextEditingController();
    final unit = TextEditingController(text: 'قطعة');
    final price = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('منتج جديد'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, autofocus: true, decoration: const InputDecoration(labelText: 'اسم المنتج')),
          const SizedBox(height: 10),
          TextField(controller: unit, decoration: const InputDecoration(labelText: 'الوحدة (قطعة، لوح، تنكة...)')),
          const SizedBox(height: 10),
          TextField(
            controller: price,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'السعر', suffixText: 'د.ع'),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('إلغاء')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
            onPressed: () => Navigator.pop(d, true),
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
    if (ok != true || name.text.trim().isEmpty) return;
    await store.addProduct(name.text, unit.text, parseNum(price.text));
    setState(_sync);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        _sync();
        return Stack(children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: brand.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(12)),
                child: const Row(children: [
                  Icon(Icons.info_outline, color: brand, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text('غيّر السعر واضغط حفظ. الوصولات القديمة تبقى بسعرها القديم.',
                        style: TextStyle(fontSize: 13)),
                  ),
                ]),
              ),
              const SizedBox(height: 12),
              for (final p in store.products) ...[
                _row(p),
                const SizedBox(height: 10),
              ],
              OutlinedButton.icon(onPressed: _add, icon: const Icon(Icons.add), label: const Text('إضافة منتج')),
            ],
          ),
          if (_dirty)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: FilledButton.icon(onPressed: _save, icon: const Icon(Icons.save), label: const Text('حفظ الأسعار')),
            ),
        ]);
      },
    );
  }

  Widget _row(Product p) => Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 6, 12),
          child: Column(children: [
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _name[p.id],
                  style: TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w700, color: p.active ? null : Colors.grey),
                  decoration: const InputDecoration(
                      border: InputBorder.none, enabledBorder: InputBorder.none, filled: false, isDense: true),
                ),
              ),
              Switch(
                value: p.active,
                onChanged: (v) async {
                  p.active = v;
                  await store.saveProducts();
                },
              ),
              PopupMenuButton<String>(
                onSelected: (v) async {
                  if (v == 'del' &&
                      await confirm(context, 'حذف ${p.name}؟', 'الوصولات القديمة ما تتأثر.')) {
                    await store.deleteProduct(p.id);
                  }
                },
                itemBuilder: (_) => const [PopupMenuItem(value: 'del', child: Text('حذف المنتج'))],
              ),
            ]),
            Row(children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _price[p.id],
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  decoration: const InputDecoration(labelText: 'السعر', suffixText: 'د.ع'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _unit[p.id],
                  decoration: const InputDecoration(labelText: 'الوحدة'),
                ),
              ),
              const SizedBox(width: 8),
            ]),
          ]),
        ),
      );
}
