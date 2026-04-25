import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:second_serving_frontend/features/inventory/models/inventory_item.dart';
import 'package:second_serving_frontend/features/inventory/services/inventory_service.dart';
import 'package:second_serving_frontend/features/inventory/services/local_inventory_service.dart';

/// ViewModel del inventario.
///
/// Estrategia de almacenamiento local: "Cache then network"
///   1. loadItems() primero lee del SQLite local (respuesta inmediata a la UI)
///   2. Luego intenta obtener datos frescos del backend
///   3. Si el backend responde, actualiza SQLite y la UI
///   4. Si el backend falla, la UI sigue mostrando datos locales (no queda en blanco)
///
/// Al crear items, se guardan en SQLite inmediatamente.
/// Si el backend falla, se encolan en pending_operations para sync posterior.
class InventoryProvider extends ChangeNotifier {
  final InventoryService _service;
  final LocalInventoryService _local = LocalInventoryService();

  List<InventoryItem> _items = [];
  List<InventoryItem> _expiringItems = [];
  int _total = 0;
  bool _isLoading = false;
  String? _error;

  InventoryProvider(this._service);

  List<InventoryItem> get items => _items;
  List<InventoryItem> get expiringItems => _expiringItems;
  int get total => _total;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Estrategia "Cache then network":
  /// Muestra datos locales al instante, luego refresca desde el backend.
  Future<void> loadItems({int skip = 0, int limit = 20}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    // 1) Leer del SQLite local (instantáneo)
    try {
      final localItems = await _local.getAllItems(skip: skip, limit: limit);
      final localCount = await _local.getItemCount();
      if (localItems.isNotEmpty) {
        _items = localItems;
        _total = localCount;
        _isLoading = false;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[InventoryProvider] Local read failed: $e');
    }

    // 2) Intentar red → actualizar SQLite y UI
    try {
      final response = await _service.getItems(skip: skip, limit: limit);
      _items = response.items;
      _total = response.total;

      await _local.upsertAll(response.items);
    } catch (e) {
      if (_items.isEmpty) {
        _error = e.toString();
      }
      debugPrint('[InventoryProvider] Network load failed (using local): $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadExpiringItems({int days = 3}) async {
    // 1) Local primero
    try {
      final localExpiring = await _local.getExpiringItems(days: days);
      if (localExpiring.isNotEmpty) {
        _expiringItems = localExpiring;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[InventoryProvider] Local expiring read failed: $e');
    }

    // 2) Red después
    try {
      _expiringItems = await _service.getExpiringItems(days: days);
      debugPrint('[InventoryProvider] expiringItems loaded: ${_expiringItems.length}');
      notifyListeners();
    } catch (e, st) {
      if (_expiringItems.isEmpty) {
        _error = e.toString();
      }
      debugPrint('[InventoryProvider] loadExpiringItems network error: $e');
      debugPrint('[InventoryProvider] stackTrace: $st');
      notifyListeners();
    }
  }

  /// Retorna `'synced'` si se guardó en el backend,
  /// `'queued'` si se encoló localmente para sync posterior,
  /// o `null` si falló por completo.
  Future<String?> addItem(Map<String, dynamic> data) async {
    _isLoading = true;
    notifyListeners();

    try {
      final item = await _service.createItem(data);
      _items.insert(0, item);
      _total++;

      await _local.upsertItem(item);

      _isLoading = false;
      notifyListeners();
      return 'synced';
    } catch (e) {
      debugPrint('[InventoryProvider] Backend addItem failed, queuing locally: $e');

      await _local.enqueuePendingOperation(
        operation: 'create',
        payload: data,
      );

      _isLoading = false;
      notifyListeners();
      return 'queued';
    }
  }

  Future<bool> updateItem(String id, Map<String, dynamic> data) async {
    try {
      final updated = await _service.updateItem(id, data);
      final idx = _items.indexWhere((i) => i.id == id);
      if (idx != -1) _items[idx] = updated;

      await _local.upsertItem(updated);

      notifyListeners();
      return true;
    } catch (e) {
      await _local.enqueuePendingOperation(
        operation: 'update',
        itemId: id,
        payload: data,
      );
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

      await _local.deleteItem(id);

      notifyListeners();
      return true;
    } catch (e) {
      await _local.enqueuePendingOperation(
        operation: 'consume',
        itemId: id,
        payload: {},
      );
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
        await _local.deleteItem(id);
      } else {
        final idx = _items.indexWhere((i) => i.id == id);
        if (idx != -1) _items[idx] = updated;
        await _local.upsertItem(updated);
      }
      notifyListeners();
      return true;
    } catch (e) {
      await _local.enqueuePendingOperation(
        operation: 'discard',
        itemId: id,
        payload: {'reason': reason, if (quantity != null) 'quantity': quantity},
      );
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

      await _local.deleteItem(id);

      notifyListeners();
      return true;
    } catch (e) {
      await _local.enqueuePendingOperation(
        operation: 'delete',
        itemId: id,
        payload: {},
      );
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Intenta sincronizar operaciones pendientes con el backend.
  Future<void> syncPendingOperations() async {
    final pending = await _local.getPendingOperations();
    if (pending.isEmpty) return;

    debugPrint('[InventoryProvider] Syncing ${pending.length} pending operations...');
    for (final op in pending) {
      try {
        final operation = op['operation'] as String;
        final itemId = op['item_id'] as String?;
        final payload = Map<String, dynamic>.from(
          _decodePayload(op['payload'] as String),
        );

        switch (operation) {
          case 'create':
            await _service.createItem(payload);
          case 'update':
            if (itemId != null) await _service.updateItem(itemId, payload);
          case 'consume':
            if (itemId != null) await _service.consumeItem(itemId);
          case 'discard':
            if (itemId != null) {
              await _service.discardItem(
                itemId,
                reason: payload['reason'] as String? ?? 'other',
                quantity: payload['quantity'] as double?,
              );
            }
          case 'delete':
            if (itemId != null) await _service.deleteItem(itemId);
        }

        await _local.removePendingOperation(op['id'] as int);
        debugPrint('[InventoryProvider] Synced op #${op['id']} ($operation)');
      } catch (e) {
        debugPrint('[InventoryProvider] Sync op #${op['id']} failed: $e');
        break;
      }
    }
  }

  Map<String, dynamic> _decodePayload(String raw) {
    try {
      return Map<String, dynamic>.from(
        const JsonDecoder().convert(raw) as Map,
      );
    } catch (_) {
      return {};
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
