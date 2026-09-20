import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/models/scanned_receipt.dart';

class ExpenseDescriptionService {
  static const String _geminiEndpoint = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent';
  
  final String _apiKey;

  ExpenseDescriptionService({required String apiKey}) : _apiKey = apiKey;

  bool get isConfigured => _apiKey.isNotEmpty;

  /// Genera una descrizione sintetica della spesa usando Gemini
  Future<String?> generateDescription(ScannedReceipt receipt) async {
    if (!isConfigured) return null;

    try {
      final prompt = _buildPrompt(receipt);
      final response = await _callGemini(prompt);
      
      if (response != null && response.isNotEmpty) {
        return response.trim();
      }
    } catch (e) {
      // Ignore errors, fallback handled by caller
    }
    return null;
  }

  String _buildPrompt(ScannedReceipt receipt) {
    final buffer = StringBuffer();
    
    buffer.writeln('Analizza i dati dello scontrino e genera una descrizione molto breve');
    buffer.writeln('della spesa, adatta a una transazione personale.');
    buffer.writeln('');
    buffer.writeln('Non inventare prodotti.');
    buffer.writeln('Non modificare il totale.');
    buffer.writeln('Non restituire spiegazioni.');
    buffer.writeln('Restituisci soltanto la descrizione.');
    buffer.writeln('');
    buffer.writeln('Dati scontrino:');
    
    if (receipt.merchantName != null) {
      buffer.writeln('Negozio: ${receipt.merchantName}');
    }
    if (receipt.purchaseDate != null) {
      buffer.writeln('Data: ${receipt.purchaseDate!.toIso8601String().split('T').first}');
    }
    if (receipt.totalAmount != null) {
      buffer.writeln('Totale: ${receipt.totalAmount!.toStringAsFixed(2)} €');
    }
    if (receipt.items.isNotEmpty) {
      buffer.writeln('Articoli:');
      for (final item in receipt.items.take(10)) {
        buffer.write('- ${item.description}');
        if (item.quantity != null) buffer.write(' x${item.quantity}');
        if (item.unitPrice != null) buffer.write(' @ ${item.unitPrice!.toStringAsFixed(2)} €');
        if (item.totalPrice != null) buffer.write(' = ${item.totalPrice!.toStringAsFixed(2)} €');
        buffer.writeln();
      }
    }
    if (receipt.rawText.isNotEmpty) {
      buffer.writeln('Testo OCR completo: ${receipt.rawText}');
    }

    return buffer.toString();
  }

  Future<String?> _callGemini(String prompt) async {
    final url = Uri.parse('$_geminiEndpoint?key=$_apiKey');
    
    final requestBody = {
      'contents': [
        {
          'parts': [
            {'text': prompt}
          ]
        }
      ],
      'generationConfig': {
        'temperature': 0.1,
        'maxOutputTokens': 100,
        'topP': 0.8,
        'topK': 10,
      },
    };

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final candidates = data['candidates'] as List?;
        if (candidates != null && candidates.isNotEmpty) {
          final content = candidates.first['content'];
          final parts = content?['parts'] as List?;
          if (parts != null && parts.isNotEmpty) {
            return parts.first['text'] as String?;
          }
        }
      }
    } catch (_) {
      // Timeout or network error
    }
    return null;
  }
}