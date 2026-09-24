import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/constants/seed_categories.dart';
import '../../core/providers/app_providers.dart';
import '../../core/providers/selected_period_provider.dart';
import '../../data/repositories/transaction_repository.dart';
import '../../domain/models/transaction.dart';
import '../../utils/category_utils.dart';
import '../../widgets/transaction_card.dart';

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
            onPressed: () async {
              final transactions = asyncValue.maybeWhen(
                data: (list) => list,
                orElse: () => <AppTransaction>[],
              );
              final selectedTransaction = await showSearch<AppTransaction?>(
                context: context,
                delegate: TransactionSearchDelegate(allTransactions: transactions),
              );

              if (selectedTransaction != null && context.mounted) {
                context.push('/add', extra: {
                  'amount': selectedTransaction.amount,
                  'date': selectedTransaction.date.toIso8601String().split('T').first,
                  'category': selectedTransaction.categoryId,
                  'title': transactionTitle(selectedTransaction.description, selectedTransaction.categoryId),
                  'method': selectedTransaction.method.name,
                  'description': selectedTransaction.description,
                });
              }
            },
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
                key: ValueKey(tx.id ?? '${tx.date.toIso8601String()}_${tx.amount}_${tx.categoryId}'),
                background: Container(
                  color: Colors.red,
                  alignment: Alignment.centerRight,
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                direction: DismissDirection.endToStart,
                onDismissed: (direction) async {
                  final messenger = ScaffoldMessenger.of(context);
                  AppTransaction? deleted;
                  try {
                    deleted = await ref
                        .read(transactionsProvider.notifier)
                        .deleteTransaction(tx.id!);
                    messenger.hideCurrentSnackBar();
                    messenger.showSnackBar(
                      SnackBar(
                        content: const Text('Transazione eliminata'),
                        action: deleted != null
                            ? SnackBarAction(
                                label: 'ANNULLA',
                                onPressed: () {
                                  ref
                                      .read(transactionsProvider.notifier)
                                      .restoreTransaction(deleted!);
                                },
                              )
                            : null,
                      ),
                    );
                  } catch (e) {
                    await ref
                        .read(transactionsProvider.notifier)
                        .restoreTransaction(tx);
                    messenger.hideCurrentSnackBar();
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('Errore: $e'),
                      ),
                    );
                  }
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
                    () {
                      final cat = seedCategories.firstWhere(
                        (c) => c.id == tx.categoryId,
                        orElse: () => seedCategories.firstWhere(
                          (c) => c.id == 'cat_altro',
                          orElse: () => seedCategories.first,
                        ),
                      );
                      return cat.iconData;
                    }(),
                    color: Colors.white,
                  ),
                ),
                   title: Text(
                     transactionTitle(tx.description, tx.categoryId),
                     style: const TextStyle(fontWeight: FontWeight.w600),
                   ),
                   subtitle: Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                       Text(
                         categoryDisplayName(tx.categoryId),
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
                    'title': transactionTitle(tx.description, tx.categoryId),
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
                      'title': transactionTitle(template.description, template.categoryId),
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

class TransactionSearchDelegate extends SearchDelegate<AppTransaction?> {
  final List<AppTransaction> allTransactions;

  TransactionSearchDelegate({required this.allTransactions});

  @override
  String get searchFieldLabel => 'Cerca transazione...';

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () {
            query = '';
            showSuggestions(context);
          },
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  List<AppTransaction> _filterTransactions(String searchQuery) {
    if (searchQuery.trim().isEmpty) return [];

    final lowerQuery = searchQuery.toLowerCase().trim();
    return allTransactions.where((tx) {
      final title = transactionTitle(tx.description, tx.categoryId).toLowerCase();
      final category = categoryDisplayName(tx.categoryId).toLowerCase();
      final rawCategoryId = tx.categoryId.toLowerCase();
      final method = tx.method.label.toLowerCase();

      return title.contains(lowerQuery) ||
          category.contains(lowerQuery) ||
          rawCategoryId.contains(lowerQuery) ||
          method.contains(lowerQuery);
    }).toList();
  }

  @override
  Widget buildResults(BuildContext context) {
    final results = _filterTransactions(query);

    if (results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'Nessuna transazione trovata per "$query"',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: results.length,
      itemBuilder: (context, index) {
        final tx = results[index];
        return TransactionCard(
          transaction: tx,
          onTap: () => close(context, tx),
        );
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    final suggestions = _filterTransactions(query);

    if (query.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'Cerca per titolo, categoria o note',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      );
    }

    if (suggestions.isEmpty) {
      return Center(
        child: Text(
          'Nessun suggerimento per "$query"',
          style: TextStyle(fontSize: 15, color: Colors.grey.shade500),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: suggestions.length,
      itemBuilder: (context, index) {
        final tx = suggestions[index];
        return TransactionCard(
          transaction: tx,
          onTap: () {
            query = transactionTitle(tx.description, tx.categoryId);
            showResults(context);
          },
        );
      },
    );
  }
}