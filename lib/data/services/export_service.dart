import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../../domain/models/transaction.dart';

class ExportService {
  static const String _csvHeader = 'Data;Tipo;Categoria;Metodo;Importo;Descrizione';

  String _csvOf(List<AppTransaction> transactions) {
    final buffer = StringBuffer(_csvHeader);
    buffer.writeln();
    for (final tx in transactions) {
      buffer.write(tx.date.toIso8601String().split('T').first);
      buffer.write(';');
      buffer.write(tx.type == TransactionType.income ? 'Entrata' : 'Uscita');
      buffer.write(';');
      buffer.write(tx.categoryId);
      buffer.write(';');
      buffer.write(tx.method.name);
      buffer.write(';');
      buffer.write(tx.amount.toStringAsFixed(2).replaceAll('.', ','));
      buffer.write(';');
      buffer.write((tx.description ?? '').replaceAll(';', ','));
      buffer.writeln();
    }
    return buffer.toString();
  }

  Future<Uint8List> _pdfBytesOf(List<AppTransaction> transactions) async {
    final document = pw.Document();
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        header: (context) => pw.Header(
          level: 0,
          child: pw.Text('SpesApp - Report Transazioni'),
        ),
        build: (context) => [
          pw.TableHelper.fromTextArray(
            headers: const ['Data', 'Tipo', 'Categoria', 'Importo', 'Descrizione'],
            data: transactions
                .map((tx) => [
                      tx.date.toIso8601String().split('T').first,
                      tx.type == TransactionType.income ? 'Entrata' : 'Uscita',
                      tx.categoryId,
                      '${tx.amount.toStringAsFixed(2)} €',
                      tx.description ?? '',
                    ])
                .toList(),
          ),
        ],
      ),
    );
    return document.save();
  }

  Future<File> _writeTempFile(String fileName, Uint8List bytes) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes);
    return file;
  }

  Future<void> exportCsv(List<AppTransaction> transactions) async {
    final csv = _csvOf(transactions);
    final file = await _writeTempFile(
      'spesapp_report_${DateTime.now().millisecondsSinceEpoch}.csv',
      Uint8List.fromList(csv.codeUnits),
    );
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        text: 'Report transazioni SpesApp',
      ),
    );
  }

  Future<void> exportPdf(List<AppTransaction> transactions) async {
    final bytes = await _pdfBytesOf(transactions);
    final file = await _writeTempFile(
      'spesapp_report_${DateTime.now().millisecondsSinceEpoch}.pdf',
      bytes,
    );
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        text: 'Report transazioni SpesApp',
      ),
    );
  }
}