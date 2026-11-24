import 'package:flutter/material.dart';

import '../center_picker.dart';
import '../charts.dart';
import '../models.dart';
import '../reports.dart';
import '../store.dart';
import '../telegram_backup.dart';
import '../ui.dart';
import 'incoming_receipt_view_screen.dart';

/// قسم المشتريات (المصروفات): كل وصل شراء تابع لمعمل، أو «معامل أخرى»،
/// أو «منتجات أخرى».
class IncomingScreen extends StatefulWidget {
  const IncomingScreen({super.key, this.initialCenterId});

  final String? initialCenterId;

  @override
  State<IncomingScreen> createState() => _IncomingScreenState();
}

class _IncomingScreenState extends State<IncomingScreen> {
  final store = AppStore.instance;

  /// null = كل الجهات
  late String? _centerId = widget.initialCenterId;
  IncomingCategory? _filter;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        if (_centerId != null && !store.centerIds.contains(_centerId)) {
          _centerId = null;
        }
        final all =
            store.incomingReceipts
                .where(
                  (r) =>
                      _centerId == null ||
                      purchaseCenterOf(store, r) == _centerId,
                )
                .toList()
              ..sort((a, b) => b.date.compareTo(a.date));
        final receipts = _filter == null
            ? all
            : all.where((receipt) => receipt.category == _filter).toList();
        final categories = _centerId == null
            ? IncomingCategory.values
            : IncomingCategoryInfo.forCenter(_centerId!);
        return Scaffold(
          appBar: AppBar(
            title: const Text('المشتريات'),
            actions: const [BackupIndicator(), SizedBox(width: 8)],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.page,
              4,
              AppSpace.page,
              110,
            ),
            children: [
              _centerChips(),
              const SizedBox(height: 14),
              _summaryCard(all),
              const SizedBox(height: 20),
              Text(
                'الوصولات',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              _filters(categories),
              const SizedBox(height: 12),
              if (receipts.isEmpty)
                EmptyState(
                  icon: Icons.inventory_2_outlined,
                  title: _filter == null
                      ? 'ماكو مشتريات هنا بعد'
                      : 'ماكو وصولات بهذا التصنيف',
                  subtitle: _filter == null
                      ? 'اضغط «وصل شراء» وسجّل أول صرف'
                      : 'جرّب تصنيف ثاني أو أضف وصل جديد',
                )
              else
                for (final receipt in receipts) ...[
                  _receiptTile(receipt),
                  const SizedBox(height: 10),
                ],
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => NewIncomingReceiptScreen(centerId: _centerId),
              ),
            ),
            icon: const Icon(Icons.add_rounded),
            label: const Text('وصل شراء'),
          ),
        );
      },
    );
  }

  Widget _centerChips() => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        ChoiceChip(
          label: const Text('كل الجهات'),
          selected: _centerId == null,
          onSelected: (_) => setState(() {
            _centerId = null;
            _filter = null;
          }),
        ),
        const SizedBox(width: 8),
        for (final id in store.centerIds) ...[
          ChoiceChip(
            avatar: LegendDot(centerColor(id)),
            label: Text(store.centerName(id)),
            selected: _centerId == id,
            onSelected: (_) => setState(() {
              _centerId = id;
              _filter = null;
            }),
          ),
          const SizedBox(width: 8),
        ],
      ],
    ),
  );

  Widget _summaryCard(List<IncomingReceipt> list) {
    final total = list.fold<double>(0, (s, r) => s + r.amount);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: brand,
        borderRadius: BorderRadius.circular(AppRadius.tile),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _centerId == null
                ? 'إجمالي المشتريات'
                : 'مشتريات ${store.centerName(_centerId!)}',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            fmtMoney(total),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .14),
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Text(
              '${list.length} وصل',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filters(List<IncomingCategory> categories) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        ChoiceChip(
          label: const Text('الكل'),
          selected: _filter == null,
          onSelected: (_) => setState(() => _filter = null),
        ),
        const SizedBox(width: 8),
        for (final category in categories) ...[
          ChoiceChip(
            label: Text(category.label),
            selected: _filter == category,
            onSelected: (_) => setState(() => _filter = category),
          ),
          const SizedBox(width: 8),
        ],
      ],
    ),
  );

  Widget _receiptTile(IncomingReceipt receipt) {
    final center = purchaseCenterOf(store, receipt);
    final detail = [
      if (_centerId == null) store.centerName(center),
      if (receipt.supplier.isNotEmpty) receipt.supplier,
      if (receipt.notes.isNotEmpty) receipt.notes,
    ];
    return Material(
      color: appSurface,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => IncomingReceiptViewScreen(receiptId: receipt.id),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: centerColor(center).withValues(alpha: .16),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(categoryIcon(receipt.category), color: appInk),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      receipt.category.label,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      detail.isEmpty
                          ? fmtDateTime(receipt.date)
                          : detail.join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: appMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    fmtMoney(receipt.amount),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: debtColor,
                    ),
                  ),
                  Text(
                    '#${receipt.number} · ${fmtDate(receipt.date)}',
                    style: const TextStyle(fontSize: 11, color: appMuted),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class NewIncomingReceiptScreen extends StatefulWidget {
  const NewIncomingReceiptScreen({super.key, this.centerId});

  /// الجهة المختارة مسبقاً (اختياري).
  final String? centerId;

  @override
  State<NewIncomingReceiptScreen> createState() =>
      _NewIncomingReceiptScreenState();
}

class _NewIncomingReceiptScreenState extends State<NewIncomingReceiptScreen> {
  final store = AppStore.instance;
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _supplier = TextEditingController();
  final _notes = TextEditingController();
  late String? _centerId = widget.centerId;
  late IncomingCategory _category = _defaultCategory(_centerId);
  bool _centerError = false;
  bool _saving = false;

  static IncomingCategory _defaultCategory(String? centerId) => centerId == null
      ? IncomingCategory.cement
      : IncomingCategoryInfo.forCenter(centerId).first;

  @override
  void initState() {
    super.initState();
    _supplier.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _amount.dispose();
    _supplier.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _pickCenter(String id) {
    setState(() {
      _centerId = id;
      _centerError = false;
      final allowed = IncomingCategoryInfo.forCenter(id);
      if (!allowed.contains(_category)) _category = allowed.first;
    });
  }

  Future<void> _save() async {
    final center = _centerId;
    if (center == null) {
      setState(() => _centerError = true);
      toast(context, 'اختار الجهة اللي ينحسب عليها الصرف', error: true);
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final receipt = await store.addIncomingReceipt(
      factoryId: center,
      category: _category,
      amount: parseNum(_amount.text),
      notes: _notes.text,
      supplier: _supplier.text,
    );
    TelegramBackup.instance.backupNow(
      reason: 'وصل شراء جديد #${receipt.number}',
      incomingReceipt: receipt,
    );
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) =>
            IncomingReceiptViewScreen(receiptId: receipt.id, justCreated: true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categories = _centerId == null
        ? IncomingCategoryInfo.forCenter('')
        : IncomingCategoryInfo.forCenter(_centerId!);
    final typed = _supplier.text.trim();
    final suggestions = store
        .suppliersFor()
        .where((s) => s != typed && (typed.isEmpty || s.contains(typed)))
        .take(6)
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: Text('وصل شراء #${store.nextIncomingReceiptNumber}'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpace.page),
          children: [
            const SectionTitle('الصرف على أي جهة؟'),
            CenterPicker(
              ids: store.centerIds,
              selected: _centerId,
              error: _centerError,
              onChanged: _pickCenter,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
              child: Text(
                _centerId == null
                    ? 'اختار المعمل حتى ينحسب الصرف من ربحه.'
                    : centerHint(_centerId!),
                style: TextStyle(
                  fontSize: 12,
                  color: _centerError ? debtColor : appMuted,
                ),
              ),
            ),
            const SizedBox(height: 10),
            const SectionTitle('نوع الصرف'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final category in categories)
                  ChoiceChip(
                    avatar: Icon(categoryIcon(category), size: 18),
                    label: Text(category.label),
                    selected: _category == category,
                    onSelected: (_) => setState(() => _category = category),
                  ),
              ],
            ),
            const SizedBox(height: 22),
            NumericKeyboardTarget(
              controller: _amount,
              child: TextFormField(
                controller: _amount,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'المبلغ',
                  suffixText: 'د.ع',
                  prefixIcon: Icon(Icons.payments_outlined),
                ),
                validator: (value) =>
                    parseNum(value ?? '') <= 0 ? 'اكتب مبلغ أكبر من صفر' : null,
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _supplier,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: _category == IncomingCategory.workers
                    ? 'اسم العامل أو الفريق (اختياري)'
                    : 'اشتريت من؟ (اختياري)',
                hintText: _category == IncomingCategory.workers
                    ? 'مثال: فريق سمير'
                    : 'مثال: معمل أسمنت كربلاء، معرض أبو أحمد',
                prefixIcon: const Icon(Icons.storefront_outlined),
              ),
            ),
            if (suggestions.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final s in suggestions)
                    ActionChip(
                      avatar: const Icon(Icons.history_rounded, size: 16),
                      label: Text(s),
                      onPressed: () => _supplier.text = s,
                    ),
                ],
              ),
            ],
            const SizedBox(height: 14),
            TextFormField(
              controller: _notes,
              minLines: 2,
              maxLines: 6,
              decoration: InputDecoration(
                labelText: 'ملاحظات (اختياري)',
                alignLabelWithHint: true,
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(bottom: 30),
                  child: Icon(Icons.notes_outlined),
                ),
                helperText: _category == IncomingCategory.workers
                    ? 'مثال: أجور هذا الأسبوع'
                    : _category == IncomingCategory.goods
                    ? 'مثال: ٥٠٠ قطعة شتايكر، أو ٢٠ تنكة ماستيك'
                    : _category == IncomingCategory.other
                    ? 'مثال: تصليح المولد'
                    : 'مثال: اسم السائق، عدد السيارات أو مقدار الحمل',
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: KeyboardSafeActionBar(
        child: FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check_rounded),
          label: const Text('حفظ الوصل'),
        ),
      ),
    );
  }
}

IconData categoryIcon(IncomingCategory category) => switch (category) {
  IncomingCategory.cement => Icons.inventory_2_outlined,
  IncomingCategory.gravel => Icons.grain_outlined,
  IncomingCategory.sand => Icons.landscape_outlined,
  IncomingCategory.workers => Icons.groups_2_outlined,
  IncomingCategory.goods => Icons.shopping_bag_outlined,
  IncomingCategory.other => Icons.build_circle_outlined,
};
