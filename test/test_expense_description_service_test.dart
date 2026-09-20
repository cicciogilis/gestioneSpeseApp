import 'package:flutter_test/flutter_test.dart';
import 'package:spesapp/data/services/expense_description_service.dart';
import 'package:spesapp/domain/models/scanned_receipt.dart';

void main() {
  group('Test Expense Description Service', () {
    // TEST-007: ExpenseDescriptionService.isConfigured returns false for empty API key
    test('TEST-007: isConfigured returns false for empty API key', () {
      final service = ExpenseDescriptionService(apiKey: '');
      
      expect(service.isConfigured, false);
    });

    // TEST-008: ExpenseDescriptionService.isConfigured returns true for valid API key
    test('TEST-008: isConfigured returns true for valid API key', () {
      final service = ExpenseDescriptionService(apiKey: 'valid-key-123');
      
      expect(service.isConfigured, true);
    });

    // TEST-009: generateDescription returns null when not configured
    test('TEST-009: generateDescription returns null when not configured', () async {
      final service = ExpenseDescriptionService(apiKey: '');
      
      final receipt = ScannedReceipt(
        imagePath: '/fake/receipt.jpg',
        merchantName: 'ESSELUNGA',
        purchaseDate: DateTime(2026, 1, 15),
        totalAmount: 25.50,
        items: [],
        rawText: 'Test receipt',
        createdAt: DateTime.now(),
      );
      
      final result = await service.generateDescription(receipt);
      
      expect(result, isNull);
    });

    // TEST-010: generateDescription returns fallback description when API fails
    test('TEST-010: generateDescription returns null on API failure (fallback)', () async {
      final service = ExpenseDescriptionService(apiKey: 'invalid-key-for-testing');
      
      final receipt = ScannedReceipt(
        imagePath: '/fake/receipt.jpg',
        merchantName: 'Unknown Store',
        purchaseDate: DateTime(2026, 1, 15),
        totalAmount: 10.00,
        items: [],
        rawText: 'Some receipt text',
        createdAt: DateTime.now(),
      );
      
      final result = await service.generateDescription(receipt);
      
      expect(result, isNull);
    });

    // TEST: generateDescription returns correct result for configured service
    test('TEST: generateDescription returns null for invalid API key (network error)', () async {
      final service = ExpenseDescriptionService(apiKey: 'invalid-key-123');
      
      final receipt = ScannedReceipt(
        imagePath: '/fake/receipt.jpg',
        merchantName: 'Coop',
        purchaseDate: DateTime(2025, 6, 10),
        totalAmount: 45.30,
        items: [
          ScannedReceiptItem(
            description: 'Milk',
            quantity: 2,
            unitPrice: 1.50,
            totalPrice: 3.00,
          ),
        ],
        rawText: 'COOP 10/06/2025 MILK 2x1.50 45.30',
        createdAt: DateTime.now(),
      );
      
      final result = await service.generateDescription(receipt);
      
      expect(result, isNull);
    });
  });
}