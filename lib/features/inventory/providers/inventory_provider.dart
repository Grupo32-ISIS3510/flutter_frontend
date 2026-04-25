import 'dart:async';

import 'package:flutter/material.dart';
import 'package:second_serving_frontend/features/inventory/models/inventory_item.dart';
import 'package:second_serving_frontend/features/inventory/services/cached_inventory_service.dart';
import 'package:second_serving_frontend/features/inventory/services/inventory_service.dart';

class InventoryProvider extends ChangeNotifier {
  final InventoryService _service;
  final Future<void> Function()? _onInventoryMutated;

  List<InventoryItem> _items = [];
  List<InventoryItem> _expiringItems = [];
  int _total = 0;
  bool _isLoading = false;
  String? _error;
  bool _isStale = false;

  InventoryProvider(
    this._service, {
    Future<void> Function()? onInventoryMutated,
  }) : _onInventoryMutated = onInventoryMutated;

  void _fireMutationHook() {
    final hook = _onInventoryMutated;
    if (hook != null) {
      unawaited(hook());
    }
  }

  List<InventoryItem> get items => _items;
  List<InventoryItem> get expiringItems => _expiringItems;
  int get total => _total;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// `true` cuando el último read del backend falló y los datos visibles
  /// vienen de la cache local (puede que estén desactualizados).
  bool get isStale => _isStale;

  Future<void> loadItems({int skip = 0, int limit = 20}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _service.getItems(skip: skip, limit: limit);
      _items = response.items;
      _total = response.total;
      _updateStaleFlag();
      // Si servimos cache pero no hay items, conviene avisar al usuario.
      if (_isStale && _items.isEmpty) {
        _error = 'Sin conexión y sin datos cacheados';
      }
    } catch (e) {
      _error = e.toString();
      _isStale = true;
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadExpiringItems({int days = 3}) async {
    try {
      _expiringItems = await _service.getExpiringItems(days: days);
      _updateStaleFlag();
      debugPrint('[InventoryProvider] expiringItems loaded: ${_expiringItems.length}');
      notifyListeners();
    } catch (e, st) {
      _error = e.toString();
      _isStale = true;
      debugPrint('[InventoryProvider] loadExpiringItems ERROR: $e');
      debugPrint('[InventoryProvider] stackTrace: $st');
      notifyListeners();
    }
  }

  void _updateStaleFlag() {
    final svc = _service;
    if (svc is CachedInventoryService) {
      _isStale = svc.lastReadFromCache;
    }
  }

  Future<bool> addItem(Map<String, dynamic> data) async {
    _isLoading = true;
    notifyListeners();

    try {
      final item = await _service.createItem(data);
      _items.insert(0, item);
      _total++;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateItem(String id, Map<String, dynamic> data) async {
    try {
      final updated = await _service.updateItem(id, data);
      final idx = _items.indexWhere((i) => i.id == id);
      if (idx != -1) _items[idx] = updated;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> consumeItem(String id) async {
    try {
      await _service.consumeItem(id);
      _items.removeWhere((i) => i.id == id);
      _total--;
      notifyListeners();
      _fireMutationHook();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> discardItem(String id,
      {required String reason, double? quantity}) async {
    try {
      final updated =
          await _service.discardItem(id, reason: reason, quantity: quantity);
      if (updated.status.value == 'discarded') {
        _items.removeWhere((i) => i.id == id);
        _total--;
      } else {
        final idx = _items.indexWhere((i) => i.id == id);
        if (idx != -1) _items[idx] = updated;
      }
      notifyListeners();
      _fireMutationHook();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteItem(String id) async {
    try {
      await _service.deleteItem(id);
      _items.removeWhere((i) => i.id == id);
      _total--;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
