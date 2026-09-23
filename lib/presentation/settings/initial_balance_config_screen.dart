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

  static const List<String> _monthLabelsShort = [
    'Gen', 'Feb', 'Mar', 'Apr', 'Mag', 'Giu',
    'Lug', 'Ago', 'Set', 'Ott', 'Nov', 'Dic',
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
      });
    } else {
      setState(() {
        _amountCtrl.text = '';
      });
    }
  }

  void _onYearChanged(int? year) async {
    if (year == null) return;
    setState(() => _selectedYear = year);
    await _loadExistingBalance();
  }

  void _onMonthTapped(int month) async {
    setState(() => _selectedMonth = month);
    await _loadExistingBalance();
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
    ref.invalidate(transactionsProvider);
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

      await repo.upsertMonthBalance(MonthBalance(
        year: _selectedYear,
        month: _selectedMonth,
        baselineType: MonthBalance.baselineMonthStart,
        baselineDate: DateTime(_selectedYear, _selectedMonth, 1),
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
    ref.invalidate(transactionsProvider);
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurazione Saldo Iniziale'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : FutureBuilder<List<int>>(
              future: _loadAvailableYears(),
              builder: (context, snapshot) {
                final years = snapshot.data ?? [DateTime.now().year];
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
                    _buildMonthButtons(),
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
                    _buildActionCard(
                      title: 'Ricalcolo automatico',
                      description:
                          'Calcola il saldo iniziale basandosi sui dati del mese precedente',
                      icon: Icons.auto_awesome,
                      color: Colors.blue,
                      onPressed: _recalcAuto,
                    ),
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
                        hintText:
                            'Importo al ${DateFormat('dd MMMM', 'it_IT').format(DateTime(_selectedYear, _selectedMonth, 1))}',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildActionCard(
                      title: 'Salva manuale',
                      description:
                          'Imposta manualmente il saldo iniziale del mese selezionato',
                      icon: Icons.save,
                      color: Colors.green,
                      onPressed: _saveManual,
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

  Widget _buildMonthButtons() {
    final primary = Theme.of(context).colorScheme.primary;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(12, (i) {
        final month = i + 1;
        final selected = month == _selectedMonth;
        return SizedBox(
          width: 80,
          child: InkWell(
            onTap: () => _onMonthTapped(month),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? primary : Colors.grey.shade100,
                border: Border.all(
                  color: selected ? primary : Colors.grey.shade300,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _monthLabelsShort[i],
                style: TextStyle(
                  fontSize: 13,
                  fontWeight:
                      selected ? FontWeight.bold : FontWeight.normal,
                  color: selected ? Colors.white : Colors.black87,
                ),
              ),
            ),
          ),
        );
      }),
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
