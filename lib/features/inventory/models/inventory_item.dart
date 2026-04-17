import 'package:second_serving_frontend/shared/models/enums.dart';

// PARSING DEFENSIVO: las APIs reales son inconsistentes. Un mismo campo
// puede llegar como int (5), double (5.0) o string ("5"). Esta función
// absorbe esa variabilidad sin que la app crashee.
int _parseInt(dynamic value) {
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is String) return int.parse(value);
  return 0;                              // Fallback seguro
}

// MODELO DE DOMINIO: representa un alimento del inventario.
// Inmutable (todos los campos final) → más seguro y predecible.
// Para "modificar" usar copyWith() (más abajo).
class InventoryItem {
  final String id;
  final String name;
  final ItemCategory category;          // enum con value, label y emoji
  final double quantity;
  final String? unit;                   // null si no aplica (e.g., "1 manzana")
  final double? unitPrice;              // null si el usuario no lo registró
  final DateTime purchaseDate;
  final DateTime expiryDate;
  final ItemStatus status;              // active / consumed / discarded
  // CLAVE: este campo lo CALCULA el BACKEND, no el cliente.
  // Evita bugs por reloj desincronizado del dispositivo (zona horaria, hora manual).
  final int daysRemaining;
  final String? notes;
  final DateTime createdAt;

  // Constructor const → permite usar instancias en lugares que requieren constantes.
  const InventoryItem({
    required this.id,
    required this.name,
    required this.category,
    required this.quantity,
    this.unit,
    this.unitPrice,
    required this.purchaseDate,
    required this.expiryDate,
    required this.status,
    required this.daysRemaining,
    this.notes,
    required this.createdAt,
  });

  // DOMINIO RICO: el modelo sabe responder preguntas sobre sí mismo.
  // Esto evita repartir `if (item.daysRemaining <= 3 && ...)` por toda la UI.
  // Si mañana cambia la regla, un solo lugar a tocar.
  bool get isExpiringSoon => daysRemaining <= 3 && status == ItemStatus.active;
  bool get isExpired => daysRemaining < 0 && status == ItemStatus.active;
  bool get isActive => status == ItemStatus.active;

  // Lógica simple pero útil: si no hay precio se asume 0 (?? operador).
  double get totalValue => (unitPrice ?? 0) * quantity;

  // FACTORY CONSTRUCTOR: convierte JSON crudo en objeto fuertemente tipado.
  // Es el "puente" entre la red (Map<String, dynamic>) y el dominio.
  factory InventoryItem.fromJson(Map<String, dynamic> json) {
    return InventoryItem(
      // `as String` = cast: lanza si el campo no es String (fail-fast en bugs).
      id: json['id'] as String,
      name: json['name'] as String,
      // Operador ?? para fallback si el backend omite la categoría.
      category: ItemCategory.fromString(json['category'] as String? ?? 'other'),
      // double.parse(toString()) absorbe int/double/string → siempre double.
      quantity: double.parse(json['quantity'].toString()),
      unit: json['unit'] as String?,    // ? indica que aceptamos null
      unitPrice: json['unit_price'] != null
          ? double.parse(json['unit_price'].toString())
          : null,
      // DateTime.parse acepta ISO 8601: "2026-04-17", "2026-04-17T10:30:00Z".
      purchaseDate: DateTime.parse(json['purchase_date'] as String),
      expiryDate: DateTime.parse(json['expiry_date'] as String),
      status: ItemStatus.fromString(json['status'] as String),
      daysRemaining: _parseInt(json['days_remaining']),    // ← parsing defensivo
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category.value,
        'quantity': quantity,
        'unit': unit,
        'unit_price': unitPrice,
        'purchase_date':
            '${purchaseDate.year}-${purchaseDate.month.toString().padLeft(2, '0')}-${purchaseDate.day.toString().padLeft(2, '0')}',
        'expiry_date':
            '${expiryDate.year}-${expiryDate.month.toString().padLeft(2, '0')}-${expiryDate.day.toString().padLeft(2, '0')}',
        'status': status.value,
        'notes': notes,
      };

  Map<String, dynamic> toCreateJson() => {
        'name': name,
        'category': category.value,
        'quantity': quantity,
        'unit': unit,
        'unit_price': unitPrice,
        'purchase_date':
            '${purchaseDate.year}-${purchaseDate.month.toString().padLeft(2, '0')}-${purchaseDate.day.toString().padLeft(2, '0')}',
        'expiry_date':
            '${expiryDate.year}-${expiryDate.month.toString().padLeft(2, '0')}-${expiryDate.day.toString().padLeft(2, '0')}',
        'notes': notes,
      };

  // PATRÓN copyWith: como el objeto es inmutable, "modificar" en realidad
  // significa crear una copia con uno o varios campos cambiados.
  // Ejemplo: item.copyWith(quantity: 0.5) → mismo item con menos cantidad.
  // Es la versión Dart del .copy() de Kotlin data classes.
  InventoryItem copyWith({
    String? id,
    String? name,
    ItemCategory? category,
    double? quantity,
    String? unit,
    double? unitPrice,
    DateTime? purchaseDate,
    DateTime? expiryDate,
    ItemStatus? status,
    int? daysRemaining,
    String? notes,
    DateTime? createdAt,
  }) {
    return InventoryItem(
      // Para cada campo: usa el nuevo valor si se pasó, si no mantiene el actual.
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      unitPrice: unitPrice ?? this.unitPrice,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      expiryDate: expiryDate ?? this.expiryDate,
      status: status ?? this.status,
      daysRemaining: daysRemaining ?? this.daysRemaining,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class InventoryListResponse {
  final List<InventoryItem> items;
  final int total;

  const InventoryListResponse({required this.items, required this.total});

  factory InventoryListResponse.fromJson(Map<String, dynamic> json) {
    return InventoryListResponse(
      items: (json['items'] as List)
          .map((e) => InventoryItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: json['total'] as int,
    );
  }
}
