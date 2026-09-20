// import 'package:flutter/material.dart';
import 'transaction.dart';

class TemplateRicorrente {
  final String? id;
  final double amount;
  final TransactionType type;
  final String categoryId;
  final MetodoPagamento method;
  final String? description;
  final Recurrence recurrence;
  final DateTime dataInizio;
  final DateTime dataProssimaOccorrenza;
  final bool attivo;

  const TemplateRicorrente({
    this.id,
    required this.amount,
    required this.type,
    required this.categoryId,
    required this.method,
    this.description,
    required this.recurrence,
    required this.dataInizio,
    required this.dataProssimaOccorrenza,
    this.attivo = true,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'amount': amount,
      'type': type.name.toUpperCase(),
      'category_id': categoryId,
      'method': method.name.toUpperCase(),
      'description': description,
      'recurrence': recurrence.name.toUpperCase(),
      'data_inizio': dataInizio.toIso8601String().split('T')[0],
      'data_prossima_occorrenza': dataProssimaOccorrenza.toIso8601String().split('T')[0],
      'attivo': attivo ? 1 : 0,
    };
  }

  factory TemplateRicorrente.fromMap(Map<String, dynamic> map) {
    return TemplateRicorrente(
      id: map['id'],
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      type: TransactionType.values.firstWhere(
        (e) => e.name.toUpperCase() == map['type'],
        orElse: () => TransactionType.expense,
      ),
      categoryId: map['category_id'] ?? '',
      method: _parseMethod(map['method']),
      description: map['description'],
      recurrence: Recurrence.values.firstWhere(
        (e) => e.name.toUpperCase() == map['recurrence'],
        orElse: () => Recurrence.none,
      ),
      dataInizio: DateTime.tryParse(map['data_inizio'] ?? '') ?? DateTime.now(),
      dataProssimaOccorrenza: DateTime.tryParse(map['data_prossima_occorrenza'] ?? '') ?? DateTime.now(),
      attivo: (map['attivo'] as int? ?? 1) == 1,
    );
  }

  static MetodoPagamento _parseMethod(dynamic value) {
    if (value == null) return MetodoPagamento.contanti;
    final upper = (value as String).toUpperCase();
    switch (upper) {
      case 'CONTANTI':
      case 'CASH':
        return MetodoPagamento.contanti;
      case 'CARTA':
      case 'CARD':
        return MetodoPagamento.carta;
      case 'BONIFICO':
      case 'TRANSFER':
        return MetodoPagamento.bonifico;
      case 'PAYPAL':
        return MetodoPagamento.paypal;
      case 'SATISPAY':
        return MetodoPagamento.satispay;
      default:
        return MetodoPagamento.contanti;
    }
  }
}