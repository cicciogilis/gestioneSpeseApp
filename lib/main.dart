import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'data/repositories/transaction_repository.dart';
import 'data/services/temp_file_service.dart';
import 'widgets/initial_balance_dialog.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Ensure date formatting is initialized for the Italian locale
  Intl.defaultLocale = 'it_IT';
  await initializeDateFormatting('it_IT');

  // Cleanup temp files on startup
  await TempFileService().cleanupTempFiles();

  // Process pending recurrences
  await TransactionRepository().processaRicorrenzePendenti();

  runApp(
    const ProviderScope(
      child: SpesApp(),
    ),
  );
}

class SpesApp extends StatelessWidget {
  const SpesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'SpesApp',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        // Show initial balance dialog after first frame
        WidgetsBinding.instance.addPostFrameCallback((_) {
          InitialBalanceDialog.showIfNeeded(context);
        });
        return child!;
      },
    );
  }
}
