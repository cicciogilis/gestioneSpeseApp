import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/constants/seed_categories.dart';
import '../../core/providers/app_providers.dart';
import '../../core/providers/month_balance_provider.dart';
import '../../core/providers/selected_period_provider.dart';
import '../../domain/models/transaction.dart';
import '../../domain/models/category.dart';
import '../../utils/category_utils.dart';

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  // Categorie escluse dal grafico a torta (solo per vista corrente, reset all'uscita)
  final Set<String> _excludedCategoryIds = {};

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
        data: (allTransactions) {
          final balanceAsync = ref.watch(monthBalanceProvider);
          final saldoIniziale =
              balanceAsync.when(data: (b) => b?.baselineAmount ?? 0.0, loading: () => 0.0, error: (_, _) => 0.0);
          return _buildAnalytics(context, allTransactions, saldoIniziale);
        },
      ),
    );
  }

  Color _categoryColor(String categoryId) {
    final cat = seedCategories.firstWhere(
      (c) => c.id == categoryId,
      orElse: () => seedCategories.firstWhere(
        (c) => c.id == 'cat_altro',
        orElse: () => seedCategories.first,
      ),
    );
    return Color(cat.color);
  }

  void _showExcludedCategoriesSheet() {
    final expenseCategories = seedCategories
        .where((c) => c.type == CategoryType.expense && c.id != 'cat_saldo_iniziale')
        .toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Categorie escluse',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Seleziona le categorie da escludere dal grafico a torta',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: expenseCategories.map((cat) {
                    final isExcluded = _excludedCategoryIds.contains(cat.id);
                    return ChoiceChip(
                      label: Text(cat.name),
                      selected: isExcluded,
                      onSelected: (val) {
                        setSheetState(() {
                          if (val) {
                            _excludedCategoryIds.add(cat.id);
                          } else {
                            _excludedCategoryIds.remove(cat.id);
                          }
                        });
                        setState(() {}); // Aggiorna il grafico
                      },
                      avatar: Icon(Icons.category, color: Color(cat.color), size: 18),
                      selectedColor: Color(cat.color).withValues(alpha: 0.3),
                      labelStyle: TextStyle(
                        color: isExcluded ? Color(cat.color) : null,
                        fontWeight: isExcluded ? FontWeight.w600 : null,
                      ),
                    );
                  }).toList(),
                ),
                const Divider(height: 32),
                Row(
                  children: [
                    TextButton(
                      onPressed: () {
                        setSheetState(() {
                          _excludedCategoryIds.clear();
                        });
                        setState(() {});
                      },
                      child: const Text('Azzera'),
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Applica'),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAnalytics(
      BuildContext context, List<AppTransaction> allTransactions, double saldoIniziale) {
    final selectedPeriod = ref.watch(selectedPeriodProvider);
    final periodLabel = selectedPeriod.toString();
    final fmt = NumberFormat.simpleCurrency(locale: 'it_IT');

    // Filter transactions by selected period for summary + pie chart
    final transactions = allTransactions.where((t) {
      return t.date.year == selectedPeriod.year &&
          t.date.month == selectedPeriod.month;
    }).toList();

    double totalIncome = 0.0;
    double totalExpense = 0.0;
    for (var t in transactions) {
      if (t.isSystemInitialBalance) continue;
      if (t.type == TransactionType.income) totalIncome += t.amount;
      if (t.type == TransactionType.expense) totalExpense += t.amount;
    }

    final expensesByCategory = <String, double>{};
    for (final t in transactions) {
      if (t.isSystemInitialBalance) continue;
      if (t.type != TransactionType.expense) continue;
      // Escludi le categorie escluse dall'utente
      if (_excludedCategoryIds.contains(t.categoryId)) continue;
      expensesByCategory.update(
        t.categoryId,
        (v) => v + t.amount,
        ifAbsent: () => t.amount,
      );
    }

    // Trend data uses ALL transactions (not just selected month)
    final monthlyExpensesByCategory = <String, Map<String, double>>{};
    final monthlyBalance = <String, double>{};
    final monthlyData = <String>[];
    for (final t in allTransactions) {
      if (t.isSystemInitialBalance) continue;
      final monthKey = DateFormat('yyyy-MM').format(t.date);
      if (t.type == TransactionType.expense) {
        // Anche qui escludiamo le categorie escluse per coerenza nei trend
        if (!_excludedCategoryIds.contains(t.categoryId)) {
          monthlyExpensesByCategory
              .putIfAbsent(monthKey, () => <String, double>{})
              .update(t.categoryId, (v) => v + t.amount, ifAbsent: () => t.amount);
          monthlyBalance.update(
            monthKey,
            (v) => v - t.amount,
            ifAbsent: () => -t.amount,
          );
        }
      } else if (t.type == TransactionType.income) {
        monthlyBalance.update(
          monthKey,
          (v) => v + t.amount,
          ifAbsent: () => t.amount,
        );
      }
    }
    monthlyData.addAll(monthlyBalance.keys.toList()..sort());
    final sortedMonths = monthlyExpensesByCategory.keys.toList()..sort();

    final pieSections = expensesByCategory.entries.map((e) {
      return PieChartSectionData(
        value: e.value,
        title:
            '${(e.value / (totalExpense == 0 ? 1 : totalExpense) * 100).toStringAsFixed(0)}%',
        color: _categoryColor(e.key),
        radius: 40,
        titleStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white),
      );
    }).toList();

    final allCategoryIds = <String>{
      ...expensesByCategory.keys,
      for (final cats in monthlyExpensesByCategory.values) ...cats.keys,
    };

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        Text('Riassunto — $periodLabel',
            style:
                const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Saldo Iniziale'),
                      Text(fmt.format(saldoIniziale),
                          style: const TextStyle(color: Colors.blueGrey)),
                    ],
                  ),
                  const Divider(),
                  Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Totale Entrate'),
                    Text('+${fmt.format(totalIncome)}',
                        style: const TextStyle(color: Colors.green)),
                  ],
                ),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Totale Uscite'),
                    Text('-${fmt.format(totalExpense)}',
                        style: const TextStyle(color: Colors.red)),
                  ],
                ),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Saldo Netto'),
                    Text(
                      fmt.format(totalIncome - totalExpense),
                      style: TextStyle(
                        color: (totalIncome - totalExpense) >= 0
                            ? Colors.green
                            : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Spese per Categoria',
                style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            IconButton(
              icon: const Icon(Icons.filter_list),
              tooltip: 'Categorie escluse',
              onPressed: _showExcludedCategoriesSheet,
            ),
          ],
        ),
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
                    const Text('Totale',
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                    Text(fmt.format(totalExpense),
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
        const SizedBox(height: 16),
        ...expensesByCategory.entries.map(
          (e) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                      color: _categoryColor(e.key), shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(categoryDisplayName(e.key))),
                Text(fmt.format(e.value)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Text('Trend Spese Mensile',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        if (monthlyExpensesByCategory.isEmpty)
          Container(
            height: 200,
            color: Colors.grey.shade200,
            alignment: Alignment.center,
            child: const Text('Nessun dato disponibile'),
          )
        else
          Column(
            children: [
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: allCategoryIds.map((catId) {
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                            color: _categoryColor(catId),
                            shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 4),
                      Text(categoryDisplayName(catId),
                          style:
                              const TextStyle(fontSize: 11)),
                    ],
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 220,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: (monthlyExpensesByCategory.values
                            .map((cats) => cats.values.fold(
                                0.0, (a, b) => a + b))
                            .reduce((a, b) => a > b ? a : b) *
                        1.1)
                        .clamp(1, double.infinity),
                    barTouchData: BarTouchData(
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipItem:
                            (group, groupIndex, rod, rodIndex) {
                          final month = sortedMonths[groupIndex];
                          return BarTooltipItem(
                            '$month\n${fmt.format(rod.toY)}',
                            const TextStyle(color: Colors.white),
                          );
                        },
                      ),
                    ),
                    titlesData: FlTitlesData(
                      leftTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            final idx = value.toInt();
                            if (idx < 0 || idx >= sortedMonths.length) {
                              return const Text('');
                            }
                            final month = sortedMonths[idx];
                            final label = DateFormat('MMM').format(
                                DateTime.parse('$month-01'));
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(label,
                                  style:
                                      const TextStyle(fontSize: 10)),
                            );
                          },
                        ),
                      ),
                    ),
                    barGroups: sortedMonths.asMap().entries.map((e) {
                      final monthKey = e.value;
                      final cats = monthlyExpensesByCategory[monthKey]!;
                      final sortedCats =
                          cats.entries.toList()..sort((a, b) => a.key.compareTo(b.key));

                      final rodStackItems = <BarChartRodStackItem>[];
                      double currentY = 0;
                      for (final catEntry in sortedCats) {
                        rodStackItems.add(BarChartRodStackItem(
                          currentY,
                          currentY + catEntry.value,
                          _categoryColor(catEntry.key),
                        ));
                        currentY += catEntry.value;
                      }

                      return BarChartGroupData(
                        x: e.key,
                        barRods: [
                          BarChartRodData(
                            toY: cats.values.fold(0.0, (a, b) => a + b),
                            width: 18,
                            borderRadius: BorderRadius.circular(4),
                            rodStackItems: rodStackItems,
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        const SizedBox(height: 24),
        const Text('Trend Saldo Annuale',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                minY: monthlyBalance.values
                        .reduce((a, b) => a < b ? a : b) *
                    1.05,
                maxY: monthlyBalance.values
                        .reduce((a, b) => a > b ? a : b) *
                    1.05,
                borderData: FlBorderData(show: false),
                gridData: const FlGridData(show: true),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                   bottomTitles: AxisTitles(
                     sideTitles: SideTitles(
                       showTitles: true,
                       getTitlesWidget: (value, meta) {
                         final idx = value.toInt();
                         if (idx < 0 || idx >= monthlyData.length) {
                           return const Text('');
                         }
                         final month = monthlyData[idx];
                          final monthDt =
                              DateTime.parse('$month-01');
                          final label = DateFormat('MMM')
                              .format(monthDt);
                          // When the month abbreviation is the same as the
                          // previous one (e.g. Jan across different years),
                          // append the year to keep labels distinguishable.
                          final prevLabel = idx > 0
                              ? DateFormat('MMM').format(
                                  DateTime.parse('${monthlyData[idx - 1]}-01'))
                              : null;
                          final displayLabel = prevLabel == label
                              ? DateFormat('MMM yy').format(monthDt)
                              : label;
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(displayLabel,
                                style: const TextStyle(fontSize: 10)),
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
                        monthlyBalance[e.value]!.clamp(
                            double.negativeInfinity, double.infinity),
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
