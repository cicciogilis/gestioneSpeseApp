import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/month_balance.dart';
import '../../domain/models/transaction.dart';
import '../repositories/transaction_repository.dart';

abstract class MonthBalanceRepository {
  Future<MonthBalance?> getMonthBalance(int year, int month);
  Future<void> upsertMonthBalance(MonthBalance value);
  Future<void> recalcCascadeFrom(int year, int month);
  Future<List<int>> getAvailableYears();
  Future<Map<String, MonthBalance>> getAllBalances();
}

class MonthBalanceRepositoryImpl implements MonthBalanceRepository {
  static const String _balancesKey = 'month_balances';
  static const String _onboardingDoneKey = 'initialBalance_onboarding_done';
  static const String _lastMessageShownKey = 'monthAutoBalanceMessage_lastShown';

  final TransactionRepository _txRepo;

  MonthBalanceRepositoryImpl({TransactionRepository? txRepo})
      : _txRepo = txRepo ?? TransactionRepository();

  String _balanceKey(int year, int month) => '${_balancesKey}_${year}_$month';
  String _encode(MonthBalance b) => jsonEncode(b.toMap());
  MonthBalance? _decode(String? jsonStr) {
    if (jsonStr == null || jsonStr.isEmpty) return null;
    try {
      return MonthBalance.fromMap(jsonDecode(jsonStr) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();

  @override
  Future<MonthBalance?> getMonthBalance(int year, int month) async {
    final prefs = await _prefs();
    final stored = _decode(prefs.getString(_balanceKey(year, month)));
    if (stored != null) return stored;

    final now = DateTime.now();
    final isCurrentMonth = year == now.year && month == now.month;

    return MonthBalance(
      year: year,
      month: month,
      baselineType: isCurrentMonth ? MonthBalance.baselineMonthStart : MonthBalance.baselineMonthStart,
      baselineDate: DateTime(year, month, 1),
      baselineAmount: 0.0,
    );
  }

  @override
  Future<void> upsertMonthBalance(MonthBalance value) async {
    final prefs = await _prefs();
    await prefs.setString(_balanceKey(value.year, value.month), _encode(value));
  }

  @override
  Future<void> recalcCascadeFrom(int year, int month) async {
    final prefs = await _prefs();
    final txns = await _txRepo.getTransactions();

    int cy = year;
    int cm = month;

    for (int i = 0; i < 36; i++) {
      final prevYear = cm == 1 ? cy - 1 : cy;
      final prevMonth = cm == 1 ? 12 : cm - 1;

      final prevBalance = await getMonthBalance(prevYear, prevMonth);
      if (prevBalance == null) break;

      final prevStart = DateTime(prevYear, prevMonth, 1);
      final prevEnd = DateTime(prevYear, prevMonth + 1, 0);

      double income = 0;
      double expense = 0;
      for (final tx in txns) {
        final inRange = !tx.date.isBefore(prevStart) && !tx.date.isAfter(prevEnd);
        if (!inRange) continue;
        if (tx.type == TransactionType.income) {
          income += tx.amount;
        } else if (tx.type == TransactionType.expense) {
          expense += tx.amount;
        }
      }

      final computed = prevBalance.baselineAmount + income - expense;

      await prefs.setString(
        _balanceKey(cy, cm),
        _encode(MonthBalance(
          year: cy,
          month: cm,
          baselineType: MonthBalance.baselineMonthStart,
          baselineDate: DateTime(cy, cm, 1),
          baselineAmount: computed,
        )),
      );

      if (cm == 12) {
        cy += 1;
        cm = 1;
      } else {
        cm += 1;
      }
    }
  }

  @override
  Future<List<int>> getAvailableYears() async {
    final prefs = await _prefs();
    final years = <int>{};
    for (final key in prefs.getKeys()) {
      if (key.startsWith(_balancesKey)) {
        final parts = key.split('_');
        if (parts.length >= 2) {
          final year = int.tryParse(parts[parts.length - 2]);
          final month = int.tryParse(parts[parts.length - 1]);
          if (year != null && month != null && month >= 1 && month <= 12) {
            years.add(year);
          }
        }
      }
    }
    final now = DateTime.now();
    years.add(now.year);
    if (years.isEmpty) return [now.year];
    final sorted = years.toList()..sort();
    return sorted;
  }

  @override
  Future<Map<String, MonthBalance>> getAllBalances() async {
    final prefs = await _prefs();
    final result = <String, MonthBalance>{};
    for (final key in prefs.getKeys()) {
      if (key.startsWith(_balancesKey)) {
        final balance = _decode(prefs.getString(key));
        if (balance != null) {
          result['${balance.year}-${balance.month.toString().padLeft(2, '0')}'] = balance;
        }
      }
    }
    return result;
  }

  Future<void> migrateLegacyBalances() async {
    final prefs = await _prefs();
    final legacyKeyPrefix = 'saldo_iniziale_';
    final migrated = <String, bool>{};

    for (final key in prefs.getKeys()) {
      if (!key.startsWith(legacyKeyPrefix)) continue;
      final parts = key.split('_');
      if (parts.length < 4) continue;

      final year = int.tryParse(parts[2]);
      final month = int.tryParse(parts[3]);
      if (year == null || month == null) continue;

      if (prefs.containsKey(_balanceKey(year, month))) continue;

      final amount = prefs.getDouble(key) ?? 0.0;
      final balance = MonthBalance(
        year: year,
        month: month,
        baselineType: MonthBalance.baselineMonthStart,
        baselineDate: DateTime(year, month, 1),
        baselineAmount: amount,
      );
      await upsertMonthBalance(balance);
      migrated[key] = true;
    }
  }

  Future<bool> getOnboardingDone() async {
    final prefs = await _prefs();
    return prefs.getBool(_onboardingDoneKey) ?? false;
  }

  Future<void> setOnboardingDone(bool value) async {
    final prefs = await _prefs();
    await prefs.setBool(_onboardingDoneKey, value);
  }

  Future<String?> getLastMonthAutoBalanceMessage() async {
    final prefs = await _prefs();
    return prefs.getString(_lastMessageShownKey);
  }

  Future<void> setLastMonthAutoBalanceMessage(String value) async {
    final prefs = await _prefs();
    await prefs.setString(_lastMessageShownKey, value);
  }
}
