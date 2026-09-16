import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/app_providers.dart';
import '../../core/providers/budget_provider.dart';
import '../../data/services/export_service.dart';
import '../../domain/models/transaction.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _useBiometric = false;
  final ExportService _exportService = ExportService();
  bool _isExporting = false;

  late final TextEditingController _limitCtrl;
  late final TextEditingController _goalCtrl;
  late final TextEditingController _balanceCtrl;

  @override
  void initState() {
    super.initState();
    final budget = ref.read(budgetProvider);
    _limitCtrl = TextEditingController(text: budget.globalLimit.toStringAsFixed(0));
    _goalCtrl = TextEditingController(text: budget.savingGoal.toStringAsFixed(0));
    _balanceCtrl = TextEditingController(text: budget.initialBalance.toStringAsFixed(2));
  }

  @override
  void dispose() {
    _limitCtrl.dispose();
    _goalCtrl.dispose();
    _balanceCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveBudget() async {
    final notifier = ref.read(budgetProvider.notifier);
    const fallback = defaultGlobalBudgetLimit;
    await notifier.setGlobalLimit(double.tryParse(_limitCtrl.text.replaceAll(',', '.')) ?? fallback);
    await notifier.setSavingGoal(double.tryParse(_goalCtrl.text.replaceAll(',', '.')) ?? defaultSavingGoal);
    await notifier.setInitialBalance(double.tryParse(_balanceCtrl.text.replaceAll(',', '.')) ?? defaultInitialBalance);
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
    await _runExport(() => _exportService.exportCsv(transactions));
  }

  Future<void> _exportPdf() async {
    final transactions = ref.read(transactionsProvider).maybeWhen(
          data: (list) => list,
          orElse: () => const <AppTransaction>[],
        );
    await _runExport(() => _exportService.exportPdf(transactions));
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
              children: [
                const Text('Archiviazione locale', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ListTile(
                  leading: const Icon(Icons.folder),
                  title: const Text('Dati salvati sul dispositivo'),
                  subtitle: const Text('Nessun account o servizio cloud richiesto'),
                ),
                const Divider(),
                const Text('Budget', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: TextField(
                    controller: _limitCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Tetto massimo spese mensile',
                      prefixText: '€ ',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: TextField(
                    controller: _goalCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Obiettivo risparmio mensile',
                      prefixText: '€ ',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: TextField(
                    controller: _balanceCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Saldo al 1° del mese',
                      prefixText: '€ ',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: FilledButton(
                    onPressed: _saveBudget,
                    child: const Text('Salva Budget'),
                  ),
                ),
                const Divider(),
                const Text('Preferenze', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                SwitchListTile(
                  title: const Text('Notifiche'),
                  value: _notificationsEnabled,
                  onChanged: (bool value) {
                    setState(() {
                      _notificationsEnabled = value;
                    });
                  },
                ),
                SwitchListTile(
                  title: const Text('Blocco biometrico'),
                  value: _useBiometric,
                  onChanged: (bool value) {
                    setState(() {
                      _useBiometric = value;
                    });
                  },
                ),
                const Divider(),
                const Text('Esportazione', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
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
                const Divider(),
                const Text('Informazioni', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
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