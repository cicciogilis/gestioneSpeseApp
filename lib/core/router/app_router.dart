import 'package:go_router/go_router.dart';

import '../../presentation/camera/camera_screen.dart';
import '../../presentation/home/home_screen.dart';
import '../../presentation/onboarding/onboarding_screen.dart';
import '../../presentation/onboarding/splash_screen.dart';
import '../../presentation/receipts/receipt_drafts_screen.dart';
import '../../presentation/settings/initial_balance_config_screen.dart';
import '../../presentation/settings/settings_screen.dart';
import '../../presentation/transaction/add_transaction_screen.dart';
import '../../presentation/transaction/transaction_list_screen.dart';
import '../../presentation/analytics/analytics_screen.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(
      path: '/splash',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => const OnboardingScreen(),
    ),
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeScreen(),
      routes: [
        GoRoute(
          path: 'add',
          builder: (context, state) => AddTransactionScreen(
            extra: state.extra as Map<String, dynamic>?,
          ),
        ),
        GoRoute(
          path: 'camera',
          builder: (context, state) => const CameraScreen(),
        ),
        GoRoute(
          path: 'transactions',
          builder: (context, state) => const TransactionListScreen(),
        ),
        GoRoute(
          path: 'analytics',
          builder: (context, state) => const AnalyticsScreen(),
        ),
        GoRoute(
          path: 'settings',
          builder: (context, state) => const SettingsScreen(),
        ),
        GoRoute(
          path: 'receipts',
          builder: (context, state) => const ReceiptDraftsScreen(),
        ),
        GoRoute(
          path: 'initial-balance-config',
          builder: (context, state) => const InitialBalanceConfigScreen(),
        ),
      ],
    ),
  ],
);
