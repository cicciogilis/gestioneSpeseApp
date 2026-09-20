import '../core/constants/seed_categories.dart';

String categoryDisplayName(String categoryId) {
  final match = seedCategories.firstWhere(
    (c) => c.id == categoryId,
    orElse: () => throw ArgumentError('Unknown category: \$categoryId'),
  );
  return match.name;
}
