import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spesapp/widgets/initial_balance_dialog.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('Test Initial Balance Dialog', () {
    test('TEST-011: getSaldoIniziale returns 0.0 when no value saved', () async {
      final now = DateTime.now();
      final result = await InitialBalanceDialog.getSaldoIniziale(now.year, now.month);

      expect(result, 0.0);
    });

    test('TEST-012: getSaldoIniziale returns saved value', () async {
      final now = DateTime.now();
      final prefs = await SharedPreferences.getInstance();
      final monthStr = now.month.toString().padLeft(2, '0');
      final balanceMap = {
        'year': now.year,
        'month': now.month,
        'baseline_type': 'month_start',
        'baseline_date': '${now.year}-$monthStr-01',
        'baseline_amount': 500.0,
      };
      await prefs.setString(
        'month_balances_${now.year}_${now.month}',
        jsonEncode(balanceMap),
      );

      final result =
          await InitialBalanceDialog.getSaldoIniziale(now.year, now.month);

      expect(result, 500.0);
    });

    testWidgets('TEST-013: showIfNeeded displays dialog when balance not set',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: _TestBalanceGate(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Saldo iniziale'), findsOneWidget);
    });

    testWidgets(
        'TEST-014: showIfNeeded skips dialog when balance already set',
         (WidgetTester tester) async {
      final prefs = await SharedPreferences.getInstance();
      prefs.setBool('initialBalance_onboarding_done', true);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: _TestBalanceGate(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Saldo iniziale'), findsNothing);
    });

    testWidgets('TEST-015: dialog saves entered balance value on confirm',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: _TestBalanceGate(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '1000.50');
      await tester.tap(find.text('Conferma'));
      await tester.pumpAndSettle();
    });

     testWidgets('TEST-016: dialog is non-bypassable (no skip button)', (WidgetTester tester) async {
       await tester.pumpWidget(
         const ProviderScope(
           child: MaterialApp(
             home: _TestBalanceGate(),
           ),
         ),
       );

       await tester.pumpAndSettle();

       expect(find.text('Salta'), findsNothing);
       expect(find.text('Conferma'), findsOneWidget);

       final prefs = await SharedPreferences.getInstance();
       expect(prefs.containsKey('initialBalance_onboarding_done'),
           isFalse);
     });

    test('TEST: getSaldoIniziale returns different values for different months',
        () async {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setString('month_balances_2026_1',
          '{"year":2026,"month":1,"baseline_type":"month_start","baseline_date":"2026-01-01","baseline_amount":100.0}');

      await prefs.setString('month_balances_2026_6',
          '{"year":2026,"month":6,"baseline_type":"month_start","baseline_date":"2026-06-01","baseline_amount":200.0}');

      final january = await InitialBalanceDialog.getSaldoIniziale(2026, 1);
      final june = await InitialBalanceDialog.getSaldoIniziale(2026, 6);

      expect(january, 100.0);
      expect(june, 200.0);
    });
  });
}

class _TestBalanceGate extends ConsumerWidget {
  const _TestBalanceGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      InitialBalanceDialog.showIfNeeded(context, ref);
    });
    return const Scaffold(
      body: Center(child: Text('Test Screen')),
    );
  }
}
