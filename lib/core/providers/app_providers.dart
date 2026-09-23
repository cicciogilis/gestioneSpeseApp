import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/month_balance_repository.dart';
import '../../data/repositories/transaction_repository.dart';
import '../../data/services/expense_category_classifier.dart';
import '../../data/services/expense_description_service.dart';
import '../../data/services/receipt_expense_service.dart';
import '../../data/services/receipt_recognition_service.dart';
import '../../data/services/receipt_service.dart';
import '../../domain/models/transaction.dart';
import 'month_balance_provider.dart';
import 'selected_period_provider.dart';

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
    ref.invalidate(monthBalanceProvider);
    ref.invalidate(homeDataProvider);
    await loadTransactions();
  }

  Future<AppTransaction?> deleteTransaction(String id) async {
    final tx = await _repository.getTransactionById(id);
    await _repository.deleteTransaction(id);
    ref.invalidate(monthBalanceProvider);
    ref.invalidate(homeDataProvider);
    await loadTransactions();
    return tx;
  }

  Future<void> restoreTransaction(AppTransaction tx) async {
    await _repository.addTransaction(tx);
    ref.invalidate(monthBalanceProvider);
    ref.invalidate(homeDataProvider);
    await loadTransactions();
  }

  Future<void> deleteFutureRecurrences(String ricorrenzaId) async {
    await _repository.deleteFutureRecurrences(ricorrenzaId);
    ref.invalidate(monthBalanceProvider);
    ref.invalidate(homeDataProvider);
    await loadTransactions();
  }
}

final transactionsProvider = AsyncNotifierProvider<TransactionListNotifier, List<AppTransaction>>(() {
  return TransactionListNotifier();
});

class HomeData {
  final double saldoNetto;
  final double entrate;
  final double uscite;
  final double saldoIniziale;
  final List<AppTransaction> monthlyTransactions;

  const HomeData({
    required this.saldoNetto,
    required this.entrate,
    required this.uscite,
    required this.saldoIniziale,
    required this.monthlyTransactions,
  });
}

class HomeDataNotifier extends AsyncNotifier<HomeData> {
  late TransactionRepository _txRepo;
  late MonthBalanceRepository _balanceRepo;

  @override
  FutureOr<HomeData> build() async {
    _txRepo = ref.watch(transactionRepositoryProvider);
    _balanceRepo = ref.watch(monthBalanceRepositoryProvider);
    final period = ref.watch(selectedPeriodProvider);
    return _fetchHomeData(period.year, period.month);
  }

  Future<HomeData> _fetchHomeData(int year, int month) async {
    final transactions = await _txRepo.getTransactionsForMonth(year, month);

    double totalIncome = 0;
    double totalExpense = 0;
    for (final tx in transactions) {
      if (tx.type == TransactionType.income) {
        totalIncome += tx.amount;
      } else if (tx.type == TransactionType.expense) {
        totalExpense += tx.amount;
      }
    }

    final balance = await _balanceRepo.getMonthBalance(year, month);
    final saldoIniziale = balance?.baselineAmount ?? 0.0;
    final saldoNetto = saldoIniziale + totalIncome - totalExpense;

    return HomeData(
      saldoNetto: saldoNetto,
      entrate: totalIncome,
      uscite: totalExpense,
      saldoIniziale: saldoIniziale,
      monthlyTransactions: transactions,
    );
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final period = ref.read(selectedPeriodProvider);
      return _fetchHomeData(period.year, period.month);
    });
  }
}

final homeDataProvider =
    AsyncNotifierProvider<HomeDataNotifier, HomeData>(() {
  return HomeDataNotifier();
});
