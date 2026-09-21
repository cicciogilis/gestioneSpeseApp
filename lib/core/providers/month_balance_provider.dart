import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/month_balance_repository.dart';
import '../../data/repositories/transaction_repository.dart';
import '../../domain/models/month_balance.dart';
import 'selected_period_provider.dart';

final monthBalanceRepositoryProvider =
    Provider<MonthBalanceRepository>((ref) {
  return MonthBalanceRepositoryImpl(
    txRepo: TransactionRepository(),
  );
});

final monthBalanceProvider = FutureProvider.autoDispose<MonthBalance?>((ref) {
  final repo = ref.watch(monthBalanceRepositoryProvider);
  final period = ref.watch(selectedPeriodProvider);
  return repo.getMonthBalance(period.year, period.month);
});

final allMonthBalancesProvider =
    FutureProvider.autoDispose<Map<String, MonthBalance>>((ref) async {
  final repo = ref.watch(monthBalanceRepositoryProvider);
  return repo.getAllBalances();
});
