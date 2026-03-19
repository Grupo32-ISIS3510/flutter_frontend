import 'package:second_serving_frontend/models/enums.dart';
import 'package:second_serving_frontend/models/inventory_item.dart';
import 'package:second_serving_frontend/services/inventory_service.dart';
import 'package:second_serving_frontend/services/mock/mock_data.dart';

class MockInventoryService implements InventoryService {
  final List<InventoryItem> _items = List.from(MockData.inventoryItems);

  @override
  Future<InventoryListResponse> getItems({int skip = 0, int limit = 20}) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final active = _items.where((i) => i.status == ItemStatus.active).toList();
    final page = active.skip(skip).take(limit).toList();
    return InventoryListResponse(items: page, total: active.length);
  }

  @override
  Future<List<InventoryItem>> getExpiringItems({int days = 3}) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _items
        .where((i) => i.status == ItemStatus.active && i.daysRemaining <= days)
        .toList()
      ..sort((a, b) => a.daysRemaining.compareTo(b.daysRemaining));
  }

  @override
  Future<InventoryItem> createItem(Map<String, dynamic> data) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final item = InventoryItem(
      id: 'inv-${DateTime.now().millisecondsSinceEpoch}',
      name: data['name'] as String,
      category: ItemCategory.fromString(data['category'] as String? ?? 'other'),
      quantity: (data['quantity'] as num?)?.toDouble() ?? 1,
      unit: data['unit'] as String?,
      unitPrice: (data['unit_price'] as num?)?.toDouble(),
      purchaseDate: DateTime.parse(data['purchase_date'] as String),
      expiryDate: DateTime.parse(data['expiry_date'] as String),
      status: ItemStatus.active,
      daysRemaining: DateTime.parse(data['expiry_date'] as String)
          .difference(DateTime.now())
          .inDays,
      notes: data['notes'] as String?,
      createdAt: DateTime.now(),
    );
    _items.add(item);
    return item;
  }

  @override
  Future<InventoryItem> updateItem(String id, Map<String, dynamic> data) async {
    await Future.delayed(const Duration(milliseconds: 400));
    final idx = _items.indexWhere((i) => i.id == id);
    if (idx == -1) throw Exception('Item no encontrado');
    final old = _items[idx];
    final updated = old.copyWith(
      name: data['name'] as String? ?? old.name,
      category: data['category'] != null
          ? ItemCategory.fromString(data['category'] as String)
          : old.category,
      quantity: (data['quantity'] as num?)?.toDouble() ?? old.quantity,
      unit: data['unit'] as String? ?? old.unit,
      unitPrice: (data['unit_price'] as num?)?.toDouble() ?? old.unitPrice,
      notes: data['notes'] as String? ?? old.notes,
    );
    _items[idx] = updated;
    return updated;
  }

  @override
  Future<InventoryItem> consumeItem(String id) async {
    await Future.delayed(const Duration(milliseconds: 400));
    final idx = _items.indexWhere((i) => i.id == id);
    if (idx == -1) throw Exception('Item no encontrado');
    final updated = _items[idx].copyWith(status: ItemStatus.consumed);
    _items[idx] = updated;
    return updated;
  }

  @override
  Future<InventoryItem> discardItem(String id,
      {required String reason, double? quantity}) async {
    await Future.delayed(const Duration(milliseconds: 400));
    final idx = _items.indexWhere((i) => i.id == id);
    if (idx == -1) throw Exception('Item no encontrado');
    final old = _items[idx];
    if (quantity != null && quantity < old.quantity) {
      final updated = old.copyWith(quantity: old.quantity - quantity);
      _items[idx] = updated;
      return updated;
    }
    final updated = old.copyWith(status: ItemStatus.discarded);
    _items[idx] = updated;
    return updated;
  }

  @override
  Future<void> deleteItem(String id) async {
    await Future.delayed(const Duration(milliseconds: 300));
    _items.removeWhere((i) => i.id == id);
  }
}
