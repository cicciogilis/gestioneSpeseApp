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

  static const IconData _defaultIcon = Icons.category;

  @override
  Widget build(BuildContext context) {
    final isExpense = transaction.type == TransactionType.expense;
    final title = transactionTitle(transaction.description, transaction.categoryId);
    final catName = categoryDisplayName(transaction.categoryId);
    final cat = _lookupCategory(transaction.categoryId);
    final color = Color(cat.color);
    final iconData = _iconData(cat.icon);

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
        subtitle: Text(
          '$catName · ${transaction.method.label}',
          style: TextStyle(fontSize: compact ? 11 : 12, color: Colors.grey),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
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
            if (transaction.recurrence.isRecurring)
              const Badge(
                label: Text('↺', style: TextStyle(fontSize: 10)),
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 0),
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

  IconData _iconData(String iconName) {
    IconData? iconData;
    switch (iconName) {
      case 'shopping_cart': iconData = Icons.shopping_cart; break;
      case 'directions_car': iconData = Icons.directions_car; break;
      case 'sports_esports': iconData = Icons.sports_esports; break;
      case 'bolt': iconData = Icons.bolt; break;
      case 'healing': iconData = Icons.healing; break;
      case 'checkroom': iconData = Icons.checkroom; break;
      case 'devices': iconData = Icons.devices; break;
      case 'home': iconData = Icons.home; break;
      case 'restaurant': iconData = Icons.restaurant; break;
      case 'subscriptions': iconData = Icons.subscriptions; break;
      case 'school': iconData = Icons.school; break;
      case 'fitness_center': iconData = Icons.fitness_center; break;
      case 'spa': iconData = Icons.spa; break;
      case 'card_giftcard': iconData = Icons.card_giftcard; break;
      case 'account_balance': iconData = Icons.account_balance; break;
      case 'home_repair_service': iconData = Icons.home_repair_service; break;
      case 'more_horiz': iconData = Icons.more_horiz; break;
      case 'category': iconData = Icons.category; break;
    }
    return iconData ?? _defaultIcon;
  }
}
