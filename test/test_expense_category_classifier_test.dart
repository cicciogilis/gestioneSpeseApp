import 'package:flutter_test/flutter_test.dart';
import 'package:spesapp/data/services/expense_category_classifier.dart';
import 'package:spesapp/domain/models/scanned_receipt.dart';

void main() {
  group('Test Expense Category Classifier', () {
    late ExpenseCategoryClassifier classifier;

    setUp(() {
      classifier = ExpenseCategoryClassifier();
    });

    // TEST-004: Classify with empty merchant name
    test('TEST-004: classify returns cat_altro for empty merchant', () {
      final result = classifier.classify(
        merchantName: '',
        items: [],
        description: 'Some expense',
      );
      
      expect(result, 'cat_altro');
    });

    // TEST-005: Classify with null description
    test('TEST-005: classify handles null description', () {
      final result = classifier.classify(
        merchantName: 'Unknown Store',
        items: [],
        description: null,
      );
      
      expect(result, 'cat_altro');
    });

    // TEST-006: Classify with items containing specific keywords
    test('TEST-006: classify detects category from items', () {
      final items = [
        ScannedReceiptItem(
          description: 'Bread',
          quantity: 1,
          unitPrice: 2.50,
          totalPrice: 2.50,
        ),
      ];
      
      final result = classifier.classify(
        merchantName: 'Grocery Store',
        items: items,
        description: 'Weekly shopping',
      );
      
      expect(result, 'cat_alimentari');
    });

    // TEST: Classify with null merchant name
    test('TEST: classify handles null merchant name', () {
      final result = classifier.classify(
        merchantName: null,
        items: [],
        description: 'Generic expense',
      );
      
      expect(result, 'cat_altro');
    });

    // TEST: Classify with empty items list
    test('TEST: classify returns default category for empty items', () {
      final result = classifier.classify(
        merchantName: 'Some Store',
        items: [],
        description: 'Purchase',
      );
      
      expect(result, 'cat_altro');
    });

    // TEST: Classify with all parameters null/empty
    test('TEST: classify returns cat_altro for all null parameters', () {
      final result = classifier.classify(
        merchantName: null,
        items: [],
        description: null,
      );
      
      expect(result, 'cat_altro');
    });
  });
}



