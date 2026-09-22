import 'package:flutter/material.dart';

enum CategoryType { income, expense, both }

class AppCategory {
  final String id;
  final String name;
  final String icon;
  final int color;
  final CategoryType type;

  const AppCategory({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.type,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'icon': icon,
      'color': color,
      'type': type.name.toUpperCase(),
    };
  }

  factory AppCategory.fromMap(Map<String, dynamic> map) {
    return AppCategory(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      icon: map['icon'] ?? 'category',
      color: map['color'] ?? 0xFF9E9E9E,
      type: CategoryType.values.firstWhere(
        (e) => e.name.toUpperCase() == map['type'],
        orElse: () => CategoryType.expense,
      ),
    );
  }

  IconData get defaultIconData {
    // Semplice mapper mockup
    return Icons.category;
  }

  IconData get iconData {
    IconData? iconData;
    switch (icon) {
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
    return iconData ?? defaultIconData;
  }
}
