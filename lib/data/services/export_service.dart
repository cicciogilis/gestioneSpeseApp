import 'dart:io';
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:share_plus/share_plus.dart';

import '../../domain/models/transaction.dart';
import '../../utils/category_utils.dart';

class ExportService {
  String _monthYearLabel(int year, int month) {
    final fmt = DateFormat('MMMM yyyy', 'it_IT');
    return fmt.format(DateTime(year, month));
  }

  String _csvOf(List<AppTransaction> transactions, int year, int month) {
    final buffer = StringBuffer();
    buffer.writeln('Report SpesApp - ${_monthYearLabel(year, month)}');
    buffer.writeln();
    buffer.writeln('Data;Tipo;Categoria;Metodo;Importo;Descrizione');
    for (final tx in transactions) {
      buffer.write(tx.date.toIso8601String().split('T').first);
      buffer.write(';');
      buffer.write(tx.type == TransactionType.income ? 'Entrata' : 'Uscita');
      buffer.write(';');
      buffer.write(categoryDisplayName(tx.categoryId));
      buffer.write(';');
      buffer.write(tx.method.name);
      buffer.write(';');
      buffer.write(tx.amount.toStringAsFixed(2).replaceAll('.', ','));
      buffer.write(';');
      buffer.write((tx.description ?? '').replaceAll(';', ','));
      buffer.writeln();
    }

    // Summary rows (4 righe riepilogo)
    double saldoIniziale = 0.0;
    double totalUscite = 0.0;
    double totalEntrate = 0.0;
    for (final tx in transactions) {
      if (tx.type == TransactionType.expense) {
        totalUscite += tx.amount;
      } else if (tx.type == TransactionType.income) {
        totalEntrate += tx.amount;
      }
    }
    final saldoNetto = saldoIniziale + totalEntrate - totalUscite;
    final fmt = NumberFormat.simpleCurrency(locale: 'it_IT');

    buffer.writeln();
    buffer.writeln('Saldo Iniziale;${fmt.format(saldoIniziale)}');
    buffer.writeln('Totale Uscite;${fmt.format(-totalUscite)}');
    buffer.writeln('Totale Entrate;${fmt.format(totalEntrate)}');
    buffer.writeln('Saldo Netto;${fmt.format(saldoNetto)}');

    return buffer.toString();
  }

  Future<Uint8List> _pdfBytesOf(List<AppTransaction> transactions, int year, int month) async {
    final document = pw.Document();
    final monthLabel = _monthYearLabel(year, month);
    final fmt = NumberFormat.simpleCurrency(locale: 'it_IT');

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        header: (context) => pw.Center(
          child: pw.Text(
            'SpesApp - Report Transazioni - $monthLabel',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16),
          ),
        ),
        build: (context) => [
          pw.TableHelper.fromTextArray(
            headers: const ['Data', 'Tipo', 'Categoria', 'Importo', 'Descrizione'],
            data: transactions
                .map((tx) => [
                      tx.date.toIso8601String().split('T').first,
                      tx.type == TransactionType.income ? 'Entrata' : 'Uscita',
                      categoryDisplayName(tx.categoryId),
                      '${tx.amount.toStringAsFixed(2)} EUR',
                      tx.description ?? '',
                    ])
                .toList(),
          ),
          pw.SizedBox(height: 20),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: _pdfSummary(transactions, fmt),
          ),
        ],
      ),
    );
    return document.save();
  }

  pw.Widget _pdfSummary(List<AppTransaction> transactions, NumberFormat fmt) {
    double totalUscite = 0.0;
    double totalEntrate = 0.0;
    for (final tx in transactions) {
      if (tx.type == TransactionType.expense) {
        totalUscite += tx.amount;
      } else if (tx.type == TransactionType.income) {
        totalEntrate += tx.amount;
      }
    }
    const saldoIniziale = 0.0;
    final saldoNetto = saldoIniziale + totalEntrate - totalUscite;
    final bg = saldoNetto >= 0 ? PdfColors.green200 : PdfColors.red200;

    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(color: bg, borderRadius: pw.BorderRadius.circular(8)),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _summaryRow('Saldo Iniziale', fmt.format(saldoIniziale)),
          _summaryRow('Totale Uscite', fmt.format(-totalUscite)),
          _summaryRow('Totale Entrate', fmt.format(totalEntrate)),
          _summaryRow('Saldo Netto', fmt.format(saldoNetto)),
        ],
      ),
    );
  }

  pw.Widget _summaryRow(String label, String value) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.Text(value),
        ],
      );

  Future<File> _writeTempFile(String fileName, Uint8List bytes) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/\$fileName');
    await file.writeAsBytes(bytes);
    return file;
  }

  int _extractYear(int? defaultYear) => DateTime.now().year;
  int _extractMonth(int? defaultMonth) => DateTime.now().month;

  Future<void> exportCsv(List<AppTransaction> transactions, {int? year, int? month}) async {
    final csv = _csvOf(transactions, _extractYear(year), _extractMonth(month));
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

  Future<void> exportPdf(List<AppTransaction> transactions, {int? year, int? month}) async {
    final bytes = await _pdfBytesOf(transactions, _extractYear(year), _extractMonth(month));
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
