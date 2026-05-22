import 'package:second_serving_frontend/shared/models/enums.dart';

/// Origen de un item de la lista de compras.
/// - manual: agregado a mano por el usuario
/// - consumed: sugerido porque se consumió en el inventario
/// - recipe: sugerido porque falta para una receta
enum ShoppingItemSource {
  manual('manual'),
  consumed('consumed'),
  recipe('recipe');

  final String value;
  const ShoppingItemSource(this.value);

  static ShoppingItemSource fromString(String value) {
    return ShoppingItemSource.values.firstWhere(
      (e) => e.value == value,
      orElse: () => ShoppingItemSource.manual,
    );
  }
}

class ShoppingItem {
  final String id;
  final String name;
  final ItemCategory category;
  final double quantity;
  final String? unit;
  final bool purchased;
  final ShoppingItemSource source;
  final String? sourceRef;
  final DateTime createdAt;

  const ShoppingItem({
    required this.id,
    required this.name,
    required this.category,
    required this.quantity,
    this.unit,
    this.purchased = false,
    this.source = ShoppingItemSource.manual,
    this.sourceRef,
    required this.createdAt,
  });

  ShoppingItem copyWith({
    String? id,
    String? name,
    ItemCategory? category,
    double? quantity,
    String? unit,
    bool? purchased,
    ShoppingItemSource? source,
    String? sourceRef,
    DateTime? createdAt,
  }) {
    return ShoppingItem(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      purchased: purchased ?? this.purchased,
      source: source ?? this.source,
      sourceRef: sourceRef ?? this.sourceRef,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category.value,
        'quantity': quantity,
        'unit': unit,
        'purchased': purchased,
        'source': source.value,
        'source_ref': sourceRef,
        'created_at': createdAt.toIso8601String(),
      };

  factory ShoppingItem.fromJson(Map<String, dynamic> json) {
    return ShoppingItem(
      id: json['id'] as String,
      name: json['name'] as String,
      category: ItemCategory.fromString(json['category'] as String? ?? 'Otros'),
      quantity: (json['quantity'] as num?)?.toDouble() ?? 1,
      unit: json['unit'] as String?,
      purchased: json['purchased'] as bool? ?? false,
      source: ShoppingItemSource.fromString(json['source'] as String? ?? 'manual'),
      sourceRef: json['source_ref'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
