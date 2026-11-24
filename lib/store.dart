import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

/// مخزن البيانات المحلي. كل البيانات تنحفظ على الجهاز (shared_preferences)
/// وتنرسل نسخة منها لبوت التليجرام كنسخة احتياطية.
class AppStore extends ChangeNotifier {
  AppStore._();
  static final AppStore instance = AppStore._();

  static const _dbKey = 'db_v1';
  static const _settingsKey = 'settings_v1';
  static const _backupKey = 'backup_state_v1';

  late SharedPreferences _prefs;

  List<Customer> customers = [];
  List<Product> products = [];
  List<Receipt> receipts = [];
  List<Payment> payments = [];
  List<FactoryLocation> factories = [];
  List<IncomingReceipt> incomingReceipts = [];
  int nextReceiptNumber = 1;
  int nextIncomingReceiptNumber = 1;
  AppSettings settings = AppSettings();

  /// هل توجد تغييرات لم تنرسل للتليجرام بعد؟
  bool backupPending = false;
  DateTime? lastBackupAt;
  String? lastBackupError;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    customers = [];
    products = [];
    receipts = [];
    payments = [];
    factories = [];
    incomingReceipts = [];
    nextReceiptNumber = 1;
    nextIncomingReceiptNumber = 1;
    settings = AppSettings();
    final raw = _prefs.getString(_dbKey);
    if (raw != null) {
      importDb(jsonDecode(raw) as Map<String, dynamic>, save: false);
    } else {
      products = defaultProducts();
      factories = defaultFactories();
    }
    final s = _prefs.getString(_settingsKey);
    if (s != null) settings = AppSettings.fromJson(jsonDecode(s));
    final b = _prefs.getString(_backupKey);
    if (b != null) {
      final j = jsonDecode(b) as Map<String, dynamic>;
      backupPending = j['pending'] as bool? ?? false;
      lastBackupAt = DateTime.tryParse(j['lastAt'] as String? ?? '');
    }
  }

  static List<Product> defaultProducts() => [
    Product(id: 'p_staiger', name: 'شتايكر', unit: 'قطعة', factoryMade: true),
    Product(id: 'p_foam', name: 'فوم', unit: 'لوح'),
    Product(id: 'p_mastic', name: 'ماستيك', unit: 'تنكة'),
    Product(id: 'p_asphalt', name: 'زفت', unit: 'برميل'),
    Product(id: 'p_flintkote', name: 'فلانكوت', unit: 'تنكة'),
    Product(id: 'p_cork', name: 'فلين', unit: 'لوح'),
  ];

  static List<FactoryLocation> defaultFactories() => [
    FactoryLocation(id: 'factory_main', name: 'المعمل الرئيسي'),
  ];

  // ───────────── الحفظ والتصدير ─────────────

  Map<String, dynamic> exportDb() => {
    'app': 'shtager',
    'version': 3,
    'exportedAt': DateTime.now().toIso8601String(),
    'nextReceiptNumber': nextReceiptNumber,
    'nextIncomingReceiptNumber': nextIncomingReceiptNumber,
    'shop': {
      'shopName': settings.shopName,
      'shopPhone': settings.shopPhone,
      'shopAddress': settings.shopAddress,
    },
    'customers': customers.map((e) => e.toJson()).toList(),
    'products': products.map((e) => e.toJson()).toList(),
    'receipts': receipts.map((e) => e.toJson()).toList(),
    'payments': payments.map((e) => e.toJson()).toList(),
    'factories': factories.map((e) => e.toJson()).toList(),
    'incomingReceipts': incomingReceipts.map((e) => e.toJson()).toList(),
  };

  void importDb(Map<String, dynamic> j, {bool save = true}) {
    List<Map<String, dynamic>> list(String k) => ((j[k] as List?) ?? [])
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    customers = list('customers').map(Customer.fromJson).toList();
    products = list('products').map(Product.fromJson).toList();
    receipts = list('receipts').map(Receipt.fromJson).toList();
    payments = list('payments').map(Payment.fromJson).toList();
    factories = list('factories').map(FactoryLocation.fromJson).toList();
    if (factories.isEmpty) factories = defaultFactories();
    incomingReceipts = list(
      'incomingReceipts',
    ).map(IncomingReceipt.fromJson).toList();
    final maxNo = receipts.fold<int>(0, (m, r) => r.number > m ? r.number : m);
    nextReceiptNumber = (j['nextReceiptNumber'] as num?)?.toInt() ?? maxNo + 1;
    if (nextReceiptNumber <= maxNo) nextReceiptNumber = maxNo + 1;
    final maxIncomingNo = incomingReceipts.fold<int>(
      0,
      (m, r) => r.number > m ? r.number : m,
    );
    nextIncomingReceiptNumber =
        (j['nextIncomingReceiptNumber'] as num?)?.toInt() ?? maxIncomingNo + 1;
    if (nextIncomingReceiptNumber <= maxIncomingNo) {
      nextIncomingReceiptNumber = maxIncomingNo + 1;
    }
    if (products.isEmpty) products = defaultProducts();
    // قبل التحديث كانت كل المبيعات تُحسب على معمل واحد، فالوصولات القديمة
    // اللي بيها شتايكر تنربط بأول معمل. تكدر تغيرها من صفحة الوصل.
    for (final r in receipts) {
      if (r.factoryId.isEmpty && r.hasFactoryItems) {
        r.factoryId = factories.first.id;
      }
    }
    final shop = j['shop'];
    if (shop is Map && save) {
      settings.shopName = shop['shopName'] as String? ?? settings.shopName;
      settings.shopPhone = shop['shopPhone'] as String? ?? settings.shopPhone;
      settings.shopAddress =
          shop['shopAddress'] as String? ?? settings.shopAddress;
    }
    if (save) {
      _saveDb(markPending: false);
      saveSettings();
    }
  }

  Future<void> _saveDb({bool markPending = true}) async {
    await _prefs.setString(_dbKey, jsonEncode(exportDb()));
    if (markPending) await setBackupState(pending: true);
    notifyListeners();
  }

  Future<void> saveSettings() async {
    await _prefs.setString(_settingsKey, jsonEncode(settings.toJson()));
    notifyListeners();
  }

  Future<void> setBackupState({
    required bool pending,
    DateTime? at,
    String? error,
  }) async {
    backupPending = pending;
    if (at != null) lastBackupAt = at;
    lastBackupError = error;
    await _prefs.setString(
      _backupKey,
      jsonEncode({
        'pending': backupPending,
        'lastAt': lastBackupAt?.toIso8601String(),
      }),
    );
    notifyListeners();
  }

  // ───────────── الخلفات ─────────────

  Customer? customerById(String id) {
    for (final c in customers) {
      if (c.id == id) return c;
    }
    return null;
  }

  Future<Customer> addCustomer(String name, String phone, String notes) async {
    final c = Customer(
      id: newId(),
      name: name.trim(),
      phone: phone.trim(),
      notes: notes.trim(),
    );
    customers.add(c);
    await _saveDb();
    return c;
  }

  Future<void> updateCustomer(Customer c) => _saveDb();

  Future<void> deleteCustomer(String id) async {
    customers.removeWhere((c) => c.id == id);
    receipts.removeWhere((r) => r.customerId == id);
    payments.removeWhere((p) => p.customerId == id);
    await _saveDb();
  }

  List<Receipt> receiptsOf(String customerId) =>
      receipts.where((r) => r.customerId == customerId).toList()
        ..sort((a, b) => b.date.compareTo(a.date));

  List<Payment> paymentsOf(String customerId) =>
      payments.where((p) => p.customerId == customerId).toList()
        ..sort((a, b) => b.date.compareTo(a.date));

  /// المبلغ اللي على الخلفة = مجموع الوصولات - (المدفوع بالوصولات + الدفعات)
  double balanceOf(String customerId, {String? excludingReceiptId}) {
    double b = 0;
    for (final r in receipts) {
      if (r.customerId == customerId && r.id != excludingReceiptId) {
        b += r.remaining;
      }
    }
    for (final p in payments) {
      if (p.customerId == customerId) b -= p.amount;
    }
    return b;
  }

  /// مجموع ما أخذه الخلفة من كل منتج (الاسم ← الكمية، الوحدة)
  Map<String, (double, String)> takenBy(String customerId) {
    final m = <String, (double, String)>{};
    for (final r in receipts.where((r) => r.customerId == customerId)) {
      for (final i in r.items) {
        final prev = m[i.productName];
        m[i.productName] = ((prev?.$1 ?? 0) + i.qty, i.unit);
      }
    }
    return m;
  }

  double get totalOutstanding =>
      customers.fold(0, (s, c) => s + balanceOf(c.id));

  // ───────────── المنتجات ─────────────

  List<Product> get activeProducts => products.where((p) => p.active).toList();

  Future<void> addProduct(
    String name,
    String unit,
    double price, {
    bool factoryMade = false,
  }) async {
    products.add(
      Product(
        id: newId(),
        name: name.trim(),
        unit: unit.trim(),
        price: price,
        factoryMade: factoryMade,
      ),
    );
    await _saveDb();
  }

  Future<void> saveProducts() => _saveDb();

  Future<void> deleteProduct(String id) async {
    products.removeWhere((p) => p.id == id);
    await _saveDb();
  }

  // ───────────── الوصولات والدفعات ─────────────

  Future<Receipt> addReceipt({
    required String customerId,
    required List<ReceiptItem> items,
    double paid = 0,
    String notes = '',
    String factoryId = '',
  }) async {
    final r = Receipt(
      id: newId(),
      number: nextReceiptNumber++,
      customerId: customerId,
      date: DateTime.now(),
      items: items,
      paid: paid,
      notes: notes.trim(),
      factoryId: items.any((i) => i.factoryMade) ? factoryId : '',
    );
    receipts.add(r);
    await _saveDb();
    return r;
  }

  /// تصحيح المعمل اللي طلع منه شتايكر وصل قديم.
  Future<void> setReceiptFactory(Receipt r, String factoryId) async {
    r.factoryId = factoryId;
    await _saveDb();
  }

  Future<void> deleteReceipt(String id) async {
    receipts.removeWhere((r) => r.id == id);
    await _saveDb();
  }

  Future<Payment> addPayment(
    String customerId,
    double amount,
    String notes,
  ) async {
    final p = Payment(
      id: newId(),
      customerId: customerId,
      date: DateTime.now(),
      amount: amount,
      notes: notes.trim(),
    );
    payments.add(p);
    await _saveDb();
    return p;
  }

  Future<void> deletePayment(String id) async {
    payments.removeWhere((p) => p.id == id);
    await _saveDb();
  }

  // ───────────── المشتريات والمعامل ─────────────

  FactoryLocation? factoryById(String id) {
    for (final factory in factories) {
      if (factory.id == id) return factory;
    }
    return null;
  }

  /// اسم أي جهة: معمل، «معامل أخرى»، أو «منتجات أخرى».
  String centerName(String id) => switch (id) {
    kOtherFactoriesId => 'معامل أخرى',
    kOtherProductsId => 'منتجات أخرى',
    _ => factoryById(id)?.name ?? 'معامل أخرى',
  };

  /// كل الجهات بالترتيب: معاملي، ثم «معامل أخرى»، ثم «منتجات أخرى».
  List<String> get centerIds => [
    for (final f in factories) f.id,
    kOtherFactoriesId,
    kOtherProductsId,
  ];

  /// الجهات اللي يطلع منها الشتايكر بوصل البيع.
  List<String> get stygerSourceIds => [
    for (final f in factories) f.id,
    kOtherFactoriesId,
  ];

  /// أسماء الموردين السابقين، الأكثر استخداماً أولاً.
  List<String> suppliersFor([String? centerId]) {
    final count = <String, int>{};
    for (final r in incomingReceipts) {
      final s = r.supplier.trim();
      if (s.isEmpty || (centerId != null && r.factoryId != centerId)) continue;
      count[s] = (count[s] ?? 0) + 1;
    }
    return count.keys.toList()..sort((a, b) => count[b]!.compareTo(count[a]!));
  }

  List<IncomingReceipt> incomingOf(String factoryId) =>
      incomingReceipts.where((r) => r.factoryId == factoryId).toList()
        ..sort((a, b) => b.date.compareTo(a.date));

  Future<FactoryLocation> addFactory(String name) async {
    final factory = FactoryLocation(id: newId(), name: name.trim());
    factories.add(factory);
    await _saveDb();
    return factory;
  }

  Future<void> renameFactory(FactoryLocation factory, String name) async {
    factory.name = name.trim();
    await _saveDb();
  }

  /// يحذف المعمل ومشترياته. وصولات البيع ما تنحذف (لأنها حسابات خلفات)،
  /// بس الشتايكر اللي بيها ينتقل إلى «معامل أخرى».
  Future<void> deleteFactory(String id) async {
    if (factories.length <= 1) return;
    factories.removeWhere((factory) => factory.id == id);
    incomingReceipts.removeWhere((receipt) => receipt.factoryId == id);
    for (final r in receipts) {
      if (r.factoryId == id) r.factoryId = kOtherFactoriesId;
    }
    await _saveDb();
  }

  Future<IncomingReceipt> addIncomingReceipt({
    required String factoryId,
    required IncomingCategory category,
    required double amount,
    String notes = '',
    String supplier = '',
  }) async {
    final receipt = IncomingReceipt(
      id: newId(),
      number: nextIncomingReceiptNumber++,
      factoryId: factoryId,
      category: category,
      amount: amount,
      notes: notes.trim(),
      supplier: supplier.trim(),
    );
    incomingReceipts.add(receipt);
    await _saveDb();
    return receipt;
  }

  Future<void> deleteIncomingReceipt(String id) async {
    incomingReceipts.removeWhere((receipt) => receipt.id == id);
    await _saveDb();
  }

  double incomingTotalOf(String factoryId) => incomingReceipts
      .where((r) => r.factoryId == factoryId)
      .fold(0, (sum, receipt) => sum + receipt.amount);

  double incomingCategoryTotal(String factoryId, IncomingCategory category) =>
      incomingReceipts
          .where((r) => r.factoryId == factoryId && r.category == category)
          .fold(0, (sum, receipt) => sum + receipt.amount);

  double get totalSales =>
      receipts.fold(0, (sum, receipt) => sum + receipt.total);

  double get totalPurchases =>
      incomingReceipts.fold(0, (sum, receipt) => sum + receipt.amount);

  double get estimatedProfit => totalSales - totalPurchases;
}

// ───────────── تنسيق الأرقام والتواريخ ─────────────

String fmtNum(num v) {
  final neg = v < 0;
  final abs = v.abs();
  final whole = abs.truncate();
  final frac = abs - whole;
  final s = whole.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  var out = buf.toString();
  if (frac > 0.0001) {
    out += (frac.toStringAsFixed(2).substring(1)).replaceAll(
      RegExp(r'0+$'),
      '',
    );
  }
  return neg ? '-$out' : out;
}

String fmtMoney(num v) => '${fmtNum(v)} د.ع';

String fmtDate(DateTime d) =>
    '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';

String fmtDateTime(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final ampm = d.hour < 12 ? 'ص' : 'م';
  return '${fmtDate(d)}  $h:${d.minute.toString().padLeft(2, '0')} $ampm';
}

double parseNum(String s) {
  const ar = '٠١٢٣٤٥٦٧٨٩';
  var t = s.trim();
  for (var i = 0; i < 10; i++) {
    t = t.replaceAll(ar[i], '$i');
  }
  t = t.replaceAll(',', '').replaceAll('٬', '').replaceAll('٫', '.');
  return double.tryParse(t) ?? 0;
}
