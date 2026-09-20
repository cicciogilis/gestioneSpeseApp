import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class InitialBalanceDialog {
  static const List<String> _months = [
    'Gennaio', 'Febbraio', 'Marzo', 'Aprile', 'Maggio', 'Giugno',
    'Luglio', 'Agosto', 'Settembre', 'Ottobre', 'Novembre', 'Dicembre'
  ];

  static String _getKey(int year, int month) => 'saldo_iniziale_${year}_$month';

  /// Mostra il dialog per il saldo iniziale del mese se non già inserito
  static Future<void> showIfNeeded(BuildContext context) async {
    final now = DateTime.now();
    final key = _getKey(now.year, now.month);
    
    final prefs = await SharedPreferences.getInstance();
    final alreadyInserted = prefs.containsKey(key);
    
    if (alreadyInserted) return;

    // Mostra il dialog dopo il primo frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) {
        _showDialog(context, key, now);
      }
    });
  }

  static void _showDialog(BuildContext context, String key, DateTime month) {
    final monthLabel = '${_months[month.month - 1]} ${month.year}';
    final controller = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: Text('Saldo iniziale — $monthLabel'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Qual è il tuo saldo di partenza per $monthLabel?'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                prefixText: '€ ',
                labelText: 'Saldo iniziale',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              // Salta: saldo iniziale = 0
              final prefs = await SharedPreferences.getInstance();
              await prefs.setDouble(key, 0.0);
              if (context.mounted) Navigator.of(context).pop();
            },
            child: const Text('Salta'),
          ),
          FilledButton(
            onPressed: () async {
              final value = double.tryParse(controller.text.replaceAll(',', '.')) ?? 0.0;
              final prefs = await SharedPreferences.getInstance();
              await prefs.setDouble(key, value);
              if (context.mounted) Navigator.of(context).pop();
            },
            child: const Text('Conferma'),
          ),
        ],
      ),
    );
  }

  /// Legge il saldo iniziale per un dato mese/anno
  static Future<double> getSaldoIniziale(int year, int month) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_getKey(year, month)) ?? 0.0;
  }
}