import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:spesapp/data/services/receipt_expense_service.dart';
import 'package:spesapp/data/services/receipt_recognition_service.dart';
import 'package:spesapp/data/services/expense_description_service.dart';
import 'package:spesapp/data/services/expense_category_classifier.dart';
import 'package:spesapp/domain/models/expense_draft.dart';
import 'package:spesapp/domain/models/scanned_receipt.dart';

void main() {
  group('Test Receipt Expense Service (Orchestrator)', () {
    // TEST-020: ReceiptExpenseService.processReceipt orchestrator
    test('TEST-020: ReceiptExpenseService orchestrator pipeline', () async {
      final service = ReceiptExpenseService(
        recognitionService: _MockReceiptRecognitionService(),
        descriptionService: ExpenseDescriptionService(apiKey: ''),
        classifier: ExpenseCategoryClassifier(),
      );
      
      final tempDir = await Directory.systemTemp.createTemp('spesapp_test_');
      final testFile = File('${tempDir.path}/spesapp_test_receipt.jpg');
      await testFile.writeAsBytes([1, 2, 3]);
      
      final result = await service.processReceipt(testFile.path);
      
      expect(result, isA<ExpenseDraft>());
      expect(result.description, isNotEmpty);
      expect(result.amount, 25.50);
      
      await tempDir.delete(recursive: true);
    });

    // TEST-035: Integration test - ReceiptService temp file management
    test('TEST-035: ReceiptService integration temp file cleanup', () async {
      final service = ReceiptExpenseService(
        recognitionService: _MockReceiptRecognitionService(),
        descriptionService: ExpenseDescriptionService(apiKey: ''),
        classifier: ExpenseCategoryClassifier(),
      );
      
      final tempDir = await Directory.systemTemp.createTemp('spesapp_test_');
      final testFile = File('${tempDir.path}/spesapp_integration_test.jpg');
      await testFile.writeAsBytes([1, 2, 3]);
      
      expect(await testFile.exists(), true);
      
      final result = await service.processReceipt(testFile.path);
      
      expect(result, isA<ExpenseDraft>());
      expect(await testFile.exists(), false);
      
      await tempDir.delete(recursive: true);
    });

    // TEST: Orchestrator handles errors from recognition service
    test('TEST: Orchestrator handles recognition errors', () async {
      final service = ReceiptExpenseService(
        recognitionService: _ErrorReceiptRecognitionService(),
        descriptionService: ExpenseDescriptionService(apiKey: 'test-api-key'),
        classifier: ExpenseCategoryClassifier(),
      );
      
      final tempDir = await Directory.systemTemp.createTemp('spesapp_test_');
      final testFile = File('${tempDir.path}/spesapp_error_test.jpg');
      await testFile.writeAsBytes([1, 2, 3]);
      
      expect(
        () => service.processReceipt(testFile.path),
        throwsA(isA<Exception>()),
      );
      
      await tempDir.delete(recursive: true);
    });

    // TEST: Orchestrator with disabled description service (fallback)
    test('TEST: Orchestrator uses fallback when description service not configured', () async {
      final service = ReceiptExpenseService(
        recognitionService: _MockReceiptRecognitionService(),
        descriptionService: ExpenseDescriptionService(apiKey: ''),
        classifier: ExpenseCategoryClassifier(),
      );
      
      final tempDir = await Directory.systemTemp.createTemp('spesapp_test_');
      final testFile = File('${tempDir.path}/spesapp_fallback_test.jpg');
      await testFile.writeAsBytes([1, 2, 3]);
      
      final result = await service.processReceipt(testFile.path);
      
      expect(result, isA<ExpenseDraft>());
      expect(result.description, isNotEmpty);
      
      await tempDir.delete(recursive: true);
    });
  });
}

// Mock receipt recognition service - extends the real class with a no-op recognizer
class _MockReceiptRecognitionService extends ReceiptRecognitionService {
  _MockReceiptRecognitionService() : super(recognizer: null);

  @override
  Future<ScannedReceipt> processFilePath(String imagePath) async {
    return ScannedReceipt(
      imagePath: imagePath,
      merchantName: 'Carrefour',
      purchaseDate: DateTime(2026, 1, 15),
      totalAmount: 25.50,
      items: [],
      rawText: 'Carrefour Data 2026-01-15 Totale 25.50',
      status: ReceiptStatus.draft,
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<void> close() async {}
}

// Error receipt recognition service - throws exception for error testing
class _ErrorReceiptRecognitionService extends ReceiptRecognitionService {
  _ErrorReceiptRecognitionService() : super(recognizer: null);

  @override
  Future<ScannedReceipt> processFilePath(String imagePath) async {
    throw Exception('OCR recognition failed');
  }

  @override
  Future<void> close() async {}
}
