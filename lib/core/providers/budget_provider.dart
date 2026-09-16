import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const double defaultGlobalBudgetLimit = 2500.0;
const double defaultSavingGoal = 500.0;
const double defaultInitialBalance = 0.0;

class BudgetSettings {
  final double globalLimit;
  final double savingGoal;
  final double initialBalance;

  const BudgetSettings({
    this.globalLimit = defaultGlobalBudgetLimit,
    this.savingGoal = defaultSavingGoal,
    this.initialBalance = defaultInitialBalance,
  });

  BudgetSettings copyWith({double? globalLimit, double? savingGoal, double? initialBalance}) {
    return BudgetSettings(
      globalLimit: globalLimit ?? this.globalLimit,
      savingGoal: savingGoal ?? this.savingGoal,
      initialBalance: initialBalance ?? this.initialBalance,
    );
  }
}

class BudgetNotifier extends Notifier<BudgetSettings> {
  static const _kLimit = 'global_budget_limit';
  static const _kGoal = 'saving_goal';
  static const _kBalance = 'initial_balance';

  @override
  BudgetSettings build() {
    _load();
    return const BudgetSettings();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = BudgetSettings(
      globalLimit: prefs.getDouble(_kLimit) ?? defaultGlobalBudgetLimit,
      savingGoal: prefs.getDouble(_kGoal) ?? defaultSavingGoal,
      initialBalance: prefs.getDouble(_kBalance) ?? defaultInitialBalance,
    );
  }

  Future<void> setGlobalLimit(double value) async {
    state = state.copyWith(globalLimit: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kLimit, value);
  }

  Future<void> setSavingGoal(double value) async {
    state = state.copyWith(savingGoal: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kGoal, value);
  }

  Future<void> setInitialBalance(double value) async {
    state = state.copyWith(initialBalance: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kBalance, value);
  }
}

final budgetProvider = NotifierProvider<BudgetNotifier, BudgetSettings>(BudgetNotifier.new);