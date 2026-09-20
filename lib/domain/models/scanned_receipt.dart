import 'transaction.dart';

enum ReceiptStatus { draft, pending, confirmed, rejected }

class ScannedReceipt {
  final String? id;
  final String imagePath;
  final String? extractedText;
  final double? amount;
  final DateTime? date;
  final String? merchant;
  final String? categoryId;
  final MetodoPagamento? method;
  final String? description;
  final ReceiptStatus status;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const ScannedReceipt({
    this.id,
    required this.imagePath,
    this.extractedText,
    this.amount,
    this.date,
    this.merchant,
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
      'extracted_text': extractedText,
      'amount': amount,
      'date': date?.toIso8601String(),
      'merchant': merchant,
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
      extractedText: map['extracted_text'],
      amount: (map['amount'] as num?)?.toDouble(),
      date: map['date'] != null ? DateTime.tryParse(map['date']) : null,
      merchant: map['merchant'],
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
    String? extractedText,
    double? amount,
    DateTime? date,
    String? merchant,
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
      extractedText: extractedText ?? this.extractedText,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      merchant: merchant ?? this.merchant,
      categoryId: categoryId ?? this.categoryId,
      method: method ?? this.method,
      description: description ?? this.description,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool get isComplete =>
      amount != null &&
      date != null &&
      merchant != null &&
      categoryId != null &&
      method != null;

  double get confidence {
    int filled = 0;
    if (amount != null) filled++;
    if (date != null) filled++;
    if (merchant != null) filled++;
    if (categoryId != null) filled++;
    if (method != null) filled++;
    return filled / 5.0;
  }
}