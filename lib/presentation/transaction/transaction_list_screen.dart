import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/constants/seed_categories.dart';
import '../../core/providers/app_providers.dart';
import '../../domain/models/transaction.dart';

class TransactionListScreen extends ConsumerStatefulWidget {
  const TransactionListScreen({super.key});

  @override
  ConsumerState<TransactionListScreen> createState() => _TransactionListScreenState();
}

class _TransactionListScreenState extends ConsumerState<TransactionListScreen> {
  final String _searchQuery = '';
  String _selectedTypeFilter = 'Tutti';
  String? _selectedCategoryId;
  DateTime? _dateFrom;
  DateTime? _dateTo;

  @override
  Widget build(BuildContext context) {
    final asyncValue = ref.watch(transactionsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lista Transazioni'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => showSearch(
              context: context,
              delegate: TransactionSearchDelegate(ref),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.tune),
            onPressed: _showFilterSheet,
          ),
        ],
      ),
      body: asyncValue.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Errore: $err')),
        data: (transactions) {
          final filtered = transactions.where((tx) {
            final matchesSearch = _searchQuery.isEmpty ||
                (tx.description?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) ||
                tx.categoryId.toLowerCase().contains(_searchQuery.toLowerCase());
            final matchesType = _selectedTypeFilter == 'Tutti' ||
                (tx.type == TransactionType.expense && _selectedTypeFilter == 'Uscite') ||
                (tx.type == TransactionType.income && _selectedTypeFilter == 'Entrate');
            final matchesCategory =
                _selectedCategoryId == null || tx.categoryId == _selectedCategoryId;
            final matchesDate = (_dateFrom == null || !tx.date.isBefore(_dateFrom!)) &&
                (_dateTo == null || !tx.date.isAfter(_dateTo!));
            return matchesSearch && matchesType && matchesCategory && matchesDate;
          }).toList();

          if (filtered.isEmpty) {
            return const Center(child: Text('Nessuna transazione trovata'));
          }

          return ListView.builder(
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final tx = filtered[index];
              return Dismissible(
                key: ValueKey(tx.id ?? UniqueKey().toString()),
                background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    child: const Icon(Icons.delete, color: Colors.white)),
                direction: DismissDirection.endToStart,
                onDismissed: (direction) {
                  setState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Transazione eliminata dalla vista')));
                },
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        tx.type == TransactionType.expense ? Colors.red.shade50 : Colors.green.shade50,
                    child: Icon(
                      tx.type == TransactionType.expense ? Icons.shopping_cart : Icons.attach_money,
                      color: tx.type == TransactionType.expense ? Colors.red : Colors.green,
                    ),
                  ),
                  title: Text(tx.description ?? tx.categoryId,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Row(
                    children: [
                      Text(DateFormat('dd MMM yy').format(tx.date)),
                      if (tx.recurrence.isRecurring) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.repeat, size: 12, color: Colors.grey),
                      ],
                    ],
                  ),
                  trailing: Text(
                    (tx.type == TransactionType.expense ? '-' : '+') +
                        NumberFormat.simpleCurrency(locale: 'it_IT').format(tx.amount),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: tx.type == TransactionType.expense ? Colors.red : Colors.green,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showFilterSheet() {
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
                const Text('Filtri', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                const Text('Tipo', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'Tutti', label: Text('Tutti')),
                    ButtonSegment(value: 'Entrate', label: Text('Entrate')),
                    ButtonSegment(value: 'Uscite', label: Text('Uscite')),
                  ],
                  selected: {_selectedTypeFilter},
                  onSelectionChanged: (set) {
                    setSheetState(() => _selectedTypeFilter = set.first);
                  },
                ),
                const SizedBox(height: 16),
                const Text('Categoria', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Tutte'),
                      selected: _selectedCategoryId == null,
                      onSelected: (val) =>
                          setSheetState(() => _selectedCategoryId = val ? null : _selectedCategoryId),
                    ),
                    ...seedCategories.map((cat) {
                      final isSelected = _selectedCategoryId == cat.id;
                      return ChoiceChip(
                        label: Text(cat.name),
                        selected: isSelected,
                        onSelected: (val) =>
                            setSheetState(() => _selectedCategoryId = val ? cat.id : null),
                      );
                    }),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.date_range),
                        label: Text(_dateFrom == null
                            ? 'Da: qualsiasi'
                            : 'Da: ${DateFormat('dd/MM/yy').format(_dateFrom!)}'),
                        onPressed: () async {
                          final d = await showDatePicker(
                            context: ctx,
                            initialDate: _dateFrom ?? DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (d != null) setSheetState(() => _dateFrom = d);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.date_range),
                        label: Text(_dateTo == null
                            ? 'A: qualsiasi'
                            : 'A: ${DateFormat('dd/MM/yy').format(_dateTo!)}'),
                        onPressed: () async {
                          final d = await showDatePicker(
                            context: ctx,
                            initialDate: _dateTo ?? DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (d != null) setSheetState(() => _dateTo = d);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    TextButton(
                      onPressed: () {
                        setSheetState(() {
                          _selectedTypeFilter = 'Tutti';
                          _selectedCategoryId = null;
                          _dateFrom = null;
                          _dateTo = null;
                        });
                      },
                      child: const Text('Azzera'),
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        setState(() {});
                      },
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
}

class TransactionSearchDelegate extends SearchDelegate<dynamic> {
  final WidgetRef ref;
  TransactionSearchDelegate(this.ref);

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () => query = '',
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, ''),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    final suggestions = ref.read(transactionsProvider).when(
      loading: () => [],
      error: (_, _) => [],
      data: (list) => list.where((tx) =>
          tx.description?.toLowerCase().contains(query.toLowerCase()) ?? false ||
          tx.categoryId.toLowerCase().contains(query.toLowerCase())).toList(),
    );
    return ListView.builder(
      itemCount: suggestions.length,
      itemBuilder: (context, index) {
        final tx = suggestions[index];
        return ListTile(
          title: Text(tx.description ?? tx.categoryId),
          subtitle: Text(DateFormat('dd MMM yy').format(tx.date)),
          trailing: Text(NumberFormat.simpleCurrency(locale: 'it_IT').format(tx.amount)),
        );
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return buildResults(context);
  }
}