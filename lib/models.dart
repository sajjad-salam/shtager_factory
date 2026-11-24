// نماذج البيانات: الخلفات، المنتجات، الوصولات، الدفعات، المعامل والمشتريات.

/// جهة ربح خاصة: شتايكر مشترى من معامل غير معاملي ويُباع للخلفات.
const kOtherFactoriesId = 'other_factories';

/// جهة ربح خاصة: كل المنتجات غير الشتايكر (فوم، ماستيك، زفت...).
const kOtherProductsId = 'other_products';

/// هل المنتج شتايكر من إنتاج المعامل؟ يستخدم للبيانات القديمة اللي ما بيها الحقل.
bool looksLikeStyger(String id, String name) =>
    id == 'p_staiger' || name.contains('شتايكر') || name.contains('ستايكر');

int _idSeq = 0;

/// معرف فريد حتى لو انكتب سجلين بنفس اللحظة (دقة الساعة على بعض الأجهزة محدودة).
String newId() =>
    DateTime.now().microsecondsSinceEpoch.toRadixString(36) +
    (_idSeq++ & 0xffff).toRadixString(36).padLeft(4, '0');

class Customer {
  final String id;
  String name;
  String phone; // رقم الواتساب (اختياري)
  String notes;
  final DateTime createdAt;

  Customer({
    required this.id,
    required this.name,
    this.phone = '',
    this.notes = '',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'phone': phone,
    'notes': notes,
    'createdAt': createdAt.toIso8601String(),
  };

  factory Customer.fromJson(Map<String, dynamic> j) => Customer(
    id: j['id'] as String,
    name: j['name'] as String? ?? '',
    phone: j['phone'] as String? ?? '',
    notes: j['notes'] as String? ?? '',
    createdAt: DateTime.tryParse(j['createdAt'] as String? ?? ''),
  );
}

class Product {
  final String id;
  String name;
  String unit; // مثال: قطعة، لفة، كغم، تنكة
  double price;
  bool active;

  /// شتايكر من إنتاج المعامل: مبيعاته تُحسب على المعمل المختار بالوصل.
  /// باقي المنتجات تُحسب على «منتجات أخرى».
  bool factoryMade;

  Product({
    required this.id,
    required this.name,
    this.unit = 'قطعة',
    this.price = 0,
    this.active = true,
    this.factoryMade = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'unit': unit,
    'price': price,
    'active': active,
    'factoryMade': factoryMade,
  };

  factory Product.fromJson(Map<String, dynamic> j) {
    final id = j['id'] as String;
    final name = j['name'] as String? ?? '';
    return Product(
      id: id,
      name: name,
      unit: j['unit'] as String? ?? 'قطعة',
      price: (j['price'] as num?)?.toDouble() ?? 0,
      active: j['active'] as bool? ?? true,
      factoryMade: j['factoryMade'] as bool? ?? looksLikeStyger(id, name),
    );
  }
}

/// سطر في الوصل. السعر يُحفظ وقت إنشاء الوصل حتى لا يتأثر بتغيير الأسعار لاحقاً.
class ReceiptItem {
  final String productId;
  final String productName;
  final String unit;
  final double qty;
  final double unitPrice;

  /// نسخة من [Product.factoryMade] وقت كتابة الوصل.
  final bool factoryMade;

  ReceiptItem({
    required this.productId,
    required this.productName,
    required this.unit,
    required this.qty,
    required this.unitPrice,
    bool? factoryMade,
  }) : factoryMade = factoryMade ?? looksLikeStyger(productId, productName);

  double get total => qty * unitPrice;

  Map<String, dynamic> toJson() => {
    'productId': productId,
    'productName': productName,
    'unit': unit,
    'qty': qty,
    'unitPrice': unitPrice,
    'factoryMade': factoryMade,
  };

  factory ReceiptItem.fromJson(Map<String, dynamic> j) => ReceiptItem(
    productId: j['productId'] as String? ?? '',
    productName: j['productName'] as String? ?? '',
    unit: j['unit'] as String? ?? '',
    qty: (j['qty'] as num?)?.toDouble() ?? 0,
    unitPrice: (j['unitPrice'] as num?)?.toDouble() ?? 0,
    factoryMade: j['factoryMade'] as bool?,
  );
}

class Receipt {
  final String id;
  final int number;
  final String customerId;
  final DateTime date;
  final List<ReceiptItem> items;
  final double paid; // المبلغ الواصل وقت الوصل
  final String notes;

  /// المعمل اللي طلع منه الشتايكر: معرف معمل أو [kOtherFactoriesId].
  /// فارغ إذا الوصل ما بيه شتايكر.
  String factoryId;

  Receipt({
    required this.id,
    required this.number,
    required this.customerId,
    required this.date,
    required this.items,
    this.paid = 0,
    this.notes = '',
    this.factoryId = '',
  });

  double get total => items.fold(0, (s, i) => s + i.total);
  double get remaining => total - paid;

  bool get hasFactoryItems => items.any((i) => i.factoryMade);

  /// مبلغ الشتايكر بالوصل (يُحسب على [factoryId]).
  double get factoryTotal =>
      items.where((i) => i.factoryMade).fold(0, (s, i) => s + i.total);

  /// مبلغ باقي المنتجات (يُحسب على «منتجات أخرى»).
  double get otherProductsTotal => total - factoryTotal;

  double get factoryQty =>
      items.where((i) => i.factoryMade).fold(0, (s, i) => s + i.qty);

  Map<String, dynamic> toJson() => {
    'id': id,
    'number': number,
    'customerId': customerId,
    'date': date.toIso8601String(),
    'items': items.map((e) => e.toJson()).toList(),
    'paid': paid,
    'notes': notes,
    'factoryId': factoryId,
  };

  factory Receipt.fromJson(Map<String, dynamic> j) => Receipt(
    id: j['id'] as String,
    number: (j['number'] as num?)?.toInt() ?? 0,
    customerId: j['customerId'] as String? ?? '',
    date: DateTime.tryParse(j['date'] as String? ?? '') ?? DateTime.now(),
    items: ((j['items'] as List?) ?? [])
        .map((e) => ReceiptItem.fromJson(Map<String, dynamic>.from(e)))
        .toList(),
    paid: (j['paid'] as num?)?.toDouble() ?? 0,
    notes: j['notes'] as String? ?? '',
    factoryId: j['factoryId'] as String? ?? '',
  );
}

/// دفعة (تسديد) من الخلفة تُنقص من المبلغ اللي عليه.
class Payment {
  final String id;
  final String customerId;
  final DateTime date;
  final double amount;
  final String notes;

  Payment({
    required this.id,
    required this.customerId,
    required this.date,
    required this.amount,
    this.notes = '',
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'customerId': customerId,
    'date': date.toIso8601String(),
    'amount': amount,
    'notes': notes,
  };

  factory Payment.fromJson(Map<String, dynamic> j) => Payment(
    id: j['id'] as String,
    customerId: j['customerId'] as String? ?? '',
    date: DateTime.tryParse(j['date'] as String? ?? '') ?? DateTime.now(),
    amount: (j['amount'] as num?)?.toDouble() ?? 0,
    notes: j['notes'] as String? ?? '',
  );
}

/// معمل من معاملي. كل معمل إله مبيعات شتايكر ومشتريات خاصة بيه.
class FactoryLocation {
  final String id;
  String name;
  final DateTime createdAt;

  FactoryLocation({required this.id, required this.name, DateTime? createdAt})
    : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'createdAt': createdAt.toIso8601String(),
  };

  factory FactoryLocation.fromJson(Map<String, dynamic> j) => FactoryLocation(
    id: j['id'] as String? ?? newId(),
    name: j['name'] as String? ?? 'المعمل الرئيسي',
    createdAt: DateTime.tryParse(j['createdAt'] as String? ?? ''),
  );
}

enum IncomingCategory { cement, gravel, sand, workers, goods, other }

extension IncomingCategoryInfo on IncomingCategory {
  String get key => switch (this) {
    IncomingCategory.cement => 'cement',
    IncomingCategory.gravel => 'gravel',
    IncomingCategory.sand => 'sand',
    IncomingCategory.workers => 'workers',
    IncomingCategory.goods => 'goods',
    IncomingCategory.other => 'other',
  };

  String get label => switch (this) {
    IncomingCategory.cement => 'أسمنت',
    IncomingCategory.gravel => 'حصو',
    IncomingCategory.sand => 'رمل',
    IncomingCategory.workers => 'عمال',
    IncomingCategory.goods => 'شراء بضاعة',
    IncomingCategory.other => 'صرفيات أخرى',
  };

  /// التصنيفات المناسبة لكل جهة: المعمل يصرف على المواد والعمال،
  /// والمعامل الأخرى والمنتجات الأخرى تشتري بضاعة جاهزة.
  static List<IncomingCategory> forCenter(String centerId) =>
      centerId == kOtherFactoriesId || centerId == kOtherProductsId
      ? const [IncomingCategory.goods, IncomingCategory.other]
      : const [
          IncomingCategory.cement,
          IncomingCategory.gravel,
          IncomingCategory.sand,
          IncomingCategory.workers,
          IncomingCategory.other,
        ];

  static IncomingCategory fromKey(String? key) =>
      IncomingCategory.values.firstWhere(
        (value) => value.key == key,
        orElse: () => IncomingCategory.other,
      );
}

/// وصل شراء/صرف تابع لجهة واحدة: معمل، أو «معامل أخرى»، أو «منتجات أخرى».
class IncomingReceipt {
  final String id;
  final int number;
  String factoryId;
  final IncomingCategory category;
  final double amount;
  final String notes;
  final DateTime date;

  IncomingReceipt({
    required this.id,
    required this.number,
    required this.factoryId,
    required this.category,
    required this.amount,
    this.notes = '',
    DateTime? date,
  }) : date = date ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'number': number,
    'factoryId': factoryId,
    'category': category.key,
    'amount': amount,
    'notes': notes,
    'date': date.toIso8601String(),
  };

  factory IncomingReceipt.fromJson(Map<String, dynamic> j) => IncomingReceipt(
    id: j['id'] as String? ?? newId(),
    number: (j['number'] as num?)?.toInt() ?? 0,
    factoryId: j['factoryId'] as String? ?? '',
    category: IncomingCategoryInfo.fromKey(j['category'] as String?),
    amount: (j['amount'] as num?)?.toDouble() ?? 0,
    notes: j['notes'] as String? ?? '',
    date: DateTime.tryParse(j['date'] as String? ?? ''),
  );
}

class AppSettings {
  String shopName;
  String shopPhone;
  String shopAddress;
  String botToken;
  String chatId;
  bool sendPdfToTelegram;

  AppSettings({
    this.shopName = 'معمل الشتايكر',
    this.shopPhone = '',
    this.shopAddress = '',
    this.botToken = '',
    this.chatId = '',
    this.sendPdfToTelegram = true,
  });

  bool get telegramReady =>
      botToken.trim().isNotEmpty && chatId.trim().isNotEmpty;

  Map<String, dynamic> toJson() => {
    'shopName': shopName,
    'shopPhone': shopPhone,
    'shopAddress': shopAddress,
    'botToken': botToken,
    'chatId': chatId,
    'sendPdfToTelegram': sendPdfToTelegram,
  };

  factory AppSettings.fromJson(Map<String, dynamic> j) => AppSettings(
    shopName: j['shopName'] as String? ?? 'معمل الشتايكر',
    shopPhone: j['shopPhone'] as String? ?? '',
    shopAddress: j['shopAddress'] as String? ?? '',
    botToken: j['botToken'] as String? ?? '',
    chatId: j['chatId'] as String? ?? '',
    sendPdfToTelegram: j['sendPdfToTelegram'] as bool? ?? true,
  );
}
