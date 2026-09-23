import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/providers/app_providers.dart';
import '../core/providers/month_balance_provider.dart';
import '../data/repositories/month_balance_repository.dart';
import '../domain/models/month_balance.dart';

const List<String> _monthLabels = [
  'Gennaio', 'Febbraio', 'Marzo', 'Aprile', 'Maggio', 'Giugno',
  'Luglio', 'Agosto', 'Settembre', 'Ottobre', 'Novembre', 'Dicembre',
];

class InitialBalanceDialog {
  static const String _onboardingDoneKey = 'initialBalance_onboarding_done';

  static Future<void> showIfNeeded(BuildContext context, WidgetRef ref) async {
    final prefs = await SharedPreferences.getInstance();
    final done = prefs.getBool(_onboardingDoneKey) ?? false;
    if (done) return;

    final now = DateTime.now();
    final repo = ref.read(monthBalanceRepositoryProvider);
    final existing = await repo.getMonthBalance(now.year, now.month);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) {
        _showDialog(context, ref, now, existing);
      }
    });
  }

  static void _showDialog(
    BuildContext context,
    WidgetRef ref,
    DateTime now,
    MonthBalance? existing,
  ) {
    final monthLabel = '${_monthLabels[now.month - 1]} ${now.year}';
    final controller = TextEditingController(
      text: existing?.baselineAmount.toStringAsFixed(2) ?? '',
    );

    bool isCurrentDay = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Saldo iniziale — $monthLabel'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Qual è il tuo saldo di partenza per questo mese?',
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    prefixText: '€ ',
                    labelText: 'Saldo iniziale',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  title: const Text('Usa saldo del giorno corrente'),
                  subtitle: const Text(
                    'Le transazioni precedenti a oggi non verranno conteggiate.',
                  ),
                  value: isCurrentDay,
                  onChanged: (val) {
                    setState(() => isCurrentDay = val ?? false);
                  },
                ),
              ],
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () async {
                final value = double.tryParse(
                      controller.text.replaceAll(',', '.'),
                    ) ??
                    0.0;

                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool(_onboardingDoneKey, true);

                final repo = ref.read(monthBalanceRepositoryProvider);
                final String baselineType = isCurrentDay
                    ? MonthBalance.baselineCurrentDay
                    : MonthBalance.baselineMonthStart;
                final DateTime baselineDate = isCurrentDay
                    ? DateTime(now.year, now.month, now.day)
                    : DateTime(now.year, now.month, 1);

                await repo.upsertMonthBalance(MonthBalance(
                  year: now.year,
                  month: now.month,
                  baselineType: baselineType,
                  baselineDate: baselineDate,
                  baselineAmount: value,
                ));

                ref.invalidate(monthBalanceProvider);
                ref.invalidate(homeDataProvider);

                if (context.mounted) Navigator.of(context).pop();
              },
              child: const Text('Conferma'),
            ),
          ],
        ),
      ),
    );
  }

  /// Shows a one-time-per-month message on the first day of each month.
  static Future<void> showMonthAutoBalanceMessage(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final now = DateTime.now();
    if (now.day != 1) return;

    final prefs = await SharedPreferences.getInstance();
    final key = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final lastShown = prefs.getString('monthAutoBalanceMessage_lastShown');
    if (lastShown == key) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Saldo iniziale mese'),
            content: const Text(
              'Il saldo iniziale del nuovo mese sarà calcolato automaticamente. '
              'Puoi modificarlo da Impostazioni → Configurazione Saldo Iniziale.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        prefs.setString('monthAutoBalanceMessage_lastShown', key);
      }
    });
  }

  static Future<double> getSaldoIniziale(int year, int month) async {
    final repo = MonthBalanceRepositoryImpl();
    final balance = await repo.getMonthBalance(year, month);
    return balance?.baselineAmount ?? 0.0;
  }
}
