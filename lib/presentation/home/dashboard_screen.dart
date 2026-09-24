import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/providers/app_providers.dart';
import '../../core/providers/budget_provider.dart';
import '../../core/providers/selected_period_provider.dart';
import '../../widgets/period_selector_bottom_sheet.dart';
import '../../widgets/transaction_card.dart';
import '../../widgets/saving_goal_bar.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  Widget build(BuildContext context) {
    final asyncHomeData = ref.watch(homeDataProvider);
    final selectedPeriod = ref.watch(selectedPeriodProvider);

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: () => openPeriodSelector(
            context: context,
            ref: ref,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                selectedPeriod.toString(),
                style: const TextStyle(fontSize: 16),
              ),
              const Icon(Icons.arrow_drop_down, size: 18),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(homeDataProvider);
            },
          ),
        ],
      ),
      body: asyncHomeData.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Errore: $err')),
        data: (homeData) => _buildDashboard(context, ref, homeData),
      ),
    );
  }

  Widget _buildDashboard(BuildContext context, WidgetRef ref, HomeData homeData) {
    final fmt = NumberFormat.simpleCurrency(locale: 'it_IT');
    final budget = ref.watch(budgetProvider);

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(homeDataProvider.notifier).refresh();
      },
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildBalanceCard(homeData, fmt),
          const SizedBox(height: 24),
          const Text(
            'BUDGET MENSILE',
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          _buildBudgetMonthlyCard(homeData, budget, fmt),
          const SizedBox(height: 24),
          const SavingGoalBar(),
          const SizedBox(height: 24),
          const Text(
            'ULTIME TRANSAZIONI',
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          ...homeData.monthlyTransactions.take(5).map(
              (tx) => TransactionCard(transaction: tx)),
          if (homeData.monthlyTransactions.isEmpty)
            const Center(
              child: Text('Nessuna transazione registrata per questo mese'),
            ),
        ],
      ),
    );
  }

  Widget _buildBalanceCard(HomeData data, NumberFormat fmt) {
    final balance = data.saldoNetto;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'SALDO NETTO',
              style: TextStyle(
                  color: Colors.grey, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              fmt.format(balance),
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color:
                    balance >= 0 ? Colors.green.shade700 : Colors.red.shade700,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.account_balance,
                        color: Colors.blueGrey, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      'Saldo Iniziale ${fmt.format(data.saldoIniziale)}',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.arrow_upward,
                        color: Colors.green, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      'Entrate ${fmt.format(data.entrate)}',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.arrow_downward,
                        color: Colors.red, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      'Uscite ${fmt.format(data.uscite)}',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildBudgetMonthlyCard(
      HomeData homeData, BudgetSettings budget, NumberFormat fmt) {
    final budgetPct =
        (homeData.uscite / budget.globalLimit).clamp(0.0, 1.0);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildBudgetBar(
              budgetPct,
              homeData.uscite,
              budget.globalLimit,
              fmt,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBudgetBar(
      double pct, double current, double limit, NumberFormat fmt) {
    const Color budgetColor = Color(0xFFF44336); // ROSSO

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LinearProgressIndicator(
          value: pct,
          minHeight: 12,
          backgroundColor: Colors.grey.shade200,
          valueColor: const AlwaysStoppedAnimation<Color>(budgetColor),
          borderRadius: BorderRadius.circular(6),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Budget di spesa',
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: budgetColor),
            ),
            Text(
              '${fmt.format(current)} / ${fmt.format(limit)}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: budgetColor,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
