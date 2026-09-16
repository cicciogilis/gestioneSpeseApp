import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/constants/seed_categories.dart';
import '../../core/providers/app_providers.dart';
import '../../domain/models/category.dart';
import '../../domain/models/transaction.dart';

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  @override
  Widget build(BuildContext context) {
    final asyncValue = ref.watch(transactionsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
      ),
      body: asyncValue.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Errore: $err')),
        data: (transactions) => _buildAnalytics(context, transactions),
      ),
    );
  }

  static const AppCategory _fallbackCategory = AppCategory(
    id: 'cat_altro',
    name: 'Altro',
    icon: 'category',
    color: 0xFF9E9E9E,
    type: CategoryType.expense,
  );

  String _categoryName(String categoryId) {
    return seedCategories
        .firstWhere((c) => c.id == categoryId, orElse: () => _fallbackCategory)
        .name;
  }

  Color _categoryColor(String categoryId) {
    return Color(
        seedCategories.firstWhere((c) => c.id == categoryId, orElse: () => _fallbackCategory).color);
  }

  Widget _buildAnalytics(BuildContext context, List<AppTransaction> transactions) {
    double totalIncome = 0.0;
    double totalExpense = 0.0;
    for (var t in transactions) {
      if (t.type == TransactionType.income) totalIncome += t.amount;
      if (t.type == TransactionType.expense) totalExpense += t.amount;
    }
    final fmt = NumberFormat.simpleCurrency(locale: 'it_IT');

    final expensesByCategory = <String, double>{};
    final monthlyExpenses = <String, double>{};
    final monthlyBalance = <String, double>{};
    final monthlyData = <String>[];
    for (final t in transactions) {
      if (t.type != TransactionType.expense) continue;
      expensesByCategory.update(t.categoryId, (v) => v + t.amount, ifAbsent: () => t.amount);
      final monthKey = DateFormat('yyyy-MM').format(t.date);
      monthlyExpenses.update(monthKey, (v) => v + t.amount, ifAbsent: () => t.amount);
      monthlyBalance.update(
        monthKey,
        (v) => v - t.amount,
        ifAbsent: () => -t.amount,
      );
    }
    for (final t in transactions) {
      if (t.type != TransactionType.income) continue;
      final monthKey = DateFormat('yyyy-MM').format(t.date);
      monthlyBalance.update(monthKey, (v) => v + t.amount, ifAbsent: () => t.amount);
    }
    monthlyData.addAll(monthlyBalance.keys.toList()..sort());

    final sortedMonths = monthlyExpenses.keys.toList()..sort();
    final pieSections = expensesByCategory.entries.map((e) {
      return PieChartSectionData(
        value: e.value,
        title: '${(e.value / (totalExpense == 0 ? 1 : totalExpense) * 100).toStringAsFixed(0)}%',
        color: _categoryColor(e.key),
        radius: 40,
        titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
      );
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        const Text('Riassunto', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Totale Entrate'),
                    Text('+${fmt.format(totalIncome)}', style: const TextStyle(color: Colors.green)),
                  ],
                ),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Totale Uscite'),
                    Text('-${fmt.format(totalExpense)}', style: const TextStyle(color: Colors.red)),
                  ],
                ),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Saldo Netto'),
                    Text(fmt.format(totalIncome - totalExpense),
                        style: TextStyle(
                            color: (totalIncome - totalExpense) >= 0
                                ? Colors.green
                                : Colors.red,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Text('Spese per Categoria', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        if (pieSections.isEmpty)
          Container(
            height: 200,
            color: Colors.grey.shade200,
            alignment: Alignment.center,
            child: const Text('Nessuna spesa registrata'),
          )
        else
          SizedBox(
            height: 220,
            child: Stack(
              children: [
                PieChart(
                  PieChartData(
                    sections: pieSections,
                    centerSpaceRadius: 40,
                    sectionsSpace: 2,
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Totale', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    Text(fmt.format(totalExpense),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
        const SizedBox(height: 16),
        ...expensesByCategory.entries.map((e) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(color: _categoryColor(e.key), shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_categoryName(e.key))),
                  Text(fmt.format(e.value)),
                ],
              ),
            )),
        const SizedBox(height: 24),
        const Text('Trend Spese Mensile', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        if (sortedMonths.isEmpty)
          Container(
            height: 200,
            color: Colors.grey.shade200,
            alignment: Alignment.center,
            child: const Text('Nessun dato disponibile'),
          )
        else
          SizedBox(
            height: 220,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: (monthlyExpenses.values.reduce((a, b) => a > b ? a : b) * 1.1).clamp(1, double.infinity),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
                      '${sortedMonths[groupIndex]}\n${fmt.format(rod.toY)}',
                      const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= sortedMonths.length) return const Text('');
                        final month = sortedMonths[idx];
                        final label = DateFormat('MMM').format(DateTime.parse('$month-01'));
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(label, style: const TextStyle(fontSize: 10)),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: sortedMonths.asMap().entries.map((e) {
                  return BarChartGroupData(
                    x: e.key,
                    barRods: [
                      BarChartRodData(
                        toY: monthlyExpenses[e.value]!,
                        color: Colors.redAccent,
                        width: 18,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        const SizedBox(height: 24),
        const Text('Trend Saldo', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        if (monthlyData.isEmpty)
          Container(
            height: 200,
            color: Colors.grey.shade200,
            alignment: Alignment.center,
            child: const Text('Nessun dato disponibile'),
          )
        else
          SizedBox(
            height: 220,
            child: LineChart(
              LineChartData(
                minY: monthlyBalance.values.reduce((a, b) => a < b ? a : b) * 1.05,
                maxY: monthlyBalance.values.reduce((a, b) => a > b ? a : b) * 1.05,
                borderData: FlBorderData(show: false),
                gridData: const FlGridData(show: true),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= monthlyData.length) return const Text('');
                        final month = monthlyData[idx];
                        final label = DateFormat('MMM').format(DateTime.parse('$month-01'));
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(label, style: const TextStyle(fontSize: 10)),
                        );
                      },
                    ),
                  ),
                ),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (spots) => spots.map((spot) {
                      final idx = spot.x.toInt();
                      return LineTooltipItem(
                        '${monthlyData[idx]}\n${fmt.format(spot.y)}',
                        const TextStyle(color: Colors.white),
                      );
                    }).toList(),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: monthlyData.asMap().entries.map((e) {
                      return FlSpot(
                        e.key.toDouble(),
                        monthlyBalance[e.value]!.clamp(double.negativeInfinity, double.infinity),
                      );
                    }).toList(),
                    isCurved: true,
                    color: Colors.green,
                    barWidth: 3,
                    belowBarData: BarAreaData(
                      show: true,
                      color: Colors.green.withValues(alpha: 0.2),
                    ),
                    dotData: const FlDotData(show: true),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 24),
      ],
    );
  }
}