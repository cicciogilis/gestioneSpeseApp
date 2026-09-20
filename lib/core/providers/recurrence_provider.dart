import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/transaction_repository.dart';
import '../../domain/models/template_ricorrente.dart';

final templateProvider = FutureProvider<List<TemplateRicorrente>>((ref) async {
  final repository = TransactionRepository();
  return repository.getTemplates();
});

/// Provider per processare le ricorrenze all'avvio
final recurrenceProcessorProvider = FutureProvider<void>((ref) async {
  final repository = TransactionRepository();
  await repository.processaRicorrenzePendenti();
});