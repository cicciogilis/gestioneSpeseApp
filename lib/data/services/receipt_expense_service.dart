import 'dart:async';

import '../../domain/models/expense_draft.dart';

import 'expense_category_classifier.dart';
import 'expense_description_service.dart';
import 'receipt_recognition_service.dart';
import 'temp_file_service.dart';

class ReceiptExpenseService {
  final ReceiptRecognitionService _recognitionService;
  final ExpenseDescriptionService _descriptionService;
  final ExpenseCategoryClassifier _classifier;
  final TempFileService _tempFileService = TempFileService();

  ReceiptExpenseService({
    required ReceiptRecognitionService recognitionService,
    required ExpenseDescriptionService descriptionService,
    required ExpenseCategoryClassifier classifier,
  })  : _recognitionService = recognitionService,
        _descriptionService = descriptionService,
        _classifier = classifier;

  /// Pipeline completa: ImagePath ? ReceiptRecognition ? Gemini ? Classifier ? ExpenseDraft
  Future<ExpenseDraft> processReceipt(String imagePath) async {
    try {
      // Step 1: Receipt recognition (OCR + structured parsing)
      final scannedReceipt = await _recognitionService.processFilePath(imagePath);
      
      // Step 2: Generate description via Gemini (with fallback)
      String? description;
      if (_descriptionService.isConfigured) {
        description = await _descriptionService.generateDescription(scannedReceipt)
            .timeout(const Duration(seconds: 10), onTimeout: () {
          // Fallback if Gemini times out
          return scannedReceipt.merchantName != null 
              ? 'Spesa da ${scannedReceipt.merchantName}'
              : 'Spesa';
        });
      } else {
        // Fallback if Gemini not configured
        description = scannedReceipt.merchantName != null 
            ? 'Spesa da ${scannedReceipt.merchantName}'
            : 'Spesa';
      }

      // Step 3: Classify category
      final category = _classifier.classify(
        merchantName: scannedReceipt.merchantName,
        items: scannedReceipt.items,
        description: description,
      );

      // Determine transaction type based on category
      final transactionType = ExpenseCategoryClassifier.classifyTransactionType(category);

      // Step 4: Build ExpenseDraft
      final draft = ExpenseDraft(
        description: description ?? '',
        amount: scannedReceipt.totalAmount,
        date: scannedReceipt.purchaseDate,
        category: category,
        type: transactionType,
        merchantName: scannedReceipt.merchantName,
        imagePath: imagePath,
        method: scannedReceipt.method,
      );

      return draft;
    } finally {
      // Auto-delete temp file after processing (success or error)
      await _tempFileService.deleteFile(imagePath);
    }
  }

  void dispose() {
    _recognitionService.close();
  }
}
