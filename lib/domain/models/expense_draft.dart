import 'transaction.dart';

class ExpenseDraft {
  final String description;
  final double? amount;
  final DateTime? date;
  final String? category;
  final TransactionType? type;
  final String? merchantName;
  final String imagePath;
  final MetodoPagamento? method;

  const ExpenseDraft({
    required this.description,
    this.amount,
    this.date,
    this.category,
    this.type,
    this.merchantName,
    required this.imagePath,
    this.method,
  });

  Map<String, dynamic> toMap() {
    return {
      'description': description,
      'amount': amount,
      'date': date?.toIso8601String().split('T').first,
      'category': category,
      'type': type?.name,
      'merchantName': merchantName,
      'imagePath': imagePath,
      'method': method?.name,
    };
  }

  factory ExpenseDraft.fromMap(Map<String, dynamic> map) {
    return ExpenseDraft(
      description: map['description'] ?? '',
      amount: (map['amount'] as num?)?.toDouble(),
      date: map['date'] != null ? DateTime.tryParse(map['date']) : null,
      category: map['category'],
      type: map['type'] != null 
          ? TransactionType.values.firstWhere(
              (e) => e.name == map['type'],
              orElse: () => TransactionType.expense,
            )
          : null,
      merchantName: map['merchantName'],
      imagePath: map['imagePath'] ?? '',
      method: map['method'] != null 
          ? MetodoPagamento.values.firstWhere(
              (e) => e.name == map['method'],
              orElse: () => MetodoPagamento.contanti,
            )
          : null,
    );
  }
}