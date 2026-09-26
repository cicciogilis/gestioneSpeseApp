import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/template_ricorrente.dart';
import '../../domain/models/transaction.dart';

class TransactionRepository {
  static const String _transactionsKey = 'local_transactions';
  static const String _legacyOfflineQueueKey = 'offline_transactions';
  static const String _legacyReadCacheKey = 'cached_transactions';
  static const String _recurrenceLedgerKey = 'recurrence_ledger';
  static const String _templatesKey = 'templates_ricorrenti';
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
    
    // If transaction has a recurrence, create/update template
    if (tx.recurrence.isRecurring) {
      await _saveTemplate(TemplateRicorrente(
        id: tx.ricorrenzaId,
        amount: tx.amount,
        type: tx.type,
        categoryId: tx.categoryId,
        method: tx.method,
        description: tx.description,
        recurrence: tx.recurrence,
        dataInizio: tx.date,
        dataProssimaOccorrenza: tx.recurrence.nextAfter(tx.date),
        attivo: true,
      ), prefs);
    }
    
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
            ricorrenzaId: tx.ricorrenzaId,
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

  Future<void> _saveTemplate(TemplateRicorrente template, SharedPreferences prefs) async {
    final templates = await _loadTemplates(prefs);
    final existingIndex = templates.indexWhere((t) => t.id == template.id);
    
    final templateToSave = template.id == null
        ? TemplateRicorrente(
            id: _newId(),
            amount: template.amount,
            type: template.type,
            categoryId: template.categoryId,
            method: template.method,
            description: template.description,
            recurrence: template.recurrence,
            dataInizio: template.dataInizio,
            dataProssimaOccorrenza: template.dataProssimaOccorrenza,
            attivo: template.attivo,
          )
        : template;
    
    if (existingIndex >= 0) {
      templates[existingIndex] = templateToSave;
    } else {
      templates.add(templateToSave);
    }
    
    await prefs.setStringList(
      _templatesKey,
      templates.map((t) => jsonEncode(t.toMap())).toList(),
    );
  }

  Future<List<TemplateRicorrente>> _loadTemplates(SharedPreferences prefs) async {
    final encoded = prefs.getStringList(_templatesKey);
    if (encoded != null) {
      return encoded
          .map((e) => TemplateRicorrente.fromMap(jsonDecode(e) as Map<String, dynamic>))
          .toList();
    }
    return <TemplateRicorrente>[];
  }

  Future<List<TemplateRicorrente>> getTemplates() async {
    final prefs = await SharedPreferences.getInstance();
    return _loadTemplates(prefs);
  }

  Future<void> processaRicorrenzePendenti() async {
    final prefs = await SharedPreferences.getInstance();
    final templates = await _loadTemplates(prefs);
    final transactions = await _loadTransactions(prefs);
    final ledger = prefs.getStringList(_recurrenceLedgerKey) ?? [];
    final ledgerMap = <String, String>{
      for (final item in ledger)
        if (item.contains('::')) item.split('::').first: item.split('::').last,
    };
    final newlyGenerated = <AppTransaction>[];
    bool hasUpdates = false;

    for (final template in templates) {
      if (!template.attivo || !template.recurrence.isRecurring) {
        continue;
      }

      DateTime cursor = ledgerMap[template.id] != null
          ? DateTime.tryParse(ledgerMap[template.id!]!) ?? template.dataProssimaOccorrenza
          : template.dataProssimaOccorrenza;
      
      var guard = 0;
      while (guard < 36) {
        cursor = template.recurrence.nextAfter(cursor);
        if (cursor.isAfter(DateTime.now())) {
          break;
        }
        
        newlyGenerated.add(
          AppTransaction(
            id: _newId(),
            amount: template.amount,
            type: template.type,
            categoryId: template.categoryId,
            method: template.method,
            date: cursor,
            description: template.description,
            recurrence: Recurrence.none,
            ricorrenzaId: template.id,
          ),
        );
        ledgerMap[template.id!] = cursor.toIso8601String();
        hasUpdates = true;
        guard++;
      }
      
      if (hasUpdates) {
        final updatedTemplate = TemplateRicorrente(
          id: template.id,
          amount: template.amount,
          type: template.type,
          categoryId: template.categoryId,
          method: template.method,
          description: template.description,
          recurrence: template.recurrence,
          dataInizio: template.dataInizio,
          dataProssimaOccorrenza: cursor,
          attivo: template.attivo,
        );
        await _saveTemplate(updatedTemplate, prefs);
      }
    }

    if (newlyGenerated.isNotEmpty) {
      final allTransactions = [...transactions, ...newlyGenerated];
      await _saveTransactions(prefs, allTransactions);
    }
    
    if (hasUpdates) {
      await prefs.setStringList(
        _recurrenceLedgerKey,
        ledgerMap.entries.map((e) => '${e.key}::${e.value}').toList(),
      );
    }
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

  Future<List<int>> getAvailableYears() async {
    final transactions = await getTransactions();
    if (transactions.isEmpty) {
      return [DateTime.now().year];
    }
    final years = transactions
        .map((tx) => tx.date.year)
        .toSet()
        .toList()
      ..sort();
    final now = DateTime.now();
    if (!years.contains(now.year)) {
      years.add(now.year);
      years.sort();
    }
    return years;
  }

  Future<List<AppTransaction>> getTransactionsForMonth(int year, int month) async {
    final all = await getTransactions();
    return all.where((tx) => tx.date.year == year && tx.date.month == month).toList();
  }

  Future<List<AppTransaction>> getTransactionsForPeriod(
      int year, int month, int monthsBack) async {
    final all = await getTransactions();
    final results = <AppTransaction>[];
    for (int i = 0; i < monthsBack; i++) {
      int m = month - i;
      int y = year;
      while (m < 1) {
        m += 12;
        y -= 1;
      }
      results.addAll(all.where((tx) => tx.date.year == y && tx.date.month == m));
    }
    return results;
  }

  Future<void> deleteTransaction(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final transactions = await _loadTransactions(prefs);
    
    // Prevent deletion of system initial balance transactions
    final txToDelete = transactions.firstWhere(
      (tx) => tx.id == id,
      orElse: () => throw Exception('Transazione non trovata'),
    );
    
    if (txToDelete.isSystemInitialBalance) {
      throw Exception('Non è possibile eliminare il saldo iniziale di sistema');
    }
    
    final filtered = transactions.where((tx) => tx.id != id).toList();
    await _saveTransactions(prefs, filtered);
  }

  Future<AppTransaction?> getTransactionById(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final transactions = await _loadTransactions(prefs);
    final index = transactions.indexWhere((tx) => tx.id == id);
    return index >= 0 ? transactions[index] : null;
  }

  Future<void> deleteFutureRecurrences(String ricorrenzaId) async {
    final prefs = await SharedPreferences.getInstance();
    final transactions = await _loadTransactions(prefs);
    final filtered = transactions.where((tx) => tx.ricorrenzaId != ricorrenzaId).toList();
    await _saveTransactions(prefs, filtered);
    
    // Also deactivate the template
    final templates = await _loadTemplates(prefs);
    final idx = templates.indexWhere((t) => t.id == ricorrenzaId);
    if (idx >= 0) {
      final template = templates[idx];
      final updated = TemplateRicorrente(
        id: template.id,
        amount: template.amount,
        type: template.type,
        categoryId: template.categoryId,
        method: template.method,
        description: template.description,
        recurrence: template.recurrence,
        dataInizio: template.dataInizio,
        dataProssimaOccorrenza: template.dataProssimaOccorrenza,
        attivo: false,
      );
      templates[idx] = updated;
      await prefs.setStringList(
        _templatesKey,
        templates.map((t) => jsonEncode(t.toMap())).toList(),
      );
    }
  }

  static String _newId() {
    _idCounter++;
    return 'local_${DateTime.now().toUtc().microsecondsSinceEpoch}_$_idCounter';
  }
}