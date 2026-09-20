import 'package:flutter_riverpod/legacy.dart';

class SelectedPeriod {
  final int year;
  final int month;

  const SelectedPeriod({required this.year, required this.month});

  SelectedPeriod copyWith({int? year, int? month}) =>
      SelectedPeriod(year: year ?? this.year, month: month ?? this.month);

  @override
  String toString() {
    const months = [
      'Gennaio', 'Febbraio', 'Marzo', 'Aprile', 'Maggio', 'Giugno',
      'Luglio', 'Agosto', 'Settembre', 'Ottobre', 'Novembre', 'Dicembre'
    ];
    return '${months[month - 1]} $year';
  }
}

class SelectedPeriodNotifier extends StateNotifier<SelectedPeriod> {
  SelectedPeriodNotifier()
      : super(SelectedPeriod(
          year: DateTime.now().year,
          month: DateTime.now().month,
        ));

  void setPeriod(int year, int month) {
    state = SelectedPeriod(year: year, month: month);
  }
}

final selectedPeriodProvider =
    StateNotifierProvider<SelectedPeriodNotifier, SelectedPeriod>(
  (ref) => SelectedPeriodNotifier(),
);
