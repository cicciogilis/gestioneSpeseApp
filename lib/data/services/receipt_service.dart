import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../../domain/models/scanned_receipt.dart';
import '../../domain/models/transaction.dart';
import 'ml_kit_service.dart';
import 'temp_file_service.dart';

class ReceiptService {
  final MLKitService _mlKitService = MLKitService();
  final TempFileService _tempFileService = TempFileService();

  static const String _draftsKey = 'scanned_receipt_drafts';

  Future<ScannedReceipt> scanReceipt(String imagePath) async {
    final extractedText = await _mlKitService.recognizeText(imagePath);
    final classification = _classifyReceipt(extractedText);

    return ScannedReceipt(
      imagePath: imagePath,
      extractedText: extractedText,
      amount: classification['amount'] as double?,
      date: classification['date'] as DateTime?,
      merchant: classification['merchant'] as String?,
      categoryId: classification['categoryId'] as String?,
      method: classification['method'] as MetodoPagamento?,
      description: classification['description'] as String?,
      status: ReceiptStatus.draft,
      createdAt: DateTime.now(),
    );
  }

  Map<String, dynamic> _classifyReceipt(String text) {
    final lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    final fullText = text.toLowerCase();

    // Extract amount - look for currency patterns
    double? amount;
    final amountRegex = RegExp(r'(\d+[.,]\d{2})\s*(?:€|EUR|euro)', caseSensitive: false);
    final matches = amountRegex.allMatches(text);
    if (matches.isNotEmpty) {
      // Take the largest amount as total
      amount = matches
          .map((m) => double.parse(m.group(1)!.replaceAll(',', '.')))
          .reduce((a, b) => a > b ? a : b);
    }

    // Extract date
    DateTime? date;
    final dateRegex = RegExp(r'(\d{1,2})[./](\d{1,2})[./](\d{2,4})');
    for (final line in lines) {
      final match = dateRegex.firstMatch(line);
      if (match != null) {
        int day = int.parse(match.group(1)!);
        int month = int.parse(match.group(2)!);
        int year = int.parse(match.group(3)!);
        if (year < 100) year += 2000;
        if (year >= 1900 && year <= 2100) {
          date = DateTime(year, month, day);
          break;
        }
      }
    }

    // Extract merchant (usually first line or after keywords)
    String? merchant;
    const merchantKeywords = ['ricevuta', 'scontrino', 'fattura', 'receipt', 'invoice'];
    for (final line in lines) {
      final lower = line.toLowerCase();
      if (!merchantKeywords.any((k) => lower.contains(k)) && line.length > 3) {
        merchant = line;
        break;
      }
    }
    merchant ??= lines.isNotEmpty ? lines.first : null;

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
      'amount': amount,
      'date': date,
      'merchant': merchant,
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
    _mlKitService.dispose();
  }
}