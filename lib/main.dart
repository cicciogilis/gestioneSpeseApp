import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'data/repositories/month_balance_repository.dart';
import 'data/repositories/transaction_repository.dart';
import 'data/services/temp_file_service.dart';
import 'widgets/initial_balance_dialog.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  Intl.defaultLocale = 'it_IT';
  await initializeDateFormatting('it_IT');

  await TempFileService().cleanupTempFiles();

  await TransactionRepository().processaRicorrenzePendenti();

  await MonthBalanceRepositoryImpl().migrateLegacyBalances();

  runApp(
    const ProviderScope(
      child: SpesApp(),
    ),
  );
}

class SpesApp extends ConsumerWidget {
  const SpesApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'SpesApp',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          InitialBalanceDialog.showIfNeeded(context, ref);
          InitialBalanceDialog.showMonthAutoBalanceMessage(context, ref);
        });
        return child!;
      },
    );
  }
}
