import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spesapp/data/repositories/transaction_repository.dart';
import 'package:spesapp/data/services/expense_category_classifier.dart';
import 'package:spesapp/domain/models/scanned_receipt.dart';
import 'package:spesapp/domain/models/expense_draft.dart';
import 'package:spesapp/domain/models/transaction.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Test Boundary Tests', () {
    // TEST-BOUND-001: ExpenseDraft with amount = 0.00
    test('TEST-BOUND-001: ExpenseDraft with zero amount', () {
      final draft = ExpenseDraft(
        description: 'Free item',
        amount: 0.0,
        date: DateTime(2026, 1, 15),
        imagePath: '/path/to/image.jpg',
      );

      expect(draft.amount, 0.0);
    });

    // TEST-BOUND-002: ExpenseDraft with very large amount
    test('TEST-BOUND-002: ExpenseDraft with very large amount', () {
      final draft = ExpenseDraft(
        description: 'Expensive purchase',
        amount: 999999999.99,
        date: DateTime(2026, 1, 15),
        imagePath: '/path/to/image.jpg',
      );

      expect(draft.amount, 999999999.99);
    });

    // TEST-BOUND-003: ExpenseDraft with empty description
    test('TEST-BOUND-003: ExpenseDraft with empty description', () {
      final draft = ExpenseDraft(
        description: '',
        amount: 10.0,
        date: DateTime(2026, 1, 15),
        imagePath: '/path/to/image.jpg',
      );

      expect(draft.description, '');
    });

    // TEST-BOUND-004: ExpenseDraft with negative amount
    test('TEST-BOUND-004: ExpenseDraft with negative amount', () {
      final draft = ExpenseDraft(
        description: 'Refund',
        amount: -50.0,
        date: DateTime(2026, 1, 15),
        imagePath: '/path/to/image.jpg',
      );

      expect(draft.amount, -50.0);
    });

    // TEST-BOUND-005: Classifier with very long merchant name
    test('TEST-BOUND-005: Classifier handles very long merchant name', () {
      final classifier = ExpenseCategoryClassifier();

      final result = classifier.classify(
        merchantName: 'A' * 1000,
        items: [],
        description: null,
      );

      expect(result, 'cat_altro');
    });

    // TEST-BOUND-006: Classifier with very long description
    test('TEST-BOUND-006: Classifier handles very long description', () {
      final classifier = ExpenseCategoryClassifier();

      final result = classifier.classify(
        merchantName: null,
        items: [],
        description: 'X' * 5000,
      );

      expect(result, 'cat_altro');
    });

    // TEST-BOUND-007: Classifier with many items (stress test)
    test('TEST-BOUND-007: Classifier handles large items list', () {
      final classifier = ExpenseCategoryClassifier();

      final items = List.generate(100, (i) => ScannedReceiptItem(
        description: 'Item $i',
        quantity: 1,
        unitPrice: 1.0,
        totalPrice: 1.0,
      ));

      final result = classifier.classify(
        merchantName: 'Generic Store',
        items: items,
        description: 'Bulk purchase',
      );

      expect(result, 'cat_altro');
    });

    // TEST-BOUND-008: TransactionRepository deleteTransaction handles non-existent ID
    test('TEST-BOUND-008: deleteTransaction handles non-existent ID gracefully', () async {
      final repository = TransactionRepository();

      await repository.addTransaction(AppTransaction(
        amount: 100.0,
        type: TransactionType.expense,
        categoryId: 'cat_alimentari',
        method: MetodoPagamento.contanti,
        date: DateTime(2026, 1, 15),
      ));

      final transactions = await repository.getTransactions();
      final id = transactions.first.id;

      await repository.deleteTransaction('non-existent-id-999');

      final afterDelete = await repository.getTransactions();
      expect(afterDelete.length, 1);
      expect(afterDelete[0].id, id);
    });

    // TEST-BOUND-009: Recurrence.yearly handles leap year edge case
    test('TEST-BOUND-009: Recurrence.yearly handles leap year correctly', () {
      final leapYearDate = DateTime(2024, 2, 29);

      final result = Recurrence.yearly.nextAfter(leapYearDate);

      expect(result.isAfter(leapYearDate), true);
      expect(result.year, 2025);
    });

    // TEST-BOUND-010: TransactionRepository handles transactions at month boundaries
    test('TEST-BOUND-010: TransactionRepository handles month boundary dates', () async {
      final repository = TransactionRepository();

      final lastDayJan = DateTime(2026, 1, 31);
      final firstDayFeb = DateTime(2026, 2, 1);

      await repository.addTransaction(AppTransaction(
        amount: 100.0,
        type: TransactionType.expense,
        categoryId: 'cat_alimentari',
        method: MetodoPagamento.contanti,
        date: lastDayJan,
      ));

      await repository.addTransaction(AppTransaction(
        amount: 200.0,
        type: TransactionType.income,
        categoryId: 'cat_stipendio',
        method: MetodoPagamento.bonifico,
        date: firstDayFeb,
      ));

      final transactions = await repository.getTransactions();

      expect(transactions.length, 2);

      final years = await repository.getAvailableYears();
      expect(years.contains(2026), isTrue);
    });
  });
}


