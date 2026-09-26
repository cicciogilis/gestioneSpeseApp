import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/providers/budget_provider.dart';

class BudgetGoalBar extends ConsumerWidget {
  final double pct;
  final double speso;
  final double tetto;
  final NumberFormat fmt;

  const BudgetGoalBar({
    super.key,
    required this.pct,
    required this.speso,
    required this.tetto,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budget = ref.watch(budgetProvider);
    final tetto = budget.globalLimit;
    final pct = (speso / tetto).clamp(0.0, 1.0);

    const Color budgetColor = Color(0xFFF44336); // ROSSO

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade800),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Budget di spesa',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              Text(
                '${(pct * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: pct > 0.8
                      ? Colors.red
                      : pct > 0.5
                          ? Colors.orange
                          : budgetColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 20,
              backgroundColor: Colors.grey.shade800,
              valueColor: const AlwaysStoppedAnimation<Color>(budgetColor),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(height: 10),

          Text(
            'Speso: €${speso.toStringAsFixed(2)} / €${tetto.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFFF44336),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}