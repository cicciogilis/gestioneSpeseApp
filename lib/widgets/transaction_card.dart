import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/constants/seed_categories.dart';
import '../domain/models/category.dart';
import '../domain/models/transaction.dart';
import '../utils/category_utils.dart';

class TransactionCard extends StatelessWidget {
  final AppTransaction transaction;
  final VoidCallback? onTap;
  final bool compact;

  const TransactionCard({
    super.key,
    required this.transaction,
    this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final isExpense = transaction.type == TransactionType.expense;
    final title = transactionTitle(transaction.description, transaction.categoryId);
    final catName = categoryDisplayName(transaction.categoryId);
    final cat = _lookupCategory(transaction.categoryId);
    final color = Color(cat.color);
    final iconData = cat.iconData;

    final fmt = NumberFormat.simpleCurrency(locale: 'it_IT');

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.2),
          child: Icon(iconData, color: color, size: compact ? 18 : 24),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: compact ? 13 : 16,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$catName · ${transaction.method.label}',
              style: TextStyle(
                fontSize: compact ? 11 : 12,
                color: Colors.grey,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (transaction.recurrence.isRecurring) ...[
              const SizedBox(width: 6),
              const Icon(
                Icons.repeat,
                size: 14,
                color: Colors.white,
              ),
            ],
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${isExpense ? '-' : '+'}${fmt.format(transaction.amount)}',
              style: TextStyle(
                color: isExpense ? Colors.red : Colors.green,
                fontWeight: FontWeight.bold,
                fontSize: compact ? 13 : 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  AppCategory _lookupCategory(String id) {
    return seedCategories.firstWhere(
      (c) => c.id == id,
      orElse: () => seedCategories.firstWhere(
        (c) => c.id == 'cat_altro',
        orElse: () => seedCategories.first,
      ),
    );
  }
}
