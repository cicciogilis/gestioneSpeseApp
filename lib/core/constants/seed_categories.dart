import '../../domain/models/category.dart';

const List<AppCategory> seedCategories = [
  AppCategory(id: 'cat_alimentari', name: 'Alimentari', icon: 'shopping_cart', color: 0xFF4CAF50, type: CategoryType.expense),
  AppCategory(id: 'cat_trasporti', name: 'Trasporti', icon: 'directions_car', color: 0xFF2196F3, type: CategoryType.expense),
  AppCategory(id: 'cat_svago', name: 'Svago', icon: 'sports_esports', color: 0xFF795548, type: CategoryType.expense),
  AppCategory(id: 'cat_utenze', name: 'Utenze', icon: 'bolt', color: 0xFF607D8B, type: CategoryType.expense),
  AppCategory(id: 'cat_salute', name: 'Salute', icon: 'healing', color: 0xFF009688, type: CategoryType.expense),
  AppCategory(id: 'cat_abbigliamento', name: 'Abbigliamento', icon: 'checkroom', color: 0xFFE91E63, type: CategoryType.expense),
  AppCategory(id: 'cat_tecnologia', name: 'Tecnologia', icon: 'devices', color: 0xFF3F51B5, type: CategoryType.expense),
  AppCategory(id: 'cat_casa', name: 'Casa', icon: 'home', color: 0xFFFF9800, type: CategoryType.expense),
  AppCategory(id: 'cat_ristorante', name: 'Ristorante', icon: 'restaurant', color: 0xFFFF5722, type: CategoryType.expense),
  AppCategory(id: 'cat_abbonamenti', name: 'Abbonamenti', icon: 'subscriptions', color: 0xFFF44336, type: CategoryType.expense),
  AppCategory(id: 'cat_istruzione', name: 'Istruzione', icon: 'school', color: 0xFF5C6BC0, type: CategoryType.expense),
  AppCategory(id: 'cat_sport', name: 'Sport', icon: 'fitness_center', color: 0xFF00BCD4, type: CategoryType.expense),
  AppCategory(id: 'cat_altro', name: 'Altro', icon: 'more_horiz', color: 0xFFBDBDBD, type: CategoryType.expense),
  AppCategory(id: 'cat_cura', name: 'Cura della persona', icon: 'spa', color: 0xFF9C27B0, type: CategoryType.expense),
  AppCategory(id: 'cat_regali', name: 'Regali', icon: 'card_giftcard', color: 0xFFFFC107, type: CategoryType.expense),
  AppCategory(id: 'cat_affitto', name: 'Affitto', icon: 'home_repair_service', color: 0xFFA1887F, type: CategoryType.expense),
  // Income
  AppCategory(id: 'cat_stipendio', name: 'Stipendio', icon: 'card_giftcard', color: 0xFFFFC107, type: CategoryType.income),
  AppCategory(id: 'cat_regalo', name: 'Regalo', icon: 'card_giftcard', color: 0xFFFFC107, type: CategoryType.income),
  AppCategory(id: 'cat_rimborso', name: 'Rimborso', icon: 'card_giftcard', color: 0xFFFFC107, type: CategoryType.income),
];
