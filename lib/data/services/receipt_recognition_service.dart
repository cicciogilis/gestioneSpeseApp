import 'dart:io';

import 'package:receipt_recognition/receipt_recognition.dart';

import '../../domain/models/scanned_receipt.dart';

class ReceiptRecognitionService {
  final ReceiptRecognizer _recognizer;

  ReceiptRecognitionService({ReceiptRecognizer? recognizer})
      : _recognizer = recognizer ??
            ReceiptRecognizer(
              script: TextRecognitionScript.latin,
              singleScan: true,
            );

  Future<ScannedReceipt> processFilePath(String imagePath) async {
    final file = File(imagePath);
    if (!await file.exists()) {
      throw Exception('File immagine non trovato: $imagePath');
    }

    try {
      final result = await _recognizer.processFilePath(imagePath);
      return _mapToScannedReceipt(imagePath, result);
    } catch (e) {
      throw Exception('Errore durante il riconoscimento: $e');
    }
  }

  Future<void> close() async {
    await _recognizer.close();
  }

  ScannedReceipt _mapToScannedReceipt(String imagePath, RecognizedReceipt result) {
    final merchantName = result.store?.value;
    final purchaseDate = result.purchaseDate?.value;
    final totalAmount = result.total?.value;
    
    final items = result.positions.map((pos) {
      final qty = pos.unit?.quantity.value;
      final unitPrice = pos.price.value;
      return ScannedReceiptItem(
        description: pos.product.value,
        quantity: qty?.toDouble(),
        unitPrice: unitPrice,
        totalPrice: unitPrice * (qty?.toDouble() ?? 1),
      );
    }).toList();

    // Build raw text from all recognized entities
    final rawText = [
      if (result.store != null) 'Negozio: ${result.store!.value}',
      if (result.purchaseDate != null) 'Data: ${result.purchaseDate!.value.toIso8601String()}',
      if (result.total != null) 'Totale: ${result.total!.value.toStringAsFixed(2)}',
      ...result.positions.map((p) => '${p.product.value} - ${p.price.value.toStringAsFixed(2)}'),
      if (result.entities != null) 
        ...result.entities!.map((e) => e.value.toString()),
    ].join('\n');

    return ScannedReceipt(
      imagePath: imagePath,
      merchantName: merchantName,
      purchaseDate: purchaseDate,
      totalAmount: totalAmount,
      items: items,
      rawText: rawText,
      status: ReceiptStatus.draft,
      createdAt: DateTime.now(),
    );
  }
}