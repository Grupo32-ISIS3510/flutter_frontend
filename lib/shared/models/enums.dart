enum ItemCategory {
  // `value` ahora es la representación en ESPAÑOL que se persiste y envía al
  // backend (e.g. POST /inventory body: { "category": "Frutas" }).
  // `label` es lo que se muestra en UI (puede coincidir con value).
  // `emoji` es el icono visual.
  dairy('Lácteos', 'Lácteos', '🥛'),
  fruits('Frutas', 'Frutas', '🍎'),
  vegetables('Verduras', 'Verduras', '🥦'),
  meat('Carnes', 'Carnes', '🥩'),
  grains('Granos', 'Granos', '🌾'),
  beverages('Bebidas', 'Bebidas', '🥤'),
  snacks('Snacks', 'Snacks', '🍪'),
  other('Otros', 'Otros', '📦');

  final String value;
  final String label;
  final String emoji;

  const ItemCategory(this.value, this.label, this.emoji);

  // Mapeo de valores LEGACY en inglés que aún pueden venir en la base de datos
  // de items creados antes del cambio (e.g. el "Tomate" con category: "fruits").
  // Mantener este mapping garantiza retrocompatibilidad sin migración masiva.
  static const Map<String, ItemCategory> _legacyEnglishValues = {
    'dairy': ItemCategory.dairy,
    'fruits': ItemCategory.fruits,
    'vegetables': ItemCategory.vegetables,
    'meat': ItemCategory.meat,
    'grains': ItemCategory.grains,
    'beverages': ItemCategory.beverages,
    'snacks': ItemCategory.snacks,
    'other': ItemCategory.other,
  };

  // PARSING TOLERANTE: acepta múltiples formas del mismo valor:
  //   - Canónico español: "Frutas", "Lácteos"
  //   - Variantes de caso/whitespace: "frutas", "  LÁCTEOS  "
  //   - Legacy inglés: "fruits", "dairy"
  // Cualquier desconocido cae a `other` (jamás crashea).
  static ItemCategory fromString(String value) {
    final normalized = value.trim().toLowerCase();

    // 1) Match canónico en español (case-insensitive)
    for (final cat in ItemCategory.values) {
      if (cat.value.toLowerCase() == normalized) return cat;
    }

    // 2) Backward compatibility con valores legacy en inglés
    return _legacyEnglishValues[normalized] ?? ItemCategory.other;
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
