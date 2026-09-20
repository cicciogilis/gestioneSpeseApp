import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/constants/seed_categories.dart';
import '../../core/providers/app_providers.dart';
import '../../core/providers/selected_period_provider.dart';
import '../../data/repositories/transaction_repository.dart';
import '../../domain/models/transaction.dart';

class TransactionListScreen extends ConsumerStatefulWidget {
  const TransactionListScreen({super.key});

  @override
  ConsumerState<TransactionListScreen> createState() =>
      _TransactionListScreenState();
}

class _TransactionListScreenState extends ConsumerState<TransactionListScreen> {
  final String _searchQuery = '';
  String _selectedTypeFilter = 'Tutti';
  String? _selectedCategoryId;

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
           final selectedPeriod = ref.watch(selectedPeriodProvider);
           
           final filtered = transactions.where((tx) {
             final matchesSearch = _searchQuery.isEmpty ||
                 (tx.description
                         ?.toLowerCase()
                         .contains(_searchQuery.toLowerCase()) ??
                     false) ||
                 tx.categoryId
                     .toLowerCase()
                     .contains(_searchQuery.toLowerCase());

             final matchesType = _selectedTypeFilter == 'Tutti' ||
                 (tx.type == TransactionType.expense &&
                     _selectedTypeFilter == 'Uscite') ||
                 (tx.type == TransactionType.income &&
                     _selectedTypeFilter == 'Entrate');

             final matchesCategory = _selectedCategoryId == null ||
                 tx.categoryId == _selectedCategoryId;

             // Filter by selected period (month/year)
             final matchesPeriod = 
                 tx.date.year == selectedPeriod.year && 
                 tx.date.month == selectedPeriod.month;

             return matchesSearch && matchesType && matchesCategory && matchesPeriod;
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
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                direction: DismissDirection.endToStart,
                onDismissed: (direction) {
                  setState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Transazione eliminata dalla vista'),
                    ),
                  );
                },
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: (() {
                      final cat = seedCategories.firstWhere(
                        (c) => c.id == tx.categoryId,
                        orElse: () => seedCategories.firstWhere(
                          (c) => c.id == 'cat_altro',
                          orElse: () => seedCategories.first,
                        ),
                      );
                      return Color(cat.color);
                    })(),
                    child: Icon(
                      tx.type == TransactionType.expense
                          ? Icons.shopping_cart
                          : Icons.attach_money,
                      color: Colors.white,
                    ),
                  ),
                  title: Text(
                    tx.description ?? tx.categoryId,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (() {
                          final cat = seedCategories.firstWhere(
                            (c) => c.id == tx.categoryId,
                            orElse: () => seedCategories.firstWhere(
                              (c) => c.id == 'cat_altro',
                              orElse: () => seedCategories.first,
                            ),
                          );
                          return cat.name;
                        })(),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      Row(
                        children: [
                          Text(DateFormat('dd MMM yy').format(tx.date)),
                          const SizedBox(width: 8),
                          Icon(
                            tx.method.icon,
                            size: 12,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            tx.method.label,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          if (tx.recurrence.isRecurring) ...[
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.repeat,
                              size: 12,
                              color: Colors.grey,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (tx.recurrence.isRecurring && tx.ricorrenzaId != null)
                        IconButton(
                          icon: const Icon(
                            Icons.settings,
                            size: 20,
                            color: Colors.grey,
                          ),
                          onPressed: () => _showRecurrenceBottomSheet(tx),
                        ),
                      Text(
                        (tx.type == TransactionType.expense ? '-' : '+') +
                            NumberFormat.simpleCurrency(locale: 'it_IT')
                                .format(tx.amount),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: tx.type == TransactionType.expense
                              ? Colors.red
                              : Colors.green,
                        ),
                      ),
                    ],
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
                const Text(
                  'Filtri',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Tipo',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'Tutti', label: Text('Tutti')),
                    ButtonSegment(value: 'Entrate', label: Text('Entrate')),
                    ButtonSegment(value: 'Uscite', label: Text('Uscite')),
                  ],
                  selected: {_selectedTypeFilter},
                  onSelectionChanged: (selection) {
                    setSheetState(() => _selectedTypeFilter = selection.first);
                  },
                ),
                const SizedBox(height: 16),
                const Text(
                  'Categoria',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Tutte'),
                      selected: _selectedCategoryId == null,
                      onSelected: (val) => setSheetState(
                        () => _selectedCategoryId =
                            val ? null : _selectedCategoryId,
                      ),
                    ),
                    ...seedCategories.map((cat) {
                      final isSelected = _selectedCategoryId == cat.id;

                      return ChoiceChip(
                        label: Text(cat.name),
                        selected: isSelected,
                        onSelected: (val) => setSheetState(
                          () => _selectedCategoryId = val ? cat.id : null,
                        ),
                      );
                    }),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Mese',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Consumer(
                  builder: (context, ref, child) {
                    final selectedPeriod = ref.watch(selectedPeriodProvider);
                    final now = DateTime.now();
                    final maxMonth = (selectedPeriod.year == now.year) ? now.month : 12;
                    
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: List.generate(maxMonth, (index) {
                          final month = index + 1;
                          final isSelected = 
                              selectedPeriod.year == now.year && 
                              selectedPeriod.month == month;
                          final label = DateFormat('MMM', 'it_IT').format(DateTime(now.year, month));
                          
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(label),
                              selected: isSelected,
                              onSelected: (_) {
                                ref.read(selectedPeriodProvider.notifier).setPeriod(
                                  now.year,
                                  month,
                                );
                                setSheetState(() {});
                              },
                              selectedColor: Theme.of(context).colorScheme.primary,
                              labelStyle: TextStyle(
                                color: isSelected ? Colors.white : null,
                              ),
                            ),
                          );
                        }),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    TextButton(
                      onPressed: () {
                        setSheetState(() {
                          _selectedTypeFilter = 'Tutti';
                          _selectedCategoryId = null;
                          ref.read(selectedPeriodProvider.notifier).setPeriod(
                            DateTime.now().year,
                            DateTime.now().month,
                          );
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

  void _showRecurrenceBottomSheet(AppTransaction tx) {
    if (tx.ricorrenzaId == null) return;

    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Opzioni ricorrenza',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Modifica questa occorrenza'),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/add', extra: {
                    'amount': tx.amount,
                    'date': tx.date.toIso8601String().split('T').first,
                    'category': tx.categoryId,
                    'title': tx.description ?? tx.categoryId,
                    'method': tx.method.name,
                    'description': tx.description,
                    'recurrence': Recurrence.none, // scollega dalla ricorrenza
                  });
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit_note),
                title: const Text('Modifica tutte le occorrenze future'),
                onTap: () async {
                  Navigator.pop(ctx);
                  final repo = TransactionRepository();
                  final templates = await repo.getTemplates();
                  final template = templates.firstWhere(
                    (t) => t.id == tx.ricorrenzaId,
                    orElse: () => throw Exception('Template non trovato'),
                  );
                  
                  // Apri form precompilato con dati template
                  if (mounted) {
                    context.push('/add', extra: {
                      'amount': template.amount,
                      'date': template.dataProssimaOccorrenza.toIso8601String().split('T').first,
                      'category': template.categoryId,
                      'title': template.description ?? template.categoryId,
                      'method': template.method.name,
                      'description': template.description,
                      'recurrence': template.recurrence,
                      'editTemplate': true,
                      'templateId': template.id,
                    });
                  }
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Elimina questa occorrenza', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(ctx);
                  ref
                      .read(transactionsProvider.notifier)
                      .deleteTransaction(tx.id!);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_forever, color: Colors.red),
                title: const Text('Elimina tutte le occorrenze future', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(ctx);
                  ref
                      .read(transactionsProvider.notifier)
                      .deleteFutureRecurrences(tx.ricorrenzaId!);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TransactionSearchDelegate extends SearchDelegate<String> {
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
          loading: () => <AppTransaction>[],
          error: (err, stack) => <AppTransaction>[],
          data: (list) => list
              .where(
                (tx) =>
                    (tx.description
                            ?.toLowerCase()
                            .contains(query.toLowerCase()) ??
                        false) ||
                    tx.categoryId.toLowerCase().contains(query.toLowerCase()),
              )
              .toList(),
        );

    return ListView.builder(
      itemCount: suggestions.length,
      itemBuilder: (context, index) {
        final tx = suggestions[index];

        return ListTile(
          title: Text(tx.description ?? tx.categoryId),
          subtitle: Text(DateFormat('dd MMM yy').format(tx.date)),
          trailing: Text(
            NumberFormat.simpleCurrency(locale: 'it_IT').format(tx.amount),
          ),
        );
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return buildResults(context);
  }
}