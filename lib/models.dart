// نماذج البيانات: الخلفات، المنتجات، الوصولات، الدفعات.

String newId() =>
    DateTime.now().microsecondsSinceEpoch.toRadixString(36) +
    (DateTime.now().hashCode & 0xfff).toRadixString(36);

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

  Product({
    required this.id,
    required this.name,
    this.unit = 'قطعة',
    this.price = 0,
    this.active = true,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'unit': unit,
    'price': price,
    'active': active,
  };

  factory Product.fromJson(Map<String, dynamic> j) => Product(
    id: j['id'] as String,
    name: j['name'] as String? ?? '',
    unit: j['unit'] as String? ?? 'قطعة',
    price: (j['price'] as num?)?.toDouble() ?? 0,
    active: j['active'] as bool? ?? true,
  );
}

/// سطر في الوصل. السعر يُحفظ وقت إنشاء الوصل حتى لا يتأثر بتغيير الأسعار لاحقاً.
class ReceiptItem {
  final String productId;
  final String productName;
  final String unit;
  final double qty;
  final double unitPrice;

  ReceiptItem({
    required this.productId,
    required this.productName,
    required this.unit,
    required this.qty,
    required this.unitPrice,
  });

  double get total => qty * unitPrice;

  Map<String, dynamic> toJson() => {
    'productId': productId,
    'productName': productName,
    'unit': unit,
    'qty': qty,
    'unitPrice': unitPrice,
  };

  factory ReceiptItem.fromJson(Map<String, dynamic> j) => ReceiptItem(
    productId: j['productId'] as String? ?? '',
    productName: j['productName'] as String? ?? '',
    unit: j['unit'] as String? ?? '',
    qty: (j['qty'] as num?)?.toDouble() ?? 0,
    unitPrice: (j['unitPrice'] as num?)?.toDouble() ?? 0,
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

  Receipt({
    required this.id,
    required this.number,
    required this.customerId,
    required this.date,
    required this.items,
    this.paid = 0,
    this.notes = '',
  });

  double get total => items.fold(0, (s, i) => s + i.total);
  double get remaining => total - paid;

  Map<String, dynamic> toJson() => {
    'id': id,
    'number': number,
    'customerId': customerId,
    'date': date.toIso8601String(),
    'items': items.map((e) => e.toJson()).toList(),
    'paid': paid,
    'notes': notes,
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
