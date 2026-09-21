import '../core/constants/seed_categories.dart';

String categoryDisplayName(String raw) {
  final cat = seedCategories.firstWhere(
    (c) => c.id == raw,
    orElse: () => seedCategories.firstWhere(
      (c) => c.id == 'cat_altro',
      orElse: () => seedCategories.first,
    ),
  );
  if (cat.name.isNotEmpty) {
    return cat.name;
  }

  final cleaned = raw.startsWith('cat_')
      ? raw.replaceFirst('cat_', '')
      : raw;
  if (cleaned.isEmpty) {
    return '';
  }
  return cleaned[0].toUpperCase() + cleaned.substring(1).toLowerCase();
}

String transactionTitle(String? description, String category) {
  if (description != null && description.isNotEmpty) {
    return description;
  }
  return categoryDisplayName(category);
}
