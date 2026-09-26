import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_providers.dart';
import 'budget_provider.dart';

class SavingGoalData {
  final double risparmiato;
  final double obiettivoRisparmioMese;
  final double percentuale;
  final bool isConfigured;
  final bool hasEntrate;

  const SavingGoalData({
    required this.risparmiato,
    required this.obiettivoRisparmioMese,
    required this.percentuale,
    required this.isConfigured,
    required this.hasEntrate,
  });
}

final savingGoalProvider = Provider<AsyncValue<SavingGoalData>>((ref) {
  final homeDataAsync = ref.watch(homeDataProvider);
  final budgetAsync = ref.watch(budgetProvider);

  return homeDataAsync.when(
    data: (homeData) {
      final budget = budgetAsync;
      final double entrate = homeData.entrate;
      final double uscite = homeData.uscite;
      final double risparmiato = entrate - uscite;
      final double obiettivoRisparmioMese = budget.savingGoal;

      if (entrate <= 0) {
        return AsyncValue.data(SavingGoalData(
          risparmiato: 0,
          obiettivoRisparmioMese: obiettivoRisparmioMese,
          percentuale: 0.0,
          isConfigured: obiettivoRisparmioMese > 0,
          hasEntrate: false,
        ));
      }

      if (obiettivoRisparmioMese <= 0) {
        return AsyncValue.data(SavingGoalData(
          risparmiato: risparmiato < 0 ? 0 : risparmiato,
          obiettivoRisparmioMese: obiettivoRisparmioMese,
          percentuale: 0.0,
          isConfigured: false,
          hasEntrate: true,
        ));
      }

      final double percentuale = (risparmiato / obiettivoRisparmioMese).clamp(0.0, 1.0);

      return AsyncValue.data(SavingGoalData(
        risparmiato: risparmiato < 0 ? 0 : risparmiato,
        obiettivoRisparmioMese: obiettivoRisparmioMese,
        percentuale: percentuale,
        isConfigured: true,
        hasEntrate: true,
      ));
    },
    loading: () => const AsyncValue.loading(),
    error: (e, st) => AsyncValue.error(e, st),
  );
});