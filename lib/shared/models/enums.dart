enum ItemCategory {
  dairy('dairy', 'Lácteos', '🥛'),
  fruits('fruits', 'Frutas', '🍎'),
  vegetables('vegetables', 'Verduras', '🥦'),
  meat('meat', 'Carnes', '🥩'),
  grains('grains', 'Granos', '🌾'),
  beverages('beverages', 'Bebidas', '🥤'),
  snacks('snacks', 'Snacks', '🍪'),
  other('other', 'Otros', '📦');

  final String value;
  final String label;
  final String emoji;

  const ItemCategory(this.value, this.label, this.emoji);

  static ItemCategory fromString(String value) {
    return ItemCategory.values.firstWhere(
      (e) => e.value == value,
      orElse: () => ItemCategory.other,
    );
  }
}

enum ItemStatus {
  active('active', 'Activo'),
  consumed('consumed', 'Consumido'),
  discarded('discarded', 'Descartado');

  final String value;
  final String label;

  const ItemStatus(this.value, this.label);

  static ItemStatus fromString(String value) {
    return ItemStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => ItemStatus.active,
    );
  }
}

enum RecipeCategory {
  breakfast('breakfast', 'Desayuno', '🌅'),
  lunch('lunch', 'Almuerzo', '☀️'),
  dinner('dinner', 'Cena', '🌙'),
  snack('snack', 'Snack', '🍿');

  final String value;
  final String label;
  final String emoji;

  const RecipeCategory(this.value, this.label, this.emoji);

  static RecipeCategory fromString(String value) {
    return RecipeCategory.values.firstWhere(
      (e) => e.value == value,
      orElse: () => RecipeCategory.lunch,
    );
  }
}

enum DiscardReason {
  expired('expired', 'Expirado'),
  overPurchase('over_purchase', 'Compra excesiva'),
  badStorage('bad_storage', 'Mal almacenamiento'),
  other('other', 'Otro');

  final String value;
  final String label;

  const DiscardReason(this.value, this.label);
}

enum RecipeAction {
  viewed('viewed'),
  cooked('cooked');

  final String value;
  const RecipeAction(this.value);
}

enum UserSegmentType {
  proactive('proactive', 'Proactivo'),
  neutral('neutral', 'Neutral'),
  passive('passive', 'Pasivo');

  final String value;
  final String label;

  const UserSegmentType(this.value, this.label);
}
