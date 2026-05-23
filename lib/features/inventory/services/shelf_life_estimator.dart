import 'package:second_serving_frontend/shared/models/enums.dart';

/// Estima la fecha de vencimiento de un producto basándose en su categoría.
///
/// Los valores representan la vida útil promedio en días para cada tipo
/// de alimento almacenado en condiciones domésticas estándar (refrigerador
/// o alacena según corresponda).
class ShelfLifeEstimator {
  static const Map<ItemCategory, int> _shelfLifeDays = {
    ItemCategory.dairy: 10,
    ItemCategory.meat: 4,
    ItemCategory.fruits: 7,
    ItemCategory.vegetables: 6,
    ItemCategory.grains: 180,
    ItemCategory.beverages: 60,
    ItemCategory.snacks: 60,
    ItemCategory.other: 5,
  };

  static DateTime estimateExpiryDate(
    ItemCategory category, {
    DateTime? purchaseDate,
  }) {
    final base = purchaseDate ?? DateTime.now();
    final days = _shelfLifeDays[category] ?? 5;
    return DateTime(base.year, base.month, base.day + days);
  }

  static int getShelfLifeDays(ItemCategory category) {
    return _shelfLifeDays[category] ?? 5;
  }
}
