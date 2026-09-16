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
}
