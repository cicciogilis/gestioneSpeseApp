import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/providers/app_providers.dart';
import '../../core/providers/budget_provider.dart';
import '../../domain/models/transaction.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  Widget build(BuildContext context) {
    final asyncValue = ref.watch(transactionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('SpesApp', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: () {
            ref.read(transactionsProvider.notifier).loadTransactions();
          }),
        ],
      ),
      body: asyncValue.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Errore: $err')),
        data: (transactions) => _buildDashboard(context, ref, transactions),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.list), label: 'Spese'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Grafici'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Impostazioni'),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Show the modal bottom sheet for adding transaction
          showModalBottomSheet(
            context: context,
            builder: (context) => SafeArea(
              child: Wrap(
                children: [
                  ListTile(
                    leading: const Icon(Icons.edit_note),
                    title: const Text('Inserimento Manuale'),
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/add');
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.camera_alt),
                    title: const Text('Scansiona Scontrino'),
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/camera');
                    },
                  ),
                ],
              ),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildDashboard(BuildContext context, WidgetRef ref, List<AppTransaction> transactions) {
    // Calculate totals
    double totalExpenses = 0.0;
    double totalIncomes = 0.0;
    for (var t in transactions) {
      if (t.type == TransactionType.expense) {
        totalExpenses += t.amount;
      } else if (t.type == TransactionType.income) {
        totalIncomes += t.amount;
      }
    }

    double balance = totalIncomes - totalExpenses;
    final budget = ref.watch(budgetProvider);
    double budgetPct = (totalExpenses / budget.globalLimit).clamp(0.0, 1.0);

    final fmt = NumberFormat.simpleCurrency(locale: 'it_IT');

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(transactionsProvider.notifier).loadTransactions();
      },
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildBalanceCard(balance, totalIncomes, totalExpenses, fmt),
          const SizedBox(height: 24),
          const Text('BUDGET MENSILE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 8),
          _buildBudgetProgress(budgetPct, totalExpenses, budget.globalLimit, fmt),
          const SizedBox(height: 24),
          const Text('ULTIME TRANSAZIONI', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 8),
          ...transactions.take(5).map((tx) => _buildTransactionTile(tx, fmt)),
        ],
      ),
    );
  }

  Widget _buildBalanceCard(double balance, double inAmt, double outAmt, NumberFormat fmt) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('SALDO NETTO', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              fmt.format(balance),
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: balance >= 0 ? Colors.green.shade700 : Colors.red.shade700,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.arrow_upward, color: Colors.green, size: 16),
                    const SizedBox(width: 4),
                    Text('Entrate ${fmt.format(inAmt)}', style: const TextStyle(fontWeight: FontWeight.w500)),
                  ],
                ),
                Row(
                  children: [
                    const Icon(Icons.arrow_downward, color: Colors.red, size: 16),
                    const SizedBox(width: 4),
                    Text('Uscite ${fmt.format(outAmt)}', style: const TextStyle(fontWeight: FontWeight.w500)),
                  ],
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildBudgetProgress(double pct, double current, double limit, NumberFormat fmt) {
    Color progressColor = Colors.green;
    if (pct > 0.7 && pct <= 0.9) progressColor = Colors.orange;
    if (pct > 0.9) progressColor = Colors.red;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            LinearProgressIndicator(
              value: pct,
              minHeight: 12,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
              borderRadius: BorderRadius.circular(6),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${(pct * 100).toStringAsFixed(0)}% Utilizzato', style: TextStyle(fontWeight: FontWeight.bold, color: progressColor)),
                Text('${fmt.format(current)} / ${fmt.format(limit)}', style: const TextStyle(color: Colors.grey)),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionTile(AppTransaction tx, NumberFormat fmt) {
    final isExpense = tx.type == TransactionType.expense;
    return Card(
      margin: const EdgeInsets.only(bottom: 8.0),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isExpense ? Colors.red.shade50 : Colors.green.shade50,
          child: Icon(
            isExpense ? Icons.shopping_cart : Icons.attach_money,
            color: isExpense ? Colors.red : Colors.green,
          ),
        ),
        title: Text(tx.description ?? tx.categoryId, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Row(
          children: [
            Text(DateFormat('dd MMM yy').format(tx.date)),
          ],
        ),
        trailing: Text(
          (isExpense ? '-' : '+') + fmt.format(tx.amount),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isExpense ? Colors.red : Colors.green,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}
