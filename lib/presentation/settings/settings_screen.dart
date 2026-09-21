import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/app_providers.dart';
import '../../core/providers/budget_provider.dart';
import '../../core/providers/month_balance_provider.dart';
import '../../core/providers/selected_period_provider.dart';
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

  Future<void> _runExport(Future<void> Function() exportAction) async {
    setState(() => _isExporting = true);
    try {
      await exportAction();
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
    final transactions = ref.read(transactionsProvider).maybeWhen(
          data: (list) => list,
          orElse: () => const <AppTransaction>[],
        );
    final period = ref.read(selectedPeriodProvider);
    final saldoIniziale = await _getSaldoIniziale(period.year, period.month);
    await _runExport(() => _exportService.exportCsv(
          transactions,
          year: period.year,
          month: period.month,
          saldoIniziale: saldoIniziale,
        ));
  }

  Future<void> _exportPdf() async {
    final transactions = ref.read(transactionsProvider).maybeWhen(
          data: (list) => list,
          orElse: () => const <AppTransaction>[],
        );
    final period = ref.read(selectedPeriodProvider);
    final saldoIniziale = await _getSaldoIniziale(period.year, period.month);
    await _runExport(() => _exportService.exportPdf(
          transactions,
          year: period.year,
          month: period.month,
          saldoIniziale: saldoIniziale,
        ));
  }

  Future<double> _getSaldoIniziale(int year, int month) async {
    final snapshot = ref.read(monthBalanceProvider);
    return snapshot.when(
      data: (balance) => balance?.baselineAmount ?? 0.0,
      loading: () => 0.0,
      error: (_, _) => 0.0,
    );
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
