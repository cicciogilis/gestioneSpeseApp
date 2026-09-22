import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/providers/app_providers.dart';
import '../../core/providers/month_balance_provider.dart';
import '../../domain/models/month_balance.dart';

class InitialBalanceConfigScreen extends ConsumerStatefulWidget {
  const InitialBalanceConfigScreen({super.key});

  @override
  ConsumerState<InitialBalanceConfigScreen> createState() =>
      _InitialBalanceConfigScreenState();
}

class _InitialBalanceConfigScreenState
    extends ConsumerState<InitialBalanceConfigScreen> {
  late int _selectedYear;
  late int _selectedMonth;
  final _amountCtrl = TextEditingController();
  bool _isLoading = false;
  bool _useCurrentDay = false;

  static const List<String> _monthLabels = [
    'Gennaio', 'Febbraio', 'Marzo', 'Aprile', 'Maggio', 'Giugno',
    'Luglio', 'Agosto', 'Settembre', 'Ottobre', 'Novembre', 'Dicembre',
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedYear = now.year;
    _selectedMonth = now.month;
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<List<int>> _loadAvailableYears() async {
    final repo = ref.read(monthBalanceRepositoryProvider);
    final years = await repo.getAvailableYears();
    return years;
  }

  Future<void> _loadExistingBalance() async {
    final repo = ref.read(monthBalanceRepositoryProvider);
    final balance = await repo.getMonthBalance(_selectedYear, _selectedMonth);
    if (balance != null) {
      setState(() {
        _amountCtrl.text = balance.baselineAmount.toStringAsFixed(2);
        _useCurrentDay = balance.isCurrentDay;
      });
    } else {
      setState(() {
        _amountCtrl.text = '';
        _useCurrentDay = false;
      });
    }
  }

  void _onYearChanged(int? year) async {
    if (year == null) return;
    setState(() => _selectedYear = year);
    await _loadExistingBalance();
  }

  void _onMonthChanged(int? month) async {
    if (month == null) return;
    setState(() => _selectedMonth = month);
    await _loadExistingBalance();
  }

  bool _isCurrentMonth() {
    final now = DateTime.now();
    return _selectedYear == now.year && _selectedMonth == now.month;
  }

  Future<void> _recalcAuto() async {
    final confirmed = await _confirmCascade();
    if (!confirmed) return;

    setState(() => _isLoading = true);
    try {
      final repo = ref.read(monthBalanceRepositoryProvider);
      await repo.recalcCascadeFrom(_selectedYear, _selectedMonth);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saldo ricalcolato automaticamente')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }

    ref.invalidate(monthBalanceProvider);
    ref.invalidate(homeDataProvider);
  }

  Future<void> _saveManual() async {
    final value = double.tryParse(_amountCtrl.text.replaceAll(',', '.'));
    if (value == null || _amountCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inserisci un importo valido')),
      );
      return;
    }
    if (value.abs() > 9999999) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Importo troppo grande')),
      );
      return;
    }

    final confirmed = await _confirmCascade();
    if (!confirmed) return;

    setState(() => _isLoading = true);
    try {
      final repo = ref.read(monthBalanceRepositoryProvider);

      final now = DateTime.now();
      final isCurrentMonth = _selectedYear == now.year && _selectedMonth == now.month;
      final effectiveUseCurrentDay = _useCurrentDay && isCurrentMonth;
      final baselineType = effectiveUseCurrentDay
          ? MonthBalance.baselineCurrentDay
          : MonthBalance.baselineMonthStart;
      final baselineDate = effectiveUseCurrentDay
          ? DateTime(now.year, now.month, now.day)
          : DateTime(_selectedYear, _selectedMonth, 1);

      await repo.upsertMonthBalance(MonthBalance(
        year: _selectedYear,
        month: _selectedMonth,
        baselineType: baselineType,
        baselineDate: baselineDate,
        baselineAmount: value,
      ));

      await repo.recalcCascadeFrom(_selectedYear, _selectedMonth);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saldo iniziale salvato')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore nel salvataggio: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }

    ref.invalidate(monthBalanceProvider);
    ref.invalidate(homeDataProvider);
  }

  Future<bool> _confirmCascade() async {
    return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Conferma operazione'),
            content: const Text(
              'Il saldo del mese selezionato e quelli dei mesi successivi '
              'saranno sovrascritti irreversibilmente, perché dipendono a '
              'cascata dai mesi precedenti.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Annulla'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Conferma'),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadExistingBalance();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final maxMonth = _selectedYear == now.year ? now.month : 12;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurazione Saldo Iniziale'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : FutureBuilder<List<int>>(
              future: _loadAvailableYears(),
              builder: (context, snapshot) {
                final years = snapshot.data ?? [now.year];
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    const Text(
                      'Seleziona mese',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    _buildYearDropdown(years),
                    const SizedBox(height: 16),
                    _buildMonthDropdown(maxMonth),
                    const SizedBox(height: 24),
                    const Text(
                      'Impostazione manuale',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _amountCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        prefixText: '€ ',
                        labelText: 'Saldo iniziale',
                        hintText: 'Importo al ${DateFormat('dd MMMM', 'it_IT').format(DateTime(_selectedYear, _selectedMonth, 1))}',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    if (_isCurrentMonth())
                      CheckboxListTile(
                        title: const Text('Usa saldo del giorno corrente'),
                        subtitle: const Text(
                          'Le transazioni precedenti a oggi non verranno conteggiate.',
                        ),
                        value: _useCurrentDay,
                        onChanged: (val) {
                          setState(() => _useCurrentDay = val ?? false);
                        },
                      ),
                    const SizedBox(height: 24),
                    const Text(
                      'Ricalcolo automatico',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Saldo iniziale = saldo iniziale mese precedente + entrate - uscite',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    Column(
                      children: [
                        _buildActionCard(
                          title: 'Ricalcolo automatico',
                          description: 'Calcola il saldo iniziale basandosi sui dati del mese precedente',
                          icon: Icons.auto_awesome,
                          color: Colors.blue,
                          onPressed: _recalcAuto,
                        ),
                        const SizedBox(height: 12),
                        _buildActionCard(
                          title: 'Salva manuale',
                          description: 'Imposta manualmente il saldo iniziale del mese selezionato',
                          icon: Icons.save,
                          color: Colors.green,
                          onPressed: _saveManual,
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
    );
  }

  Widget _buildYearDropdown(List<int> years) {
    return DropdownButtonFormField<int>(
      initialValue: _selectedYear,
      items: years
          .map((y) => DropdownMenuItem(value: y, child: Text(y.toString())))
          .toList(),
      onChanged: _onYearChanged,
      decoration: const InputDecoration(
        labelText: 'Anno',
        border: OutlineInputBorder(),
      ),
    );
  }

  Widget _buildMonthDropdown(int maxMonth) {
    final effectiveMonth = _selectedMonth > maxMonth ? maxMonth : _selectedMonth;
    return DropdownButtonFormField<int>(
      initialValue: effectiveMonth,
      items: List.generate(maxMonth, (i) => i + 1).map((m) {
        return DropdownMenuItem(value: m, child: Text(_monthLabels[m - 1]));
      }).toList(),
      onChanged: _onMonthChanged,
      decoration: const InputDecoration(
        labelText: 'Mese',
        border: OutlineInputBorder(),
      ),
    );
  }

  Widget _buildActionCard({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Card(
      elevation: 2,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.2),
          child: Icon(icon, color: color),
        ),
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(description,
            style: TextStyle(color: Colors.grey[600], fontSize: 12)),
        trailing: const Icon(Icons.chevron_right),
        onTap: onPressed,
      ),
    );
  }
}
