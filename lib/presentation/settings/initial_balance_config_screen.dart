import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isSaving = false;

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

  /// Normalizza virgola -> punto e parsing sicuro
  double? _parseAmount(String input) {
    if (input.trim().isEmpty) return null;
    final normalized = input.trim().replaceAll(',', '.');
    return double.tryParse(normalized);
  }

  /// Validazione dell'input
  String? _validateAmount(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Inserisci un importo';
    }
    final amount = _parseAmount(value);
    if (amount == null) {
      return 'Importo non valido. Usa formato: 1234.56 o 1234,56';
    }
    if (amount < -999999.99 || amount > 999999.99) {
      return 'Importo fuori dal range consentito (-999.999,99 ÷ 999.999,99)';
    }
    return null;
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
    if (!_formKey.currentState!.validate()) return;

    final amount = _parseAmount(_amountCtrl.text);
    if (amount == null) {
      _showErrorDialog('Impossibile interpretare l\'importo inserito.');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final repo = ref.read(monthBalanceRepositoryProvider);
      await repo.upsertMonthBalance(MonthBalance(
        year: _selectedYear,
        month: _selectedMonth,
        baselineType: MonthBalance.baselineMonthStart,
        baselineDate: DateTime(_selectedYear, _selectedMonth, 1),
        baselineAmount: amount,
      ));

      // Ricalcola a cascata i mesi SUCCESSIVI (non tocca il mese appena salvato)
      final nextMonth = _selectedMonth == 12 ? 1 : _selectedMonth + 1;
      final nextYear = _selectedMonth == 12 ? _selectedYear + 1 : _selectedYear;
      await repo.recalcCascadeFrom(nextYear, nextMonth);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Saldo iniziale di €${amount.toStringAsFixed(2)} salvato '
              'per ${_monthName(_selectedMonth)} $_selectedYear',
            ),
            backgroundColor: const Color(0xFF4CAF50),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );

        _amountCtrl.clear();
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog(
          'Errore durante il salvataggio del saldo iniziale:\n${e.toString()}',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }

    ref.invalidate(monthBalanceProvider);
    ref.invalidate(homeDataProvider);
    ref.invalidate(transactionsProvider);
  }

  /// Utility: nome mese in italiano
  String _monthName(int month) {
    const mesi = [
      '', 'Gennaio', 'Febbraio', 'Marzo', 'Aprile', 'Maggio', 'Giugno',
      'Luglio', 'Agosto', 'Settembre', 'Ottobre', 'Novembre', 'Dicembre',
    ];
    return mesi[month];
  }

  /// Dialog di errore
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Errore'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
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
                    _buildYearDropdown(years),
                    const SizedBox(height: 16),
                    _buildMonthButtons(),
                    const SizedBox(height: 24),
                    const Text(
                      'Ricalcolo Automatico',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Il saldo iniziale del mese selezionato viene calcolato sommando al saldo iniziale del mese precedente le relative uscite ed entrate totali',
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
                      'Impostazione Manuale',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Inserisci manualmente il saldo iniziale per il mese selezionato',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    Form(
                      key: _formKey,
                      child: TextFormField(
                        controller: _amountCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Saldo iniziale (€)',
                          hintText: 'Es: 1500,00',
                          prefixIcon: Icon(Icons.euro),
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'^-?[0-9]*[.,]?[0-9]*$'),
                          ),
                        ],
                        validator: _validateAmount,
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: _isSaving ? null : _saveManual,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.save),
                        label: Text(_isSaving ? 'Salvataggio...' : 'Salva Saldo'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4CAF50),
                          foregroundColor: Colors.white,
                        ),
                      ),
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
