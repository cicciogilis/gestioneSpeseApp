import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/seed_categories.dart';
import '../../domain/models/transaction.dart';
import '../../core/providers/app_providers.dart';

class AddTransactionScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? extra;

  const AddTransactionScreen({super.key, this.extra});

  @override
  ConsumerState<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  TransactionType _selectedType = TransactionType.expense;
  MetodoPagamento _selectedMethod = MetodoPagamento.contanti;
  Recurrence _selectedRecurrence = Recurrence.none;
  DateTime _selectedDate = DateTime.now();
  String? _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    // Prefill from AI if available
    if (widget.extra != null) {
      final data = widget.extra!;
      // Assuming keys: amount, date, category, title (description)
      if (data['amount'] != null) {
        _amountCtrl.text = data['amount'].toString();
      }
      if (data['date'] != null) {
        // Expecting string YYYY-MM-DD
        try {
          _selectedDate = DateTime.parse(data['date'].toString());
        } catch (_) {
          // ignore
        }
      }
      if (data['category'] != null) {
        final String catName = data['category'].toString();
        final cat = seedCategories.firstWhere(
          (c) => c.name == catName,
          orElse: () => seedCategories.firstWhere((c) => c.name == 'Altro', orElse: () => seedCategories.first),
        );
        _selectedCategoryId = cat.id;
        // Also set type based on category? For now, we keep the type as selected by the segment button.
        // But we could adjust the segment button based on category.type. We'll leave it as is for simplicity.
      }
      if (data['title'] != null) {
        _descCtrl.text = data['title'].toString();
      }
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  void _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Seleziona una categoria')));
      return;
    }

    final amount = double.tryParse(_amountCtrl.text.replaceAll(',', '.')) ?? 0.0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Importo non valido')));
      return;
    }

    final tx = AppTransaction(
      amount: amount,
      type: _selectedType,
      categoryId: _selectedCategoryId!,
      method: _selectedMethod,
      date: _selectedDate,
      description: _descCtrl.text.isNotEmpty ? _descCtrl.text : null,
      recurrence: _selectedRecurrence,
    );

    // Save
    await ref.read(transactionsProvider.notifier).addTransaction(tx);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Salvata!')));
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final availableCategories =
      seedCategories.where((c) => c.type.name == _selectedType.name && c.id != 'cat_saldo_iniziale').toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nuova Transazione'),
        actions: [
          IconButton(icon: const Icon(Icons.save), onPressed: _save),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<TransactionType>(
                segments: const [
                  ButtonSegment(value: TransactionType.expense, label: Text('Uscita')),
                  ButtonSegment(value: TransactionType.income, label: Text('Entrata')),
                ],
                selected: {_selectedType},
                onSelectionChanged: (set) {
                  setState(() {
                    _selectedType = set.first;
                    _selectedCategoryId = null; // reset category on type switch
                  });
                },
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Importo',
                  prefixText: '€ ',
                  border: OutlineInputBorder(),
                ),
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                validator: (val) => val == null || val.isEmpty ? 'Inserisci un importo' : null,
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today),
                title: Text('${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}'),
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (d != null) setState(() => _selectedDate = d);
                },
              ),
              const SizedBox(height: 16),
              const Text('Metodo di Pagamento', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SegmentedButton<MetodoPagamento>(
                  segments: const [
                    ButtonSegment(value: MetodoPagamento.contanti, label: Text('Contanti')),
                    ButtonSegment(value: MetodoPagamento.carta, label: Text('Carta')),
                    ButtonSegment(value: MetodoPagamento.bonifico, label: Text('Bonifico')),
                    ButtonSegment(value: MetodoPagamento.paypal, label: Text('PayPal')),
                    ButtonSegment(value: MetodoPagamento.satispay, label: Text('SatisPay')),
                  ],
                  selected: {_selectedMethod},
                  onSelectionChanged: (set) => setState(() => _selectedMethod = set.first),
                ),
              ),
              const SizedBox(height: 24),
              const Text('Ricorrenza', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: recMap.entries.map((entry) {
                  final isSelected = _selectedRecurrence == entry.key;
                  return ChoiceChip(
                    label: Text(entry.value),
                    selected: isSelected,
                    onSelected: (val) =>
                        setState(() => _selectedRecurrence = val ? entry.key : Recurrence.none),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              const Text('Categoria', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: availableCategories.map((cat) {
                  final isSelected = cat.id == _selectedCategoryId;
                  return ChoiceChip(
                    label: Text(cat.name),
                    selected: isSelected,
                    onSelected: (val) => setState(() => _selectedCategoryId = val ? cat.id : null),
                    selectedColor: Color(cat.color).withValues(alpha: 0.3),
                    avatar: Icon(Icons.category, color: Color(cat.color), size: 18),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _descCtrl,
                decoration: const InputDecoration(
                  labelText: 'Descrizione / Note',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
                child: const Text('SALVA', style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

const Map<Recurrence, String> recMap = {
  Recurrence.none: 'Nessuna',
  Recurrence.daily: 'Giornaliera',
  Recurrence.weekly: 'Settimanale',
  Recurrence.monthly: 'Mensile',
  Recurrence.yearly: 'Annuale',
};
