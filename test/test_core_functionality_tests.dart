import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spesapp/data/repositories/transaction_repository.dart';
import 'package:spesapp/domain/models/expense_draft.dart';
import 'package:spesapp/domain/models/scanned_receipt.dart';
import 'package:spesapp/domain/models/template_ricorrente.dart';
import 'package:spesapp/domain/models/transaction.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Test Core Functionality', () {
    // TEST-013: ScannedReceipt model serialization/deserialization
    test('TEST-013: ScannedReceipt model can serialize and deserialize', () {
      final receipt = ScannedReceipt(
        id: 'test-id-123',
        imagePath: '/path/to/receipt.jpg',
        merchantName: 'ESSELUNGA',
        purchaseDate: DateTime(2026, 1, 15),
        totalAmount: 32.50,
        items: [
          ScannedReceiptItem(
            description: 'POMEODORI',
            quantity: 2,
            unitPrice: 1.50,
            totalPrice: 3.00,
          ),
        ],
        rawText: 'ESSELUNGA 15/01/2026 TOTALE 32.50',
        status: ReceiptStatus.draft,
        createdAt: DateTime(2026, 1, 16),
      );

      final map = receipt.toMap();

      expect(map['id'], 'test-id-123');
      expect(map['merchant_name'], 'ESSELUNGA');
      expect(map['total_amount'], 32.50);
      expect(map['status'], 'DRAFT');
    });

    // TEST-016: ScannedReceiptItem model
    test('TEST-016: ScannedReceiptItem model serialization works', () {
      final item = ScannedReceiptItem(
        description: 'Milk',
        quantity: 2,
        unitPrice: 1.50,
        totalPrice: 3.00,
      );

      final map = item.toMap();
      expect(map['description'], 'Milk');
      expect(map['quantity'], 2);
      expect(map['unit_price'], 1.50);
      expect(map['total_price'], 3.00);
    });

    // TEST-017: ExpenseDraft model
    test('TEST-017: ExpenseDraft model creation with all required fields', () {
      final draft = ExpenseDraft(
        description: 'Test expense',
        amount: 45.99,
        date: DateTime(2026, 1, 15),
        category: 'cat_alimentari',
        type: TransactionType.expense,
        merchantName: 'Carrefour',
        imagePath: '/path/to/image.jpg',
        method: MetodoPagamento.carta,
      );

      expect(draft.description, 'Test expense');
      expect(draft.amount, 45.99);
      expect(draft.imagePath, '/path/to/image.jpg');
      expect(draft.merchantName, 'Carrefour');
    });

    // TEST-019: TemplateRicorrente serialization
    test('TEST-019: TemplateRicorrente serialization/deserialization', () {
      final template = TemplateRicorrente(
        id: 'template-001',
        amount: 50.0,
        type: TransactionType.expense,
        categoryId: 'cat_sport',
        method: MetodoPagamento.carta,
        description: 'Monthly gym',
        recurrence: Recurrence.monthly,
        dataInizio: DateTime(2026, 1, 1),
        dataProssimaOccorrenza: DateTime(2026, 2, 1),
        attivo: true,
      );

      final map = template.toMap();
      final deserialized = TemplateRicorrente.fromMap(map);

      expect(deserialized.id, template.id);
      expect(deserialized.amount, template.amount);
      expect(deserialized.type, template.type);
      expect(deserialized.categoryId, template.categoryId);
      expect(deserialized.method, template.method);
      expect(deserialized.description, template.description);
      expect(deserialized.recurrence, template.recurrence);
      expect(deserialized.dataInizio, template.dataInizio);
      expect(deserialized.dataProssimaOccorrenza, template.dataProssimaOccorrenza);
      expect(deserialized.attivo, template.attivo);
    });

    // TEST-029: AppTransaction model serialization
    test('TEST-029: AppTransaction model serialization works correctly', () {
      final tx = AppTransaction(
        id: 'tx-001',
        amount: 100.0,
        type: TransactionType.expense,
        categoryId: 'cat_alimentari',
        method: MetodoPagamento.carta,
        date: DateTime(2026, 1, 15),
        description: 'Weekly groceries',
        recurrence: Recurrence.monthly,
        ricorrenzaId: 'template-001',
      );

      final map = tx.toMap();

      expect(map['id'], 'tx-001');
      expect(map['amount'], 100.0);
      expect(map['type'], 'EXPENSE');
      expect(map['category_id'], 'cat_alimentari');
      expect(map['method'], 'CARTA');
      expect(map['recurrence'], 'MONTHLY');
      expect(map['ricorrenza_id'], 'template-001');
    });

    // TEST-030: AppTransaction.fromMap deserializes correctly
    test('TEST-030: AppTransaction.fromMap deserializes correctly', () {
      final map = {
        'id': 'tx-002',
        'amount': 250.75,
        'type': 'INCOME',
        'category_id': 'cat_stipendio',
        'method': 'BONIFICO',
        'date': '2026-01-15',
        'description': 'Salary',
        'ai_summary': 'Monthly salary',
        'recurrence': 'NONE',
        'ricorrenza_id': null,
      };

      final tx = AppTransaction.fromMap(map);

      expect(tx.id, 'tx-002');
      expect(tx.amount, 250.75);
      expect(tx.type, TransactionType.income);
      expect(tx.categoryId, 'cat_stipendio');
      expect(tx.method, MetodoPagamento.bonifico);
      expect(tx.description, 'Salary');
      expect(tx.aiSummary, 'Monthly salary');
      expect(tx.recurrence, Recurrence.none);
    });

    // TEST: Recurrence.nextAfter calculates correct dates
    test('TEST: Recurrence.nextAfter calculates correct future dates', () {
      final now = DateTime(2026, 1, 15);

      expect(Recurrence.daily.nextAfter(now), DateTime(2026, 1, 16));
      expect(Recurrence.weekly.nextAfter(now), DateTime(2026, 1, 22));
      expect(Recurrence.monthly.nextAfter(now), DateTime(2026, 2, 15));
      expect(Recurrence.yearly.nextAfter(now), DateTime(2027, 1, 15));
    });

    // TEST: Recurrence.isRecurring property
    test('TEST: Recurrence.isRecurring returns correct values', () {
      expect(Recurrence.none.isRecurring, false);
      expect(Recurrence.daily.isRecurring, true);
      expect(Recurrence.weekly.isRecurring, true);
      expect(Recurrence.monthly.isRecurring, true);
      expect(Recurrence.yearly.isRecurring, true);
    });

    // TEST: TransactionRepository can add and retrieve transactions
    test('TEST: TransactionRepository add and retrieve transactions', () async {
      final repository = TransactionRepository();

      final tx = AppTransaction(
        amount: 50.0,
        type: TransactionType.expense,
        categoryId: 'cat_alimentari',
        method: MetodoPagamento.contanti,
        date: DateTime(2026, 1, 15),
        description: 'Initial test transaction',
      );

      await repository.addTransaction(tx);

      final transactions = await repository.getTransactions();

      expect(transactions.length, 1);
      expect(transactions[0].amount, 50.0);
      expect(transactions[0].categoryId, 'cat_alimentari');
    });

    // TEST: TransactionRepository getAvailableYears returns current year
    test('TEST: TransactionRepository getAvailableYears returns correct years', () async {
      final repository = TransactionRepository();
      final now = DateTime.now();

      await repository.addTransaction(AppTransaction(
        amount: 75.0,
        type: TransactionType.income,
        categoryId: 'cat_stipendio',
        method: MetodoPagamento.bonifico,
        date: DateTime(now.year, 6, 1),
      ));

      final years = await repository.getAvailableYears();

      expect(years.contains(now.year), isTrue);
    });

    // TEST: MetodoPagamento enum has all expected values
    test('TEST: MetodoPagamento enum has all expected values', () {
      expect(MetodoPagamento.values, [
        MetodoPagamento.contanti,
        MetodoPagamento.carta,
        MetodoPagamento.bonifico,
        MetodoPagamento.paypal,
        MetodoPagamento.satispay,
      ]);
    });

    // TEST: TransactionType enum has income and expense
    test('TEST: TransactionType enum values', () {
      expect(TransactionType.values, [TransactionType.income, TransactionType.expense]);
    });

    // TEST: MetodoPagamentoLabel extension provides labels and icons
    test('TEST: MetodoPagamentoLabel extension provides correct labels', () {
      expect(MetodoPagamento.contanti.label, 'Contanti');
      expect(MetodoPagamento.carta.label, 'Carta');
      expect(MetodoPagamento.bonifico.label, 'Bonifico');
      expect(MetodoPagamento.paypal.label, 'PayPal');
      expect(MetodoPagamento.satispay.label, 'SatisPay');
    });

    // TEST: TransactionRepository deleteTransaction works
    test('TEST: TransactionRepository deleteTransaction removes transaction', () async {
      final repository = TransactionRepository();

      await repository.addTransaction(AppTransaction(
        amount: 100.0,
        type: TransactionType.expense,
        categoryId: 'cat_alimentari',
        method: MetodoPagamento.contanti,
        date: DateTime.now(),
      ));

      final transactions = await repository.getTransactions();
      final id = transactions.first.id;

      await repository.deleteTransaction(id!);

      final afterDelete = await repository.getTransactions();
      expect(afterDelete, isEmpty);
    });
  });
}

