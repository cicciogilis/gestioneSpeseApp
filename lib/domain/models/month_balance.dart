class MonthBalance {
  final int year;
  final int month;
  final String baselineType;
  final DateTime baselineDate;
  final double baselineAmount;

  const MonthBalance({
    required this.year,
    required this.month,
    this.baselineType = 'month_start',
    required this.baselineDate,
    required this.baselineAmount,
  });

  static const String baselineMonthStart = 'month_start';
  static const String baselineCurrentDay = 'current_day';

  bool get isCurrentDay => baselineType == baselineCurrentDay;

  MonthBalance copyWith({
    int? year,
    int? month,
    String? baselineType,
    DateTime? baselineDate,
    double? baselineAmount,
  }) {
    return MonthBalance(
      year: year ?? this.year,
      month: month ?? this.month,
      baselineType: baselineType ?? this.baselineType,
      baselineDate: baselineDate ?? this.baselineDate,
      baselineAmount: baselineAmount ?? this.baselineAmount,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'year': year,
      'month': month,
      'baseline_type': baselineType,
      'baseline_date': baselineDate.toIso8601String().split('T').first,
      'baseline_amount': baselineAmount,
    };
  }

  factory MonthBalance.fromMap(Map<String, dynamic> map) {
    return MonthBalance(
      year: map['year'] as int,
      month: map['month'] as int,
      baselineType: map['baseline_type'] as String? ?? baselineMonthStart,
      baselineDate: DateTime.tryParse(map['baseline_date'] as String? ?? '') ??
          DateTime(map['year'] as int, map['month'] as int, 1),
      baselineAmount: (map['baseline_amount'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class MonthTotals {
  final double income;
  final double expense;
  final double saldoNetto;
  final double baselineAmount;
  final DateTime baselineDate;
  final String baselineType;

  const MonthTotals({
    required this.income,
    required this.expense,
    required this.saldoNetto,
    required this.baselineAmount,
    required this.baselineDate,
    required this.baselineType,
  });
}

extension MonthBalanceExtension on MonthBalance {
  DateTime get startDate {
    if (baselineType == MonthBalance.baselineCurrentDay) {
      return baselineDate;
    }
    return DateTime(year, month, 1);
  }
}
