import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';

import '../../domain/models/transaction.dart';
import '../../utils/category_utils.dart';

class ExportService {
  String _monthYearLabel(int year, int month) {
    final fmt = DateFormat('MMMM yyyy', 'it_IT');
    return fmt.format(DateTime(year, month));
  }

  String _monthShortLabel(int year, int month) {
    const names = [
      'Gen', 'Feb', 'Mar', 'Apr', 'Mag', 'Giu',
      'Lug', 'Ago', 'Set', 'Ott', 'Nov', 'Dic',
    ];
    return '${names[month - 1]} $year';
  }

  // Legge il saldo iniziale dal repository (stessa fonte di Home/Analytics)
  Future<double> _getSaldoIniziale(int year, int month) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'month_balances_${year}_$month';
    final jsonStr = prefs.getString(key);
    if (jsonStr == null || jsonStr.isEmpty) return 0.0;
    try {
      final map = Map<String, dynamic>.from(jsonDecode(jsonStr));
      return (map['baselineAmount'] as num?)?.toDouble() ?? 0.0;
    } catch (_) {
      return 0.0;
    }
  }

  String _csvOf(
    List<AppTransaction> transactions,
    int year,
    List<int> months,
    Map<int, double> saldiIniziali,
  ) {
    final buffer = StringBuffer();
    
    if (months.length == 1) {
      buffer.writeln('Report SpesApp - ${_monthYearLabel(year, months.first)}');
    } else {
      buffer.writeln('Report SpesApp - ${months.map((m) => _monthShortLabel(year, m)).join(', ')}');
    }
    buffer.writeln();
    
    for (final month in months) {
      final monthTransactions = transactions
          .where((tx) => tx.date.year == year && tx.date.month == month)
          .toList();
      
      // Filtra le transazioni di sistema (saldo iniziale) per l'elenco transazioni
      final displayTransactions = monthTransactions
          .where((tx) => !tx.isSystemInitialBalance)
          .toList();
      
      if (displayTransactions.isEmpty && monthTransactions.every((tx) => tx.isSystemInitialBalance)) {
        // Se ci sono solo transazioni di sistema, mostra solo il riepilogo
      } else if (displayTransactions.isEmpty) {
        continue;
      }
      
      buffer.writeln('--- ${_monthYearLabel(year, month)} ---');
      buffer.writeln('Data;Tipo;Categoria;Metodo;Importo;Descrizione');
      
      for (final tx in displayTransactions) {
        buffer.write(tx.date.toIso8601String().split('T').first);
        buffer.write(';');
        buffer.write(tx.type == TransactionType.income ? 'Entrata' : 'Uscita');
        buffer.write(';');
        buffer.write(categoryDisplayName(tx.categoryId));
        buffer.write(';');
        buffer.write(tx.method.name);
        buffer.write(';');
        // Formato euro corretto: €1.234,56
        buffer.write('€${tx.amount.toStringAsFixed(2).replaceAll('.', ',')}');
        buffer.write(';');
        buffer.write((tx.description ?? '').replaceAll(';', ','));
        buffer.writeln();
      }
      
      double totalUscite = 0.0;
      double totalEntrate = 0.0;
      for (final tx in displayTransactions) {
        if (tx.type == TransactionType.expense) {
          totalUscite += tx.amount;
        } else if (tx.type == TransactionType.income) {
          totalEntrate += tx.amount;
        }
      }
      
      // Saldo iniziale per questo mese (dal repository, stesso di Home/Analytics)
      final meseSaldoIniziale = saldiIniziali[month] ?? 0.0;
      
      final saldoNetto = meseSaldoIniziale + totalEntrate - totalUscite;
      final fmt = NumberFormat.simpleCurrency(locale: 'it_IT');
      
      buffer.writeln();
      buffer.writeln('Saldo Iniziale;${fmt.format(meseSaldoIniziale)}');
      buffer.writeln('Totale Entrate;${fmt.format(totalEntrate)}');
      buffer.writeln('Totale Uscite;${fmt.format(-totalUscite)}');
      buffer.writeln('Saldo Netto;${fmt.format(saldoNetto)}');
      buffer.writeln();
    }
    
    return buffer.toString();
  }

  Future<Uint8List> _pdfBytesOf(
    List<AppTransaction> transactions,
    int year,
    List<int> months,
    Map<int, double> saldiIniziali,
  ) async {
    final document = pw.Document();
    final fmt = NumberFormat.simpleCurrency(locale: 'it_IT');

    for (final month in months) {
      final monthTransactions = transactions
          .where((tx) => tx.date.year == year && tx.date.month == month)
          .toList();

      // Filtra le transazioni di sistema (saldo iniziale) per l'elenco transazioni
      final displayTransactions = monthTransactions
          .where((tx) => !tx.isSystemInitialBalance)
          .toList();

      if (displayTransactions.isEmpty && monthTransactions.every((tx) => tx.isSystemInitialBalance)) {
        // Se ci sono solo transazioni di sistema, mostra solo il riepilogo
      } else if (displayTransactions.isEmpty) {
        continue;
      }

      // Calcola totali per questo mese (solo transazioni non di sistema)
      double totalUscite = 0.0;
      double totalEntrate = 0.0;
      for (final tx in displayTransactions) {
        if (tx.type == TransactionType.expense) {
          totalUscite += tx.amount;
        } else if (tx.type == TransactionType.income) {
          totalEntrate += tx.amount;
        }
      }
      
      // Saldo iniziale per questo mese (dal repository, stesso di Home/Analytics)
      final meseSaldoIniziale = saldiIniziali[month] ?? 0.0;
      final saldoNetto = meseSaldoIniziale + totalEntrate - totalUscite;
      final bg = saldoNetto >= 0 ? PdfColors.green200 : PdfColors.red200;

      document.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          header: (context) => pw.Center(
            child: pw.Text(
              'SpesApp - Report Transazioni - ${_monthYearLabel(year, month)}',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16),
            ),
          ),
          build: (context) => [
            pw.TableHelper.fromTextArray(
              headers: const ['Data', 'Tipo', 'Categoria', 'Importo', 'Descrizione'],
              data: displayTransactions
                  .map((tx) => [
                        tx.date.toIso8601String().split('T').first,
                        tx.type == TransactionType.income ? 'Entrata' : 'Uscita',
                        categoryDisplayName(tx.categoryId),
                        '€${tx.amount.toStringAsFixed(2).replaceAll('.', ',')}',
                        tx.description ?? '',
                      ])
                  .toList(),
            ),
            pw.SizedBox(height: 20),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: _pdfSummary(meseSaldoIniziale, totalEntrate, totalUscite, saldoNetto, fmt, bg),
            ),
          ],
        ),
      );
    }

    // Summary page for all months
    if (months.length > 1) {
      document.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          header: (context) => pw.Center(
            child: pw.Text(
              'SpesApp - Riepilogo Multi-Mese',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16),
            ),
          ),
          build: (context) => [
            pw.TableHelper.fromTextArray(
              headers: const ['Mese', 'Saldo Iniziale', 'Entrate', 'Uscite', 'Saldo Netto'],
              data: months.map((month) {
                final monthTx = transactions
                    .where((tx) => tx.date.year == year && tx.date.month == month)
                    .toList();
                double mEntrate = 0, mUscite = 0;
                for (final tx in monthTx) {
                  if (tx.isSystemInitialBalance) continue;
                  if (tx.type == TransactionType.income) mEntrate += tx.amount;
                  if (tx.type == TransactionType.expense) mUscite += tx.amount;
                }
                final mSaldoIniziale = saldiIniziali[month] ?? 0.0;
                return [
                  _monthShortLabel(year, month),
                  fmt.format(mSaldoIniziale),
                  fmt.format(mEntrate),
                  fmt.format(-mUscite),
                  fmt.format(mSaldoIniziale + mEntrate - mUscite),
                ];
              }).toList(),
            ),
            pw.SizedBox(height: 20),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: _pdfSummary(
                months.fold<double>(0.0, (sum, m) => sum + (saldiIniziali[m] ?? 0.0)),
                transactions.where((tx) => months.contains(tx.date.month) && tx.date.year == year && tx.type == TransactionType.income && !tx.isSystemInitialBalance).fold(0.0, (sum, tx) => sum + tx.amount),
                transactions.where((tx) => months.contains(tx.date.month) && tx.date.year == year && tx.type == TransactionType.expense && !tx.isSystemInitialBalance).fold(0.0, (sum, tx) => sum + tx.amount),
                transactions.where((tx) => months.contains(tx.date.month) && tx.date.year == year && !tx.isSystemInitialBalance).fold<double>(0.0, (sum, tx) => sum + (tx.type == TransactionType.income ? tx.amount : -tx.amount)) + months.fold<double>(0.0, (sum, m) => sum + (saldiIniziali[m] ?? 0.0)),
                fmt,
                PdfColors.grey200,
              ),
            ),
          ],
        ),
      );
    }

    return document.save();
  }

  pw.Widget _pdfSummary(
    double saldoIniziale,
    double totalEntrate,
    double totalUscite,
    double saldoNetto,
    NumberFormat fmt,
    PdfColor bg,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(color: bg, borderRadius: pw.BorderRadius.circular(8)),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _summaryRow('Saldo Iniziale', fmt.format(saldoIniziale)),
          _summaryRow('Totale Entrate', fmt.format(totalEntrate)),
          _summaryRow('Totale Uscite', fmt.format(-totalUscite)),
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
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes);
    return file;
  }

  Future<void> exportCsv(
    List<AppTransaction> transactions, {
    int? year,
    List<int>? months,
    double saldoIniziale = 0.0,
  }) async {
    final y = year ?? DateTime.now().year;
    final m = months ?? [DateTime.now().month];
    
    // Carica saldi iniziali dal repository per ogni mese
    final saldiIniziali = <int, double>{};
    for (final month in m) {
      saldiIniziali[month] = await _getSaldoIniziale(y, month);
    }
    
    final csv = _csvOf(transactions, y, m, saldiIniziali);
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

  Future<void> exportPdf(
    List<AppTransaction> transactions, {
    int? year,
    List<int>? months,
    double saldoIniziale = 0.0,
  }) async {
    final y = year ?? DateTime.now().year;
    final m = months ?? [DateTime.now().month];
    
    // Carica saldi iniziali dal repository per ogni mese
    final saldiIniziali = <int, double>{};
    for (final month in m) {
      saldiIniziali[month] = await _getSaldoIniziale(y, month);
    }
    
    final bytes = await _pdfBytesOf(transactions, y, m, saldiIniziali);
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