import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/transaction_repository.dart';
import '../../data/services/expense_category_classifier.dart';
import '../../data/services/expense_description_service.dart';
import '../../data/services/receipt_expense_service.dart';
import '../../data/services/receipt_recognition_service.dart';
import '../../data/services/receipt_service.dart';
import '../../domain/models/transaction.dart';

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  return TransactionRepository();
});

final receiptRecognitionServiceProvider = Provider<ReceiptRecognitionService>((ref) {
  return ReceiptRecognitionService();
});

final expenseDescriptionServiceProvider = Provider<ExpenseDescriptionService>((ref) {
  const apiKey = String.fromEnvironment('LLM_API_KEY');
  return ExpenseDescriptionService(apiKey: apiKey);
});

final expenseCategoryClassifierProvider = Provider<ExpenseCategoryClassifier>((ref) {
  return ExpenseCategoryClassifier();
});

final receiptExpenseServiceProvider = Provider<ReceiptExpenseService>((ref) {
  return ReceiptExpenseService(
    recognitionService: ref.read(receiptRecognitionServiceProvider),
    descriptionService: ref.read(expenseDescriptionServiceProvider),
    classifier: ref.read(expenseCategoryClassifierProvider),
  );
});

final receiptServiceProvider = Provider<ReceiptService>((ref) {
  return ReceiptService(ref.read(receiptRecognitionServiceProvider));
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

  Future<void> deleteTransaction(String id) async {
    await _repository.deleteTransaction(id);
    await loadTransactions();
  }

  Future<void> deleteFutureRecurrences(String ricorrenzaId) async {
    await _repository.deleteFutureRecurrences(ricorrenzaId);
    await loadTransactions();
  }
}

final transactionsProvider = AsyncNotifierProvider<TransactionListNotifier, List<AppTransaction>>(() {
  return TransactionListNotifier();
});
