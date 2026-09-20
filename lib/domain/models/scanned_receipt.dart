import 'transaction.dart';

enum ReceiptStatus { draft, pending, confirmed, rejected }

class ScannedReceiptItem {
  final String description;
  final double? quantity;
  final double? unitPrice;
  final double? totalPrice;

  const ScannedReceiptItem({
    required this.description,
    this.quantity,
    this.unitPrice,
    this.totalPrice,
  });

  Map<String, dynamic> toMap() {
    return {
      'description': description,
      'quantity': quantity,
      'unit_price': unitPrice,
      'total_price': totalPrice,
    };
  }

  factory ScannedReceiptItem.fromMap(Map<String, dynamic> map) {
    return ScannedReceiptItem(
      description: map['description'] ?? '',
      quantity: (map['quantity'] as num?)?.toDouble(),
      unitPrice: (map['unit_price'] as num?)?.toDouble(),
      totalPrice: (map['total_price'] as num?)?.toDouble(),
    );
  }
}

class ScannedReceipt {
  final String? id;
  final String imagePath;
  final String? merchantName;
  final DateTime? purchaseDate;
  final double? totalAmount;
  final List<ScannedReceiptItem> items;
  final String rawText;
  final String? categoryId;
  final MetodoPagamento? method;
  final String? description;
  final ReceiptStatus status;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const ScannedReceipt({
    this.id,
    required this.imagePath,
    this.merchantName,
    this.purchaseDate,
    this.totalAmount,
    required this.items,
    required this.rawText,
    this.categoryId,
    this.method,
    this.description,
    this.status = ReceiptStatus.draft,
    required this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'image_path': imagePath,
      'merchant_name': merchantName,
      'purchase_date': purchaseDate?.toIso8601String(),
      'total_amount': totalAmount,
      'items': items.map((i) => i.toMap()).toList(),
      'raw_text': rawText,
      'category_id': categoryId,
      'method': method?.name.toUpperCase(),
      'description': description,
      'status': status.name.toUpperCase(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  factory ScannedReceipt.fromMap(Map<String, dynamic> map) {
    return ScannedReceipt(
      id: map['id'],
      imagePath: map['image_path'] ?? '',
      merchantName: map['merchant_name'],
      purchaseDate: map['purchase_date'] != null ? DateTime.tryParse(map['purchase_date']) : null,
      totalAmount: (map['total_amount'] as num?)?.toDouble(),
      items: (map['items'] as List<dynamic>? ?? [])
          .map((e) => ScannedReceiptItem.fromMap(e as Map<String, dynamic>))
          .toList(),
      rawText: map['raw_text'] ?? '',
      categoryId: map['category_id'],
      method: map['method'] != null ? _parseMethod(map['method']) : null,
      description: map['description'],
      status: ReceiptStatus.values.firstWhere(
        (e) => e.name.toUpperCase() == map['status'],
        orElse: () => ReceiptStatus.draft,
      ),
      createdAt: DateTime.tryParse(map['created_at'] ?? '') ?? DateTime.now(),
      updatedAt: map['updated_at'] != null ? DateTime.tryParse(map['updated_at']) : null,
    );
  }

  static MetodoPagamento? _parseMethod(dynamic value) {
    if (value == null) return null;
    final upper = (value as String).toUpperCase();
    switch (upper) {
      case 'CONTANTI':
      case 'CASH':
        return MetodoPagamento.contanti;
      case 'CARTA':
      case 'CARD':
        return MetodoPagamento.carta;
      case 'BONIFICO':
      case 'TRANSFER':
        return MetodoPagamento.bonifico;
      case 'PAYPAL':
        return MetodoPagamento.paypal;
      case 'SATISPAY':
        return MetodoPagamento.satispay;
      default:
        return null;
    }
  }

  ScannedReceipt copyWith({
    String? id,
    String? imagePath,
    String? merchantName,
    DateTime? purchaseDate,
    double? totalAmount,
    List<ScannedReceiptItem>? items,
    String? rawText,
    String? categoryId,
    MetodoPagamento? method,
    String? description,
    ReceiptStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ScannedReceipt(
      id: id ?? this.id,
      imagePath: imagePath ?? this.imagePath,
      merchantName: merchantName ?? this.merchantName,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      totalAmount: totalAmount ?? this.totalAmount,
      items: items ?? this.items,
      rawText: rawText ?? this.rawText,
      categoryId: categoryId ?? this.categoryId,
      method: method ?? this.method,
      description: description ?? this.description,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool get isComplete =>
      totalAmount != null &&
      purchaseDate != null &&
      merchantName != null &&
      categoryId != null &&
      method != null;

  double get confidence {
    int filled = 0;
    if (totalAmount != null) filled++;
    if (purchaseDate != null) filled++;
    if (merchantName != null) filled++;
    if (categoryId != null) filled++;
    if (method != null) filled++;
    return filled / 5.0;
  }
}