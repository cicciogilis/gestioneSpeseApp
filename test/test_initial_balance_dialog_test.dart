import 'package:flutter/material.dart';
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
    // TEST-011: getSaldoIniziale returns default 0.0 when not saved
    test('TEST-011: getSaldoIniziale returns 0.0 when no value saved', () async {
      final now = DateTime.now();
      final result = await InitialBalanceDialog.getSaldoIniziale(now.year, now.month);
      
      expect(result, 0.0);
    });

    // TEST-012: getSaldoIniziale returns saved value
    test('TEST-012: getSaldoIniziale returns saved value', () async {
      final now = DateTime.now();
      final prefs = await SharedPreferences.getInstance();
      final key = 'saldo_iniziale_${now.year}_${now.month}';
      await prefs.setDouble(key, 500.0);
      
      final result = await InitialBalanceDialog.getSaldoIniziale(now.year, now.month);
      
      expect(result, 500.0);
    });

    // TEST-013: InitialBalanceDialog shows dialog when balance not set
    testWidgets('TEST-013: showIfNeeded displays dialog when balance not set', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                InitialBalanceDialog.showIfNeeded(context);
              });
              return Scaffold(
                body: Center(child: Text('Test Screen')),
              );
            },
          ),
        ),
      );
      
      await tester.pumpAndSettle();
      
      expect(find.text('Saldo iniziale'), findsOneWidget);
    });

    // TEST-014: InitialBalanceDialog does NOT show dialog when balance already set
    testWidgets('TEST-014: showIfNeeded skips dialog when balance already set', (WidgetTester tester) async {
      final now = DateTime.now();
      final prefs = await SharedPreferences.getInstance();
      final key = 'saldo_iniziale_${now.year}_${now.month}';
      await prefs.setDouble(key, 100.0);
      
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                InitialBalanceDialog.showIfNeeded(context);
              });
              return Scaffold(
                body: Center(child: Text('Test Screen')),
              );
            },
          ),
        ),
      );
      
      await tester.pumpAndSettle();
      
      expect(find.text('Saldo iniziale'), findsNothing);
    });

    // TEST-015: InitialBalanceDialog saves value when confirmed
    testWidgets('TEST-015: dialog saves entered balance value on confirm', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                InitialBalanceDialog.showIfNeeded(context);
              });
              return Scaffold(
                body: Center(child: Text('Test Screen')),
              );
            },
          ),
        ),
      );
      
      await tester.pumpAndSettle();
      
      await tester.enterText(find.byType(TextField), '1000.50');
      await tester.tap(find.text('Conferma'));
      await tester.pumpAndSettle();
      
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final key = 'saldo_iniziale_${now.year}_${now.month}';
      
      expect(prefs.getDouble(key), 1000.5);
    });

    // TEST: InitialBalanceDialog saves 0.0 when 'Salta' is pressed
    testWidgets('TEST: dialog saves 0.0 when skip button pressed', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                InitialBalanceDialog.showIfNeeded(context);
              });
              return Scaffold(
                body: Center(child: Text('Test Screen')),
              );
            },
          ),
        ),
      );
      
      await tester.pumpAndSettle();
      
      await tester.tap(find.text('Salta'));
      await tester.pumpAndSettle();
      
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final key = 'saldo_iniziale_${now.year}_${now.month}';
      
      expect(prefs.getDouble(key), 0.0);
    });

    // TEST: getSaldoIniziale uses year and month for key differentiation
    test('TEST: getSaldoIniziale returns different values for different months', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('saldo_iniziale_2026_1', 100.0);
      await prefs.setDouble('saldo_iniziale_2026_6', 200.0);
      
      final january = await InitialBalanceDialog.getSaldoIniziale(2026, 1);
      final june = await InitialBalanceDialog.getSaldoIniziale(2026, 6);
      
      expect(january, 100.0);
      expect(june, 200.0);
    });
  });
}



