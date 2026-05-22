import 'package:flutter/material.dart';
import 'package:second_serving_frontend/features/inventory/models/inventory_item.dart';
import 'package:second_serving_frontend/features/recipes/models/recipe.dart';
import 'package:second_serving_frontend/features/shopping_list/models/shopping_item.dart';
import 'package:second_serving_frontend/features/shopping_list/services/local_shopping_list_service.dart';
import 'package:second_serving_frontend/features/shopping_list/services/shopping_suggestions_service.dart';
import 'package:second_serving_frontend/shared/models/enums.dart';

/// ViewModel de la lista de compras.
///
/// Estrategia: local-first. Toda mutacion se aplica primero en SQLite y luego
/// se notifica a la UI. Se deja preparada la cola offline para sincronizar
/// con el backend AWS en cuando el endpoint este disponible.
class ShoppingListProvider extends ChangeNotifier {
  final LocalShoppingListService _local;
  final ShoppingSuggestionsService _suggestions;

  List<ShoppingItem> _items = [];
  List<ShoppingSuggestion> _currentSuggestions = [];
  bool _isLoading = false;
  String? _error;

  ShoppingListProvider({
    LocalShoppingListService? local,
    ShoppingSuggestionsService? suggestions,
  })  : _local = local ?? LocalShoppingListService(),
        _suggestions = suggestions ?? ShoppingSuggestionsService();

  List<ShoppingItem> get items => _items;
  List<ShoppingItem> get pendingItems =>
      _items.where((i) => !i.purchased).toList();
  List<ShoppingItem> get purchasedItems =>
      _items.where((i) => i.purchased).toList();
  List<ShoppingSuggestion> get suggestions => _currentSuggestions;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get totalCount => _items.length;
  int get pendingCount => pendingItems.length;

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();
    try {
      _items = await _local.getAll();
      _error = null;
    } catch (e) {
      _error = e.toString();
      debugPrint('[ShoppingList] load error: $e');
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> addManual({
    required String name,
    required ItemCategory category,
    double quantity = 1,
    String? unit,
  }) async {
    final item = ShoppingItem(
      id: 'sl_${DateTime.now().millisecondsSinceEpoch}',
      name: name.trim(),
      category: category,
      quantity: quantity,
      unit: unit,
      createdAt: DateTime.now(),
    );
    await _local.upsert(item, synced: false);
    await _local.enqueuePendingOperation(
      operation: 'create',
      itemId: item.id,
      payload: item.toJson(),
    );
    _items = [item, ..._items];
    notifyListeners();
  }

  Future<void> addFromSuggestion(ShoppingSuggestion suggestion) async {
    final item = ShoppingItem(
      id: 'sl_${DateTime.now().millisecondsSinceEpoch}',
      name: suggestion.name,
      category: suggestion.category,
      quantity: suggestion.quantity,
      unit: suggestion.unit,
      source: suggestion.source,
      sourceRef: suggestion.sourceRef,
      createdAt: DateTime.now(),
    );
    await _local.upsert(item, synced: false);
    await _local.enqueuePendingOperation(
      operation: 'create',
      itemId: item.id,
      payload: item.toJson(),
    );
    _items = [item, ..._items];
    _currentSuggestions = _currentSuggestions
        .where((s) => s.name != suggestion.name)
        .toList();
    notifyListeners();
  }

  Future<void> togglePurchased(String id) async {
    final idx = _items.indexWhere((i) => i.id == id);
    if (idx == -1) return;
    final updated = _items[idx].copyWith(purchased: !_items[idx].purchased);
    await _local.upsert(updated, synced: false);
    await _local.enqueuePendingOperation(
      operation: 'update',
      itemId: id,
      payload: {'purchased': updated.purchased},
    );
    _items[idx] = updated;
    notifyListeners();
  }

  Future<void> remove(String id) async {
    await _local.delete(id);
    await _local.enqueuePendingOperation(
      operation: 'delete',
      itemId: id,
      payload: {},
    );
    _items = _items.where((i) => i.id != id).toList();
    notifyListeners();
  }

  Future<void> clearPurchased() async {
    final purchasedIds = _items.where((i) => i.purchased).map((i) => i.id).toList();
    await _local.deletePurchased();
    for (final id in purchasedIds) {
      await _local.enqueuePendingOperation(
        operation: 'delete',
        itemId: id,
        payload: {},
      );
    }
    _items = _items.where((i) => !i.purchased).toList();
    notifyListeners();
  }

  void refreshSuggestions({
    required List<InventoryItem> activeInventory,
    required List<InventoryItem> recentlyConsumed,
    required List<RecipeDetail> nearbyRecipes,
  }) {
    _currentSuggestions = _suggestions.generate(
      activeInventory: activeInventory,
      recentlyConsumed: recentlyConsumed,
      nearbyRecipes: nearbyRecipes,
      currentList: _items,
    );
    notifyListeners();
  }

  void dismissSuggestion(ShoppingSuggestion suggestion) {
    _currentSuggestions = _currentSuggestions
        .where((s) => s.name != suggestion.name)
        .toList();
    notifyListeners();
  }
}
