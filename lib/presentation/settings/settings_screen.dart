import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/app_providers.dart';
import '../../core/providers/budget_provider.dart';
import '../../core/providers/month_balance_provider.dart';
import '../../data/services/export_service.dart';
import '../../domain/models/transaction.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _notificationsEnabled = true;
  final ExportService _exportService = ExportService();
  bool _isExporting = false;

  late final TextEditingController _limitCtrl;
  late final TextEditingController _goalCtrl;

  @override
  void initState() {
    super.initState();
    final budget = ref.read(budgetProvider);
    _limitCtrl = TextEditingController(text: budget.globalLimit.toStringAsFixed(0));
    _goalCtrl = TextEditingController(text: budget.savingGoal.toStringAsFixed(0));
  }

  @override
  void dispose() {
    _limitCtrl.dispose();
    _goalCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveBudget() async {
    final notifier = ref.read(budgetProvider.notifier);
    const fallback = defaultGlobalBudgetLimit;
    await notifier.setGlobalLimit(double.tryParse(_limitCtrl.text.replaceAll(',', '.')) ?? fallback);
    await notifier.setSavingGoal(double.tryParse(_goalCtrl.text.replaceAll(',', '.')) ?? defaultSavingGoal);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Budget salvato')));
    }
  }

  Future<double> _getSaldoIniziale(int year, int month) async {
    final repo = ref.read(monthBalanceRepositoryProvider);
    final balance = await repo.getMonthBalance(year, month);
    return balance?.baselineAmount ?? 0.0;
  }

  Future<void> _startExport(String format) async {
    final result = await showDialog<_ExportSelection>(
      context: context,
      barrierDismissible: false,
       builder: (ctx) => _ExportSelectionDialog(),
    );

    if (result == null) return;

    final confirmedYear = result.year;
    final confirmedMonth = result.month;

    final transactions = ref.read(transactionsProvider).maybeWhen(
          data: (list) => list
              .where((tx) =>
                  tx.date.year == confirmedYear &&
                  tx.date.month == confirmedMonth)
              .toList(),
          orElse: () => const <AppTransaction>[],
        );

    final saldoIniziale =
        await _getSaldoIniziale(confirmedYear, confirmedMonth);

    setState(() => _isExporting = true);
    try {
      if (format == 'csv') {
        await _exportService.exportCsv(
          transactions,
          year: confirmedYear,
          month: confirmedMonth,
          saldoIniziale: saldoIniziale,
        );
      } else {
        await _exportService.exportPdf(
          transactions,
          year: confirmedYear,
          month: confirmedMonth,
          saldoIniziale: saldoIniziale,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore export: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _exportCsv() async {
    await _startExport('csv');
  }

  Future<void> _exportPdf() async {
    await _startExport('pdf');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Impostazioni'),
      ),
      body: _isExporting
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                const Text('Budget', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: TextField(
                    controller: _limitCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Tetto massimo spese al mese (€)',
                      prefixText: '€ ',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: TextField(
                    controller: _goalCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Obiettivo risparmio al mese (€)',
                      prefixText: '€ ',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: FilledButton(
                    onPressed: _saveBudget,
                    child: const Text('Salva Budget'),
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                const Text('Preferenze', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                SwitchListTile(
                  title: const Text('Notifiche'),
                  value: _notificationsEnabled,
                  onChanged: (bool value) {
                    setState(() {
                      _notificationsEnabled = value;
                    });
                  },
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: const Icon(Icons.account_balance_wallet),
                  title: const Text('Configurazione Saldo Iniziale'),
                  subtitle: const Text('Imposta o ricalcola il saldo mensile'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/initial-balance-config'),
                ),
                const SizedBox(height: 8),
                const Divider(),
                const SizedBox(height: 8),
                const Text('Esportazione', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                ListTile(
                  leading: const Icon(Icons.table_chart),
                  title: const Text('Esporta CSV'),
                  subtitle: const Text('Invia il report completo come CSV'),
                  onTap: _exportCsv,
                ),
                ListTile(
                  leading: const Icon(Icons.picture_as_pdf),
                  title: const Text('Esporta PDF'),
                  subtitle: const Text('Invia il report come documento PDF'),
                  onTap: _exportPdf,
                ),
                const SizedBox(height: 8),
                const Divider(),
                const SizedBox(height: 8),
                const Text('Informazioni', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                ListTile(
                  leading: const Icon(Icons.info),
                  title: const Text('Versione 1.0.0'),
                ),
                ListTile(
                  leading: const Icon(Icons.code),
                  title: const Text('Open Source Licenses'),
                  onTap: () {
                    showLicensePage(
                      context: context,
                      applicationName: 'SpesApp',
                      applicationVersion: '1.0.0',
                    );
                  },
                ),
            ],
          ),
    );
  }
}

class _ExportSelection {
  final int year;
  final int month;

  const _ExportSelection({required this.year, required this.month});
}

class _ExportSelectionDialog extends StatefulWidget {

  @override
  State<_ExportSelectionDialog> createState() => _ExportSelectionDialogState();
}

class _ExportSelectionDialogState extends State<_ExportSelectionDialog> {
  final now = DateTime.now();
  late int _selectedYear;
  late int _selectedMonth;

  @override
  void initState() {
    super.initState();
    _selectedYear = now.year;
    _selectedMonth = now.month;
  }

  @override
  Widget build(BuildContext context) {
    const monthLabels = [
      'Gennaio', 'Febbraio', 'Marzo', 'Aprile', 'Maggio', 'Giugno',
      'Luglio', 'Aggosto', 'Settembre', 'Ottobre', 'Novembre', 'Dicembre',
    ];

    final yearItems = List.generate(11, (i) => now.year - 5 + i);

    final monthItems = _selectedYear == now.year
        ? List.generate(now.month, (i) => i + 1)
        : List.generate(12, (i) => i + 1);

    if (_selectedMonth > monthItems.length) {
      _selectedMonth = monthItems.length;
    }

    return AlertDialog(
      title: const Text('Seleziona periodo'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
           DropdownButtonFormField<int>(
            initialValue: _selectedYear,
            decoration: const InputDecoration(
              labelText: 'Anno',
              border: OutlineInputBorder(),
            ),
            items: yearItems
                .map((y) => DropdownMenuItem(value: y, child: Text(y.toString())))
                .toList(),
            onChanged: (int? val) {
              if (val != null) {
                setState(() {
                  _selectedYear = val;
                  if (_selectedMonth > monthItems.length) {
                    _selectedMonth = monthItems.length;
                  }
                });
              }
            },
          ),
          const SizedBox(height: 16),
           DropdownButtonFormField<int>(
            initialValue: _selectedMonth,
            decoration: const InputDecoration(
              labelText: 'Mese',
              border: OutlineInputBorder(),
            ),
            items: monthItems
                .map((m) => DropdownMenuItem(
                      value: m,
                      child: Text(monthLabels[m - 1]),
                    ))
                .toList(),
            onChanged: (int? val) {
              if (val != null) {
                setState(() => _selectedMonth = val);
              }
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annulla'),
        ),
        FilledButton(
          onPressed: _selectedMonth >= 1 && _selectedMonth <= 12
              ? () => Navigator.pop(
                  context,
                  _ExportSelection(year: _selectedYear, month: _selectedMonth),
                )
              : null,
          child: const Text('Esporta'),
        ),
      ],
    );
  }
}
