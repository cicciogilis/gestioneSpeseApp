import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/transaction.dart';

class TransactionRepository {
  static const String _transactionsKey = 'local_transactions';
  static const String _legacyOfflineQueueKey = 'offline_transactions';
  static const String _legacyReadCacheKey = 'cached_transactions';
  static const String _recurrenceLedgerKey = 'recurrence_ledger';
  static int _idCounter = 0;

  Future<List<AppTransaction>> getTransactions() async {
    final prefs = await SharedPreferences.getInstance();
    final transactions = await _loadTransactions(prefs);
    final updated = await _materializeDueRecurrences(transactions, prefs);
    updated.sort((a, b) => b.date.compareTo(a.date));
    return updated;
  }

  Future<void> addTransaction(AppTransaction tx) async {
    final prefs = await SharedPreferences.getInstance();
    final transactions = await _loadTransactions(prefs);
    final stored = tx.id == null
        ? AppTransaction(
            id: _newId(),
            amount: tx.amount,
            type: tx.type,
            categoryId: tx.categoryId,
            method: tx.method,
            date: tx.date,
            description: tx.description,
            aiSummary: tx.aiSummary,
            recurrence: tx.recurrence,
          )
        : tx;
    transactions.add(stored);
    await _saveTransactions(prefs, transactions);
  }

  Future<List<AppTransaction>> _loadTransactions(SharedPreferences prefs) async {
    final encoded = prefs.getStringList(_transactionsKey);
    if (encoded != null) {
      return _decodeTransactions(encoded);
    }

    final legacyEncoded = <String>[
      ...(prefs.getStringList(_legacyOfflineQueueKey) ?? []),
      ...(prefs.getStringList(_legacyReadCacheKey) ?? []),
    ];
    if (legacyEncoded.isEmpty) {
      return <AppTransaction>[];
    }

    final migrated = _deduplicate(_decodeTransactions(legacyEncoded));
    await _saveTransactions(prefs, migrated);
    return migrated;
  }

  List<AppTransaction> _decodeTransactions(List<String> encoded) {
    final transactions = <AppTransaction>[];
    for (final item in encoded) {
      try {
        transactions.add(AppTransaction.fromMap(jsonDecode(item) as Map<String, dynamic>));
      } catch (_) {}
    }
    return _deduplicate(transactions);
  }

  List<AppTransaction> _deduplicate(List<AppTransaction> transactions) {
    final byKey = <String, AppTransaction>{};
    for (final tx in transactions) {
      final key = tx.id ?? jsonEncode(tx.toMap());
      byKey.putIfAbsent(key, () => tx);
    }
    return byKey.values.toList();
  }

  Future<void> _saveTransactions(
    SharedPreferences prefs,
    List<AppTransaction> transactions,
  ) async {
    await prefs.setStringList(
      _transactionsKey,
      transactions.map((tx) => jsonEncode(tx.toMap())).toList(),
    );
  }

  Future<List<AppTransaction>> _materializeDueRecurrences(
    List<AppTransaction> transactions,
    SharedPreferences prefs,
  ) async {
    final ledger = prefs.getStringList(_recurrenceLedgerKey) ?? [];
    final ledgerMap = <String, String>{
      for (final item in ledger)
        if (item.contains('::')) item.split('::').first: item.split('::').last,
    };
    final newlyGenerated = <AppTransaction>[];

    for (final base in List.of(transactions)) {
      if (!base.recurrence.isRecurring || base.id == null) {
        continue;
      }

      DateTime cursor = ledgerMap[base.id] != null
          ? DateTime.tryParse(ledgerMap[base.id]!) ?? base.date
          : base.date;
      var guard = 0;
      while (guard < 36) {
        cursor = base.recurrence.nextAfter(cursor);
        if (cursor.isAfter(DateTime.now())) {
          break;
        }
        newlyGenerated.add(
          AppTransaction(
            id: _newId(),
            amount: base.amount,
            type: base.type,
            categoryId: base.categoryId,
            method: base.method,
            date: cursor,
            description: base.description,
            aiSummary: base.aiSummary,
            recurrence: Recurrence.none,
          ),
        );
        ledgerMap[base.id!] = cursor.toIso8601String();
        guard++;
      }
    }

    if (newlyGenerated.isEmpty) {
      return transactions;
    }

    final updated = <AppTransaction>[...transactions, ...newlyGenerated];
    await _saveTransactions(prefs, updated);
    await prefs.setStringList(
      _recurrenceLedgerKey,
      ledgerMap.entries.map((e) => '${e.key}::${e.value}').toList(),
    );
    return updated;
  }

  static String _newId() {
    _idCounter++;
    return 'local_${DateTime.now().toUtc().microsecondsSinceEpoch}_$_idCounter';
  }
}
