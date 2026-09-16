enum TransactionType { income, expense }
enum PaymentMethod { cash, card, transfer, other }
enum Recurrence { none, daily, weekly, monthly, yearly }

extension RecurrenceX on Recurrence {
  bool get isRecurring => this != Recurrence.none;

  /// Data della prossima occorrenza dopo [from], secondo la frequenza.
  DateTime nextAfter(DateTime from) {
    switch (this) {
      case Recurrence.daily:
        return from.add(const Duration(days: 1));
      case Recurrence.weekly:
        return from.add(const Duration(days: 7));
      case Recurrence.monthly:
        var m = from.month + 1;
        var y = from.year;
        if (m > 12) {
          m = 1;
          y += 1;
        }
        final lastDay = DateTime(y, m + 1, 0).day;
        return DateTime(y, m, from.day > lastDay ? lastDay : from.day);
      case Recurrence.yearly:
        final isLeapDay = from.month == 2 && from.day == 29;
        final isLeapYear = (from.year + 1) % 4 == 0 && ((from.year + 1) % 100 != 0 || (from.year + 1) % 400 == 0);
        return DateTime(from.year + 1, from.month, isLeapDay && !isLeapYear ? 28 : from.day);
      case Recurrence.none:
        return from;
    }
  }
}

class AppTransaction {
  final String? id;
  final double amount;
  final TransactionType type;
  final String categoryId;
  final PaymentMethod method;
  final DateTime date;
  final String? description;
  final String? aiSummary;
  final Recurrence recurrence;

  const AppTransaction({
    this.id,
    required this.amount,
    required this.type,
    required this.categoryId,
    required this.method,
    required this.date,
    this.description,
    this.aiSummary,
    this.recurrence = Recurrence.none,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'amount': amount,
      'type': type.name.toUpperCase(),
      'category_id': categoryId,
      'method': method.name.toUpperCase(),
      'date': date.toIso8601String().split('T')[0],
      'description': description,
      'ai_summary': aiSummary,
      'recurrence': recurrence.name.toUpperCase(),
    };
  }

  factory AppTransaction.fromMap(Map<String, dynamic> map) {
    return AppTransaction(
      id: map['id'],
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      type: TransactionType.values.firstWhere(
        (e) => e.name.toUpperCase() == map['type'],
        orElse: () => TransactionType.expense,
      ),
      categoryId: map['category_id'] ?? '',
      method: PaymentMethod.values.firstWhere(
        (e) => e.name.toUpperCase() == map['method'],
        orElse: () => PaymentMethod.other,
      ),
      date: DateTime.tryParse(map['date'] ?? '') ?? DateTime.now(),
      description: map['description'],
      aiSummary: map['ai_summary'],
      recurrence: Recurrence.values.firstWhere(
        (e) => e.name.toUpperCase() == map['recurrence'],
        orElse: () => Recurrence.none,
      ),
    );
  }
}
