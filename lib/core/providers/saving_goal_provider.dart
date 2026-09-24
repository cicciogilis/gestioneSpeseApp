import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_providers.dart';

class SavingGoalData {
  final double totaleEntrate;
  final double totaleUscite;
  final double risparmioCorrente;
  final double ratio;
  final bool hasEntrate;

  const SavingGoalData({
    required this.totaleEntrate,
    required this.totaleUscite,
    required this.risparmioCorrente,
    required this.ratio,
    required this.hasEntrate,
  });
}

final savingGoalProvider = Provider<AsyncValue<SavingGoalData>>((ref) {
  final homeDataAsync = ref.watch(homeDataProvider);

  return homeDataAsync.when(
    data: (homeData) {
      final double entrate = homeData.entrate;
      final double uscite = homeData.uscite;

      if (entrate <= 0) {
        return AsyncValue.data(SavingGoalData(
          totaleEntrate: 0,
          totaleUscite: uscite,
          risparmioCorrente: 0,
          ratio: 0.0,
          hasEntrate: false,
        ));
      }

      final double risparmio = entrate - uscite;
      final double ratio = (risparmio / entrate).clamp(0.0, 1.0);

      return AsyncValue.data(SavingGoalData(
        totaleEntrate: entrate,
        totaleUscite: uscite,
        risparmioCorrente: risparmio < 0 ? 0 : risparmio,
        ratio: ratio,
        hasEntrate: true,
      ));
    },
    loading: () => const AsyncValue.loading(),
    error: (e, st) => AsyncValue.error(e, st),
  );
});