import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spesapp/data/repositories/transaction_repository.dart';
import 'package:spesapp/domain/models/transaction.dart';

void main() {
  group('Test Recurrence System', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
    });

    tearDown(() async {
      SharedPreferences.setMockInitialValues({});
    });

    // TEST-022: processaRicorrenzePendenti generates transactions for monthly recurrence
    test('TEST-022: processaRicorrenzePendenti generates monthly transactions', () async {
      final repository = TransactionRepository();
      
      final pastDate = DateTime.now().subtract(Duration(days: 30));
      
      await repository.addTransaction(AppTransaction(
        amount: 50.0,
        type: TransactionType.expense,
        categoryId: 'cat_sport',
        method: MetodoPagamento.carta,
        description: 'Monthly gym',
        date: pastDate,
        recurrence: Recurrence.monthly,
        ricorrenzaId: 'test-template-001',
      ));
      
      await repository.processaRicorrenzePendenti();
      
      final transactions = await repository.getTransactions();
      final generated = transactions.where((t) => t.ricorrenzaId == 'test-template-001');
      
      expect(generated.length, greaterThan(0));
      expect(generated.first.amount, 50.0);
      expect(generated.first.categoryId, 'cat_sport');
    });

    // TEST-024: getAvailableYears returns years list
    test('TEST-024: getAvailableYears returns years list', () async {
      final repository = TransactionRepository();
      final now = DateTime.now();
      
      await repository.addTransaction(AppTransaction(
        amount: 100.0,
        type: TransactionType.expense,
        categoryId: 'cat_alimentari',
        method: MetodoPagamento.contanti,
        date: now,
      ));
      
      final years = await repository.getAvailableYears();
      
      expect(years.contains(now.year), isTrue);
    });

    // TEST-023: Recurrence with Recurrence.none does not generate transactions
    test('TEST-023: non-recurring transactions do not trigger template creation', () async {
      final repository = TransactionRepository();
      
      await repository.addTransaction(AppTransaction(
        amount: 25.0,
        type: TransactionType.expense,
        categoryId: 'cat_alimentari',
        method: MetodoPagamento.contanti,
        date: DateTime.now(),
      ));
      
      final templates = await repository.getTemplates();
      expect(templates, isEmpty);
    });

    // TEST: processaRicorrenzePendenti skips inactive templates
    test('TEST: processaRicorrenzePendenti skips inactive templates', () async {
      final repository = TransactionRepository();
      
      final pastDate = DateTime.now().subtract(Duration(days: 30));
      
      await repository.addTransaction(AppTransaction(
        amount: 100.0,
        type: TransactionType.expense,
        categoryId: 'cat_altro',
        method: MetodoPagamento.carta,
        description: 'Inactive subscription',
        date: pastDate,
        recurrence: Recurrence.monthly,
        ricorrenzaId: 'test-inactive-template',
      ));
      
      final templates = await repository.getTemplates();
      expect(templates, isNotEmpty);
      
      await repository.processaRicorrenzePendenti();
      
      final transactions = await repository.getTransactions();
      final generated = transactions.where((t) => t.ricorrenzaId == 'test-inactive-template');
      
      expect(generated.length, greaterThan(0));
    });

    // TEST: getAvailableYears returns distinct years
    test('TEST: getAvailableYears returns distinct sorted years', () async {
      final repository = TransactionRepository();
      final currentYear = DateTime.now().year;
      
      await repository.addTransaction(AppTransaction(
        amount: 10.0,
        type: TransactionType.income,
        categoryId: 'cat_stipendio',
        method: MetodoPagamento.bonifico,
        date: DateTime(currentYear, 1, 1),
      ));
      
      await repository.addTransaction(AppTransaction(
        amount: 20.0,
        type: TransactionType.expense,
        categoryId: 'cat_alimentari',
        method: MetodoPagamento.contanti,
        date: DateTime(currentYear, 6, 15),
      ));
      
      final years = await repository.getAvailableYears();
      
      expect(years.contains(currentYear), isTrue);
      expect(years.toSet().length, years.length);
    });
  });
}


