import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spesapp/data/repositories/transaction_repository.dart';
import 'package:spesapp/domain/models/transaction.dart';

void main() {
  group('RecurrenceX.nextAfter', () {
    final base = DateTime(2026, 1, 31);

    test('daily adds one day', () {
      expect(Recurrence.daily.nextAfter(base), DateTime(2026, 2, 1));
    });

    test('weekly adds seven days', () {
      expect(Recurrence.weekly.nextAfter(base), DateTime(2026, 2, 7));
    });

    test('monthly clamps to last day of month', () {
      expect(Recurrence.monthly.nextAfter(base), DateTime(2026, 2, 28));
      expect(Recurrence.monthly.nextAfter(DateTime(2026, 3, 31)), DateTime(2026, 4, 30));
    });

    test('yearly handles leap day', () {
      expect(Recurrence.yearly.nextAfter(DateTime(2024, 2, 29)), DateTime(2025, 2, 28));
      expect(Recurrence.yearly.nextAfter(DateTime(2025, 2, 28)), DateTime(2026, 2, 28));
    });

    test('none returns same date', () {
      expect(Recurrence.none.nextAfter(base), base);
    });

    test('isRecurring flag', () {
      expect(Recurrence.none.isRecurring, isFalse);
      expect(Recurrence.monthly.isRecurring, isTrue);
    });
  });

  group('AppTransaction recurrence serialization', () {
    test('toMap/fromMap roundtrip', () {
      final tx = AppTransaction(
        id: 'tx1',
        amount: 25.0,
        type: TransactionType.expense,
        categoryId: 'cat_alimentari',
        method: MetodoPagamento.carta,
        date: DateTime(2026, 1, 15),
        recurrence: Recurrence.monthly,
      );
      final restored = AppTransaction.fromMap(tx.toMap());
      expect(restored.recurrence, Recurrence.monthly);
    });
  });

  group('TransactionRepository local persistence', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('persists and restores transactions locally', () async {
      final repository = TransactionRepository();
      final tx = AppTransaction(
        amount: 25.0,
        type: TransactionType.expense,
        categoryId: 'cat_alimentari',
        method: MetodoPagamento.carta,
        date: DateTime(2026, 1, 15),
        description: 'Spesa',
      );

      await repository.addTransaction(tx);

      final restored = await TransactionRepository().getTransactions();
      expect(restored, hasLength(1));
      expect(restored.single.amount, 25.0);
      expect(restored.single.description, 'Spesa');
      expect(restored.single.id, isNotEmpty);
    });

    test('migrates legacy offline and cache entries', () async {
      final tx = AppTransaction(
        id: 'legacy-1',
        amount: 10.0,
        type: TransactionType.income,
        categoryId: 'cat_stipendio',
        method: MetodoPagamento.bonifico,
        date: DateTime(2026, 1, 1),
      );
      SharedPreferences.setMockInitialValues({
        'offline_transactions': [jsonEncode(tx.toMap())],
        'cached_transactions': [jsonEncode(tx.toMap())],
      });

      final restored = await TransactionRepository().getTransactions();

      expect(restored, hasLength(1));
      expect(restored.single.id, 'legacy-1');
    });
  });
}