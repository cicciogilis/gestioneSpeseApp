import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/providers/app_providers.dart';
import '../core/providers/month_balance_provider.dart';
import '../domain/models/month_balance.dart';
import '../domain/models/transaction.dart';

enum OnboardingBalanceChoice { initialBalance, currentBalance }

class OnboardingBalanceChoiceDialog extends ConsumerWidget {
  final void Function(OnboardingBalanceChoice, double) onConfirm;

  const OnboardingBalanceChoiceDialog({super.key, required this.onConfirm});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AlertDialog(
      title: const Text('Configura il tuo saldo'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Come vuoi iniziare? Scegli una delle due opzioni:',
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 24),
          _ChoiceCard(
            icon: Icons.account_balance_wallet,
            iconColor: Colors.blue,
            title: 'Saldo iniziale mese',
            subtitle: 'Imposta il saldo di partenza del mese corrente.\nNon verrà creata alcuna transazione.',
            onTap: () => _showInputSheet(context, ref, OnboardingBalanceChoice.initialBalance),
          ),
          const SizedBox(height: 16),
          _ChoiceCard(
            icon: Icons.account_balance,
            iconColor: Colors.green,
            title: 'Saldo iniziale al giorno corrente',
            subtitle: 'Verrà inserita una voce di saldo iniziale nella lista transazioni del mese corrente',
            onTap: () => _showInputSheet(context, ref, OnboardingBalanceChoice.currentBalance),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annulla'),
        ),
      ],
    );
  }

  void _showInputSheet(BuildContext context, WidgetRef ref, OnboardingBalanceChoice choice) {
    Navigator.of(context).pop();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _InitialBalanceInputSheet(
        choice: choice,
        onConfirm: (amount) => onConfirm(choice, amount),
      ),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ChoiceCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: iconColor.withValues(alpha: 0.15),
                child: Icon(icon, size: 28, color: iconColor),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _InitialBalanceInputSheet extends ConsumerStatefulWidget {
  final OnboardingBalanceChoice choice;
  final void Function(double) onConfirm;

  const _InitialBalanceInputSheet({
    required this.choice,
    required this.onConfirm,
  });

  @override
  ConsumerState<_InitialBalanceInputSheet> createState() => _InitialBalanceInputSheetState();
}

class _InitialBalanceInputSheetState extends ConsumerState<_InitialBalanceInputSheet> {
  final _amountCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  double? _parseAmount(String input) {
    if (input.trim().isEmpty) return null;
    final normalized = input.trim().replaceAll(',', '.');
    return double.tryParse(normalized);
  }

  String? _validateAmount(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Inserisci un importo';
    }
    final amount = _parseAmount(value);
    if (amount == null) {
      return 'Importo non valido. Usa formato: 1234.56 o 1234,56';
    }
    if (amount < -999999.99 || amount > 999999.99) {
      return 'Importo fuori dal range consentito';
    }
    return null;
  }

  Future<void> _onSave() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = _parseAmount(_amountCtrl.text);
    if (amount == null) return;

    setState(() => _isSaving = true);

    try {
      final now = DateTime.now();
      final repo = ref.read(monthBalanceRepositoryProvider);

      // 1. Save MonthBalance (same for both choices)
      await repo.upsertMonthBalance(
        MonthBalance(
          year: now.year,
          month: now.month,
          baselineType: MonthBalance.baselineMonthStart,
          baselineDate: DateTime(now.year, now.month, 1),
          baselineAmount: amount,
        ),
      );
      await repo.recalcCascadeFrom(now.year, now.month);

      // 2. If "Saldo corrente", create special transaction
      if (widget.choice == OnboardingBalanceChoice.currentBalance) {
        final txRepo = ref.read(transactionRepositoryProvider);
        await txRepo.addTransaction(
          AppTransaction(
            amount: amount,
            type: TransactionType.income,
            categoryId: 'cat_saldo_iniziale',
            method: MetodoPagamento.contanti,
            date: now,
            description: 'Saldo iniziale',
            isInitialBalance: true,
          ),
        );
      }

      // 3. Mark onboarding complete
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding_done', true);

      // 4. Invalidate providers
      ref.invalidate(monthBalanceProvider);
      ref.invalidate(homeDataProvider);
      ref.invalidate(transactionsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.choice == OnboardingBalanceChoice.initialBalance
                  ? 'Saldo iniziale di €${amount.toStringAsFixed(2)} salvato'
                  : 'Saldo corrente di €${amount.toStringAsFixed(2)} salvato con transazione "Saldo Iniziale"',
            ),
            backgroundColor: const Color(0xFF4CAF50),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.of(context).pop(); // Close bottom sheet
        widget.onConfirm(amount);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCurrentBalance = widget.choice == OnboardingBalanceChoice.currentBalance;
    final title = isCurrentBalance ? 'Inserisci Saldo Iniziale al giorno corrente' : 'Inserisci Saldo Iniziale Mese';
    final subtitle = isCurrentBalance
        ? 'Verrà inserita una voce di saldo iniziale nella lista transazioni del mese corrente'
        : '';
    final hint = isCurrentBalance
        ? 'Es: 1500,00 (verrà creata transazione "Saldo Iniziale")'
        : 'Es: 1500,00 (solo saldo di partenza, nessuna transazione)';

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              hint,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
              decoration: const InputDecoration(
                labelText: 'Importo (€)',
                hintText: 'Es: 1500,00',
                prefixIcon: Icon(Icons.euro),
                border: OutlineInputBorder(),
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^-?[0-9]*[.,]?[0-9]*$')),
              ],
              validator: _validateAmount,
              autofocus: true,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _onSave,
                icon: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.save),
                label: Text(_isSaving ? 'Salvataggio...' : 'Conferma e Inizia'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}