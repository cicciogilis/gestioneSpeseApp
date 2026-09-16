import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/transaction_repository.dart';
import '../../domain/models/transaction.dart';

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  return TransactionRepository();
});

class TransactionListNotifier extends AsyncNotifier<List<AppTransaction>> {
  late TransactionRepository _repository;

  @override
  FutureOr<List<AppTransaction>> build() async {
    _repository = ref.watch(transactionRepositoryProvider);
    return _repository.getTransactions();
  }

  Future<void> loadTransactions() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _repository.getTransactions());
  }

  Future<void> addTransaction(AppTransaction tx) async {
    await _repository.addTransaction(tx);
    await loadTransactions();
  }
}

final transactionsProvider = AsyncNotifierProvider<TransactionListNotifier, List<AppTransaction>>(() {
  return TransactionListNotifier();
});
