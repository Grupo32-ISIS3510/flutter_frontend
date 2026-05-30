import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:second_serving_frontend/features/inventory/data/inventory_local_db.dart';
import 'package:second_serving_frontend/features/inventory/models/inventory_item.dart';
import 'package:second_serving_frontend/features/inventory/services/cached_inventory_service.dart';
import 'package:second_serving_frontend/features/inventory/services/inventory_service.dart';
import 'package:second_serving_frontend/features/inventory/services/local_inventory_service.dart';
import 'package:second_serving_frontend/shared/models/enums.dart';

/// ViewModel del inventario.
///
/// Estrategia de almacenamiento local: "Cache then network"
///   - Las lecturas se delegan a [CachedInventoryService] que implementa
///     stale-while-revalidate: intenta el remoto, si falla sirve la cache.
///   - Las escrituras se delegan al servicio. Si el backend falla,
///     se encolan en pending_operations (SQLite) para sync posterior.
class InventoryProvider extends ChangeNotifier {
  final InventoryService _service;
  final LocalInventoryService _local = LocalInventoryService();
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

  // ── Micro-optimización (PPoF #3) ─────────────────────────────────────────
  // Getter memoizado con los nombres de los primeros 8 ingredientes por vencer.
  // Evita recalcular `map → toSet → take → toList` en cada `build()` de
  // RecipesScreen: solo recomputa cuando cambia la referencia de _expiringItems.
  List<String>? _cachedChipNames;
  List<InventoryItem>? _lastExpiringRef;

  List<String> get topExpiringIngredientNames {
    if (identical(_lastExpiringRef, _expiringItems) && _cachedChipNames != null) {
      return _cachedChipNames!;
    }
    _lastExpiringRef = _expiringItems;
    _cachedChipNames =
        _expiringItems.map((i) => i.name).toSet().take(8).toList();
    return _cachedChipNames!;
  }

  int get total => _total;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// `true` cuando el último read del backend falló y los datos visibles
  /// vienen de la cache local (puede que estén desactualizados).
  bool get isStale => _isStale;

  // Carga una página amplia para que el inventario completo sea visible: la
  // pantalla no implementa scroll infinito, así que con `limit: 20` los items
  // más allá del 20 (p. ej. uno recién agregado con vencimiento lejano) no se veían.
  // `SliverList.builder` renderiza de forma perezosa, así que subir el límite no
  // afecta memoria de UI; solo agranda el payload de red.
  Future<void> loadItems({int skip = 0, int limit = 200}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _service.getItems(skip: skip, limit: limit);
      _items = response.items;
      _total = response.total;
      _updateStaleFlag();
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
      debugPrint(
          '[InventoryProvider] expiringItems loaded: ${_expiringItems.length}');
      notifyListeners();
    } catch (e, st) {
      _isStale = true;
      if (_expiringItems.isEmpty) {
        _error = e.toString();
      }
      debugPrint('[InventoryProvider] loadExpiringItems error: $e');
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
      _isLoading = false;
      notifyListeners();
      _fireMutationHook();
      return 'synced';
    } catch (e) {
      debugPrint(
          '[InventoryProvider] Backend addItem failed, queuing locally: $e');
      await _local.enqueuePendingOperation(
        operation: 'create',
        payload: data,
      );

      // Inserción optimista: el alimento debe verse en el inventario aunque no
      // haya red. Se construye con un id local temporal y se persiste en la
      // cache de lectura (InventoryLocalDb) para que sobreviva a un reload
      // offline y al reinicio de la app. Al reconectar, syncPendingOperations
      // crea el item real y el siguiente loadItems online reemplaza la cache
      // (el temporal se descarta).
      final optimistic = _buildOptimisticItem(data);
      if (optimistic != null) {
        _items.insert(0, optimistic);
        _total++;
        try {
          await InventoryLocalDb.instance.upsert(optimistic);
        } catch (cacheErr) {
          debugPrint(
              '[InventoryProvider] optimistic cache upsert failed: $cacheErr');
        }
      }

      _isLoading = false;
      notifyListeners();
      _fireMutationHook();
      return 'queued';
    }
  }

  /// Construye un [InventoryItem] a partir del payload de creación para mostrarlo
  /// de inmediato cuando el guardado se encola sin conexión. Devuelve null si el
  /// payload está incompleto (en cuyo caso simplemente no se inserta).
  InventoryItem? _buildOptimisticItem(Map<String, dynamic> data) {
    try {
      final now = DateTime.now();
      return InventoryItem(
        id: 'local_${now.millisecondsSinceEpoch}',
        name: data['name'] as String,
        category: ItemCategory.fromString(data['category'] as String? ?? 'other'),
        quantity: double.parse(data['quantity'].toString()),
        unit: data['unit'] as String?,
        unitPrice: data['unit_price'] != null
            ? double.parse(data['unit_price'].toString())
            : null,
        purchaseDate: DateTime.parse(data['purchase_date'] as String),
        expiryDate: DateTime.parse(data['expiry_date'] as String),
        status: ItemStatus.active,
        notes: data['notes'] as String?,
        createdAt: now,
      );
    } catch (e) {
      debugPrint('[InventoryProvider] could not build optimistic item: $e');
      return null;
    }
  }

  Future<bool> updateItem(String id, Map<String, dynamic> data) async {
    try {
      final updated = await _service.updateItem(id, data);
      final idx = _items.indexWhere((i) => i.id == id);
      if (idx != -1) _items[idx] = updated;
      notifyListeners();
      _fireMutationHook();
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
      notifyListeners();
      _fireMutationHook();
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
      } else {
        final idx = _items.indexWhere((i) => i.id == id);
        if (idx != -1) _items[idx] = updated;
      }
      notifyListeners();
      _fireMutationHook();
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
      notifyListeners();
      _fireMutationHook();
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

    debugPrint(
        '[InventoryProvider] Syncing ${pending.length} pending operations...');
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
