import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class AppMigrationService {
  static const String _versionKey = 'app_schema_version';
  static const int _currentVersion = 3; // Incrementa questo a ogni cambiamento schema

  static Future<void> runMigrationsIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final savedVersion = prefs.getInt(_versionKey) ?? 0;

    if (savedVersion >= _currentVersion) return;

    // Esegui migrazioni in ordine
    for (int v = savedVersion + 1; v <= _currentVersion; v++) {
      await _runMigration(v, prefs);
    }

    await prefs.setInt(_versionKey, _currentVersion);
  }

  static Future<void> _runMigration(int version, SharedPreferences prefs) async {
    switch (version) {
      case 1:
        await _migrationV1AddIsInitialBalanceToTransactions(prefs);
        break;
      case 2:
        await _migrationV2AddMonthBalanceSchema(prefs);
        break;
      case 3:
        await _migrationV3UpdateTransactionTypeInitialBalance(prefs);
        break;
      // Aggiungi qui future migrazioni
    }
  }

  /// v1: Aggiunge campo isInitialBalance alle transazioni esistenti
  /// Le transazioni con description="Saldo iniziale" e categoryId="cat_saldo_iniziale" 
  /// vengono marcate come isInitialBalance=true
  static Future<void> _migrationV1AddIsInitialBalanceToTransactions(
    SharedPreferences prefs,
  ) async {
    const transactionsKey = 'local_transactions';
    final encoded = prefs.getStringList(transactionsKey);
    if (encoded == null) return;

    final List<String> migrated = [];
    for (final item in encoded) {
      try {
        final map = Map<String, dynamic>.from(jsonDecode(item));
        // Se non ha il campo, inferisci da description/categoryId
        if (!map.containsKey('is_initial_balance')) {
          final desc = map['description'] as String?;
          final catId = map['category_id'] as String?;
          final isInitial = desc == 'Saldo iniziale' && catId == 'cat_saldo_iniziale';
          map['is_initial_balance'] = isInitial;
        }
        migrated.add(jsonEncode(map));
      } catch (_) {
        // Mantieni originale se parsing fallisce
        migrated.add(item);
      }
    }

    await prefs.setStringList(transactionsKey, migrated);
  }

  /// v2: Assicura che month_balances abbia la struttura corretta
  static Future<void> _migrationV2AddMonthBalanceSchema(
    SharedPreferences prefs,
  ) async {
    // Le chiavi sono tipo: month_balances_YYYY_MM
    // Non serve migrazione se già usa il formato corretto
    // Questo placeholder serve per future migrazioni
  }

  /// v3: Aggiorna le transazioni "Saldo iniziale" esistenti al nuovo tipo TransactionType.initialBalance
  static Future<void> _migrationV3UpdateTransactionTypeInitialBalance(
    SharedPreferences prefs,
  ) async {
    const transactionsKey = 'local_transactions';
    final encoded = prefs.getStringList(transactionsKey);
    if (encoded == null) return;

    final List<String> migrated = [];
    for (final item in encoded) {
      try {
        final map = Map<String, dynamic>.from(jsonDecode(item));
        // Se la transazione è un saldo iniziale (description="Saldo iniziale" + categoryId="cat_saldo_iniziale")
        // aggiorna il type a "INITIAL_BALANCE"
        final desc = map['description'] as String?;
        final catId = map['category_id'] as String?;
        final isInitial = desc == 'Saldo iniziale' && catId == 'cat_saldo_iniziale';
        if (isInitial) {
          map['type'] = 'INITIAL_BALANCE';
        }
        migrated.add(jsonEncode(map));
      } catch (_) {
        migrated.add(item);
      }
    }

    await prefs.setStringList(transactionsKey, migrated);
  }

  /// Utility: forza re-esecuzione migrazioni (per testing)
  static Future<void> forceMigrations() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_versionKey);
    await runMigrationsIfNeeded();
  }

  /// Utility: ottieni versione corrente salvata
  static Future<int> getCurrentVersion() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_versionKey) ?? 0;
  }
}