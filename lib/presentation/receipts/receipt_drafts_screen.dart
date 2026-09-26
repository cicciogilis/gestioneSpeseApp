import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/providers/app_providers.dart';
import '../../domain/models/scanned_receipt.dart';
import '../../domain/models/transaction.dart';
import '../../core/constants/seed_categories.dart';

final receiptDraftsProvider = FutureProvider<List<ScannedReceipt>>((ref) async {
  final service = ref.read(receiptServiceProvider);
  return service.getDrafts();
});

class ReceiptDraftsScreen extends ConsumerWidget {
  const ReceiptDraftsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draftsAsync = ref.watch(receiptDraftsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scontrini Scansionati'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(receiptDraftsProvider),
          ),
        ],
      ),
      body: draftsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Errore: $err')),
        data: (drafts) {
          if (drafts.isEmpty) {
            return _buildEmptyState(context);
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: drafts.length,
            itemBuilder: (context, index) {
              final receipt = drafts[index];
              return _buildReceiptCard(context, ref, receipt);
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.receipt_long, size: 96, color: Colors.grey),
          const SizedBox(height: 24),
          const Text(
            'Nessuno scontrino salvato',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          const Text(
            'Scansiona uno scontrino per salvarlo qui',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => context.push('/camera'),
            icon: const Icon(Icons.camera_alt),
            label: const Text('SCANSIONA SCONTRINO'),
            style: ElevatedButton.styleFrom(
              fixedSize: const Size(250, 50),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptCard(BuildContext context, WidgetRef ref, ScannedReceipt receipt) {
    final fmt = NumberFormat.simpleCurrency(locale: 'it_IT');
    final confidence = (receipt.confidence * 100).toInt();

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _getStatusColor(receipt.status).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getStatusIcon(receipt.status),
                    color: _getStatusColor(receipt.status),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        receipt.merchantName ?? 'Sconosciuto',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        receipt.purchaseDate != null
                            ? DateFormat('dd MMM yyyy', 'it_IT').format(receipt.purchaseDate!)
                            : 'Data sconosciuta',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (receipt.totalAmount != null)
                  Text(
                    fmt.format(receipt.totalAmount!),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
            if (receipt.rawText.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Anteprima: ${receipt.rawText.substring(0, receipt.rawText.length > 100 ? 100 : receipt.rawText.length)}...',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontFamily: 'monospace',
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                _StatusChip(status: receipt.status),
                const SizedBox(width: 8),
                _ConfidenceChip(confidence: confidence),
                const Spacer(),
                if (receipt.status == ReceiptStatus.draft) ...[
                  TextButton.icon(
                    onPressed: () => _convertToTransaction(context, ref, receipt),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Aggiungi'),
                  ),
                  TextButton.icon(
                    onPressed: () => _editReceipt(context, ref, receipt),
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text('Modifica'),
                  ),
                  TextButton.icon(
                    onPressed: () => _deleteReceipt(context, ref, receipt),
                    icon: const Icon(Icons.delete, size: 18),
                    label: const Text('Elimina'),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(ReceiptStatus status) {
    switch (status) {
      case ReceiptStatus.draft:
        return Colors.blue;
      case ReceiptStatus.pending:
        return Colors.orange;
      case ReceiptStatus.confirmed:
        return Colors.green;
      case ReceiptStatus.rejected:
        return Colors.red;
    }
  }

  IconData _getStatusIcon(ReceiptStatus status) {
    switch (status) {
      case ReceiptStatus.draft:
        return Icons.drafts;
      case ReceiptStatus.pending:
        return Icons.pending;
      case ReceiptStatus.confirmed:
        return Icons.check_circle;
      case ReceiptStatus.rejected:
        return Icons.cancel;
    }
  }

  void _convertToTransaction(BuildContext context, WidgetRef ref, ScannedReceipt receipt) {
    if (!receipt.isComplete) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Scontrino incompleto. Modifica prima di aggiungere.')),
      );
      return;
    }

    context.push('/add', extra: {
      'amount': receipt.totalAmount,
      'date': receipt.purchaseDate?.toIso8601String().split('T').first,
      'category': receipt.categoryId != null
          ? seedCategories.firstWhere((c) => c.id == receipt.categoryId, orElse: () => seedCategories.first).name
          : null,
      'title': receipt.merchantName,
      'method': receipt.method?.name,
      'description': receipt.description,
    }).then((_) {
      // After saving transaction, mark receipt as confirmed
      ref.read(receiptServiceProvider).confirmReceipt(receipt);
      ref.invalidate(receiptDraftsProvider);
    });
  }

  void _editReceipt(BuildContext context, WidgetRef ref, ScannedReceipt receipt) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _ReceiptEditSheet(receipt: receipt),
    ).then((_) => ref.invalidate(receiptDraftsProvider));
  }

  void _deleteReceipt(BuildContext context, WidgetRef ref, ScannedReceipt receipt) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Elimina scontrino?'),
        content: const Text('Questa azione non può essere annullata.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annulla')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(receiptServiceProvider).deleteDraft(receipt.id!);
              ref.invalidate(receiptDraftsProvider);
            },
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
  }
}

class _ReceiptEditSheet extends ConsumerStatefulWidget {
  final ScannedReceipt receipt;

  const _ReceiptEditSheet({required this.receipt});

  @override
  ConsumerState<_ReceiptEditSheet> createState() => _ReceiptEditSheetState();
}

class _ReceiptEditSheetState extends ConsumerState<_ReceiptEditSheet> {
  late final TextEditingController _amountCtrl;
  late final TextEditingController _merchantCtrl;
  late final TextEditingController _descCtrl;
  DateTime? _selectedDate;
  String? _selectedCategoryId;
  MetodoPagamento? _selectedMethod;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _amountCtrl = TextEditingController(text: widget.receipt.totalAmount?.toStringAsFixed(2) ?? '');
    _merchantCtrl = TextEditingController(text: widget.receipt.merchantName ?? '');
    _descCtrl = TextEditingController(text: widget.receipt.description ?? '');
    _selectedDate = widget.receipt.purchaseDate;
    _selectedCategoryId = widget.receipt.categoryId;
    _selectedMethod = widget.receipt.method;
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _merchantCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    final amount = double.tryParse(_amountCtrl.text.replaceAll(',', '.'));
    if (amount == null || amount <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Importo non valido')));
      }
      setState(() => _isSaving = false);
      return;
    }

    final updated = widget.receipt.copyWith(
      totalAmount: amount,
      merchantName: _merchantCtrl.text.isNotEmpty ? _merchantCtrl.text : null,
      description: _descCtrl.text.isNotEmpty ? _descCtrl.text : null,
      purchaseDate: _selectedDate,
      categoryId: _selectedCategoryId,
      method: _selectedMethod,
      updatedAt: DateTime.now(),
    );

    await ref.read(receiptServiceProvider).saveDraft(updated);
    
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Salvato')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Modifica Scontrino',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Importo (€)',
                prefixText: '€ ',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _merchantCtrl,
              decoration: const InputDecoration(
                labelText: 'Commerciante',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today),
              title: Text(_selectedDate != null
                  ? DateFormat('dd MMM yyyy', 'it_IT').format(_selectedDate!)
                  : 'Seleziona data'),
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate ?? DateTime.now(),
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (d != null && mounted) setState(() => _selectedDate = d);
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _selectedCategoryId,
              decoration: const InputDecoration(
                labelText: 'Categoria',
                border: OutlineInputBorder(),
              ),
              items: seedCategories.map((cat) {
                return DropdownMenuItem(
                  value: cat.id,
                  child: Row(
                    children: [
                      Icon(Icons.category, color: Color(cat.color), size: 20),
                      const SizedBox(width: 8),
                      Text(cat.name),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (val) => setState(() => _selectedCategoryId = val),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<MetodoPagamento>(
              initialValue: _selectedMethod,
              decoration: const InputDecoration(
                labelText: 'Metodo di Pagamento',
                border: OutlineInputBorder(),
              ),
              items: MetodoPagamento.values.map((m) {
                return DropdownMenuItem(
                  value: m,
                  child: Row(
                    children: [
                      Icon(m.icon, size: 20),
                      const SizedBox(width: 8),
                      Text(m.label),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (val) => setState(() => _selectedMethod = val),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descCtrl,
              decoration: const InputDecoration(
                labelText: 'Descrizione / Note',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _isSaving ? null : _save,
              style: FilledButton.styleFrom(padding: const EdgeInsets.all(16)),
              child: _isSaving
                  ? const CircularProgressIndicator()
                  : const Text('SALVA MODIFICHE', style: TextStyle(fontSize: 16)),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final ReceiptStatus status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    switch (status) {
      case ReceiptStatus.draft:
        color = Colors.blue;
        label = 'Bozza';
        break;
      case ReceiptStatus.pending:
        color = Colors.orange;
        label = 'In attesa';
        break;
      case ReceiptStatus.confirmed:
        color = Colors.green;
        label = 'Confermato';
        break;
      case ReceiptStatus.rejected:
        color = Colors.red;
        label = 'Rifiutato';
        break;
    }
    return Chip(
      label: Text(label, style: const TextStyle(fontSize: 11, color: Colors.white)),
      backgroundColor: color,
      padding: const EdgeInsets.symmetric(horizontal: 8),
    );
  }
}

class _ConfidenceChip extends StatelessWidget {
  final int confidence;

  const _ConfidenceChip({required this.confidence});

  @override
  Widget build(BuildContext context) {
    Color color;
    if (confidence >= 80) {
      color = Colors.green;
    } else if (confidence >= 60) {
      color = Colors.orange;
    } else {
      color = Colors.red;
    }

    return Chip(
      label: Text('$confidence%', style: const TextStyle(fontSize: 11, color: Colors.white)),
      backgroundColor: color,
      padding: const EdgeInsets.symmetric(horizontal: 8),
    );
  }
}