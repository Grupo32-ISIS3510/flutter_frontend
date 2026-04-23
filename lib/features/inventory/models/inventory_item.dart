import 'package:second_serving_frontend/shared/models/enums.dart';

int _parseInt(dynamic value) {
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is String) return int.parse(value);
  return 0;
}

class InventoryItem {
  final String id;
  final String name;
  final ItemCategory category;
  final double quantity;
  final String? unit;
  final double? unitPrice;
  final DateTime purchaseDate;
  final DateTime expiryDate;
  final ItemStatus status;
  final int daysRemaining;
  final String? notes;
  final DateTime createdAt;

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

  bool get isExpiringSoon => daysRemaining <= 3 && status == ItemStatus.active;
  bool get isExpired => daysRemaining < 0 && status == ItemStatus.active;
  bool get isActive => status == ItemStatus.active;

  double get totalValue => (unitPrice ?? 0) * quantity;

  factory InventoryItem.fromJson(Map<String, dynamic> json) {
    return InventoryItem(
      id: json['id'] as String,
      name: json['name'] as String,
      category: ItemCategory.fromString(json['category'] as String? ?? 'other'),
      quantity: double.parse(json['quantity'].toString()),
      unit: json['unit'] as String?,
      unitPrice: json['unit_price'] != null
          ? double.parse(json['unit_price'].toString())
          : null,
      purchaseDate: DateTime.parse(json['purchase_date'] as String),
      expiryDate: DateTime.parse(json['expiry_date'] as String),
      status: ItemStatus.fromString(json['status'] as String),
      daysRemaining: _parseInt(json['days_remaining']),
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
