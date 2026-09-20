import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../../domain/models/scanned_receipt.dart';
import '../../domain/models/transaction.dart';
import 'receipt_recognition_service.dart';
import 'temp_file_service.dart';

class ReceiptService {
  final ReceiptRecognitionService _recognitionService;
  final TempFileService _tempFileService = TempFileService();

  static const String _draftsKey = 'scanned_receipt_drafts';

  ReceiptService(this._recognitionService);

  Future<ScannedReceipt> scanReceipt(String imagePath) async {
    // Use receipt_recognition library for structured OCR
    final scannedReceipt = await _recognitionService.processFilePath(imagePath);
    
    // Apply local classification for category and payment method
    final classification = _classifyReceipt(scannedReceipt.rawText);
    
    // Merge recognition results with local classification
    return scannedReceipt.copyWith(
      categoryId: classification['categoryId'] as String?,
      method: classification['method'] as MetodoPagamento?,
      description: classification['description'] as String?,
      status: ReceiptStatus.draft,
    );
  }

  Map<String, dynamic> _classifyReceipt(String text) {
    final lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    final fullText = text.toLowerCase();

    // Classify category based on merchant or keywords
    String? categoryId;
    final categoryKeywords = {
      'cat_alimentari': ['supermercato', 'conad', 'esselunga', 'coop', 'lidl', 'eurospin', 'md', 'famila', 'carrefour', 'auchans', 'grocery', 'food', 'alimentari'],
      'cat_trasporti': ['benzina', 'carburante', 'eni', 'q8', 'ip', 'tamoil', 'autostrada', 'parcheggio', 'taxi', 'uber', 'bus', 'treno', 'fuel', 'gas'],
      'cat_ristoranti': ['ristorante', 'pizzeria', 'bar', 'caffe', 'mcdonald', 'burger', 'kfc', 'subway', 'restaurant', 'cafe', 'pub'],
      'cat_salute': ['farmacia', 'pharmacy', 'medico', 'dentista', 'ospedale', 'analisi', 'ricetta', 'medicine'],
      'cat_intrattenimento': ['cinema', 'teatro', 'netflix', 'spotify', 'disney', 'prime', 'videogame', 'steam', 'playstation', 'xbox'],
      'cat_abbigliamento': ['negozio', 'abbigliamento', 'vestiti', 'scarpe', 'zara', 'h&m', 'uniqlo', 'decathlon', 'clothing'],
      'cat_casa': ['ikea', 'leroy', 'brico', 'casa', 'arredamento', 'eletrodomestici', 'mediaworld', 'expert', 'home'],
      'cat_altro': [],
    };

    for (final entry in categoryKeywords.entries) {
      for (final keyword in entry.value) {
        if (fullText.contains(keyword.toLowerCase())) {
          categoryId = entry.key;
          break;
        }
      }
      if (categoryId != null) break;
    }

    // Default to 'Altro' if no match
    categoryId ??= 'cat_altro';

    // Classify payment method
    MetodoPagamento? method;
    if (fullText.contains('contanti') || fullText.contains('cash')) {
      method = MetodoPagamento.contanti;
    } else if (fullText.contains('carta') || fullText.contains('card') || fullText.contains('pos') || fullText.contains('bancomat')) {
      method = MetodoPagamento.carta;
    } else if (fullText.contains('paypal')) {
      method = MetodoPagamento.paypal;
    } else if (fullText.contains('satispay')) {
      method = MetodoPagamento.satispay;
    } else if (fullText.contains('bonifico') || fullText.contains('transfer')) {
      method = MetodoPagamento.bonifico;
    }

    // Description from remaining text
    String? description;
    if (lines.length > 1) {
      description = lines.skip(1).take(3).join(' ');
    }

    return {
      'categoryId': categoryId,
      'method': method,
      'description': description,
    };
  }

  Future<void> saveDraft(ScannedReceipt receipt) async {
    final prefs = await SharedPreferences.getInstance();
    final drafts = await getDrafts();
    
    final existingIndex = drafts.indexWhere((d) => d.id == receipt.id);
    final updatedReceipt = receipt.copyWith(
      updatedAt: DateTime.now(),
      id: receipt.id ?? 'draft_${DateTime.now().millisecondsSinceEpoch}',
    );
    
    if (existingIndex >= 0) {
      drafts[existingIndex] = updatedReceipt;
    } else {
      drafts.add(updatedReceipt);
    }
    
    await prefs.setStringList(
      _draftsKey,
      drafts.map((d) => jsonEncode(d.toMap())).toList(),
    );
  }

  Future<List<ScannedReceipt>> getDrafts() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getStringList(_draftsKey);
    if (encoded == null) return [];
    
    return encoded
        .map((e) => ScannedReceipt.fromMap(jsonDecode(e) as Map<String, dynamic>))
        .where((d) => d.status == ReceiptStatus.draft)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<void> deleteDraft(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final drafts = await getDrafts();
    drafts.removeWhere((d) => d.id == id);
    await prefs.setStringList(
      _draftsKey,
      drafts.map((d) => jsonEncode(d.toMap())).toList(),
    );
  }

  Future<void> confirmReceipt(ScannedReceipt receipt) async {
    final updated = receipt.copyWith(
      status: ReceiptStatus.confirmed,
      updatedAt: DateTime.now(),
    );
    await saveDraft(updated);
    await _tempFileService.deleteFile(receipt.imagePath);
  }

  Future<void> rejectReceipt(ScannedReceipt receipt) async {
    final updated = receipt.copyWith(
      status: ReceiptStatus.rejected,
      updatedAt: DateTime.now(),
    );
    await saveDraft(updated);
    await _tempFileService.deleteFile(receipt.imagePath);
  }

  Future<void> cleanupOldDrafts({Duration maxAge = const Duration(days: 30)}) async {
    final drafts = await getDrafts();
    final now = DateTime.now();
    final toKeep = drafts.where((d) => now.difference(d.createdAt) <= maxAge).toList();
    
    if (toKeep.length != drafts.length) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _draftsKey,
        toKeep.map((d) => jsonEncode(d.toMap())).toList(),
      );
    }
  }

  void dispose() {
    // No MLKitService to dispose anymore
  }
}