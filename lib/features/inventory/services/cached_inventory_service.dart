import 'package:flutter/foundation.dart';
import 'package:second_serving_frontend/features/inventory/data/inventory_local_db.dart';
import 'package:second_serving_frontend/features/inventory/models/inventory_item.dart';
import 'package:second_serving_frontend/features/inventory/services/inventory_service.dart';

/// Decorator de [InventoryService] que aplica el patrón
/// **stale-while-revalidate**:
///
/// - **Lecturas**: intenta el remoto; si falla por red, devuelve la cache
///   local. Si el remoto responde, refresca la cache.
/// - **Escrituras**: por ahora delega 1:1 al remoto y, en éxito, sincroniza
///   la fila local. Sin red, propaga la excepción del remoto. La cola offline
///   (outbox) llegará en una fase posterior.
///
/// Expone [lastReadFromCache] para que la capa superior pueda mostrar un
/// indicador "datos posiblemente desactualizados".
class CachedInventoryService implements InventoryService {
  CachedInventoryService({required this.remote, required this.db});

  final InventoryService remote;
  final InventoryLocalDb db;

  bool _lastReadFromCache = false;

  /// `true` cuando el último read fue servido desde cache (porque el remoto
  /// falló por red u otro error transitorio).
  bool get lastReadFromCache => _lastReadFromCache;

  @override
  Future<InventoryListResponse> getItems({int skip = 0, int limit = 20}) async {
    try {
      final response = await remote.getItems(skip: skip, limit: limit);
      // En la primera página refrescamos toda la cache; en páginas siguientes
      // hacemos upsert por ítem para no destruir lo previo.
      if (skip == 0) {
        await db.replaceAll(response.items);
      } else {
        for (final item in response.items) {
          await db.upsert(item);
        }
      }
      _lastReadFromCache = false;
      return response;
    } catch (e) {
      debugPrint('[CachedInventoryService] getItems remote failed: $e — '
          'sirviendo cache.');
      final cached = await db.getActiveItems(skip: skip, limit: limit);
      _lastReadFromCache = true;
      return InventoryListResponse(items: cached, total: cached.length);
    }
  }

  @override
  Future<List<InventoryItem>> getExpiringItems({int days = 3}) async {
    try {
      final items = await remote.getExpiringItems(days: days);
      for (final item in items) {
        await db.upsert(item);
      }
      _lastReadFromCache = false;
      return items;
    } catch (e) {
      debugPrint('[CachedInventoryService] getExpiringItems remote failed: '
          '$e — sirviendo cache.');
      final cached = await db.getExpiringWithinDays(days);
      _lastReadFromCache = true;
      return cached;
    }
  }

  @override
  Future<InventoryItem> createItem(Map<String, dynamic> data) async {
    final created = await remote.createItem(data);
    await db.upsert(created);
    return created;
  }

  @override
  Future<InventoryItem> updateItem(String id, Map<String, dynamic> data) async {
    final updated = await remote.updateItem(id, data);
    await db.upsert(updated);
    return updated;
  }

  @override
  Future<InventoryItem> consumeItem(String id) async {
    final updated = await remote.consumeItem(id);
    // Items consumidos salen del listado activo: eliminarlos de la cache.
    await db.deleteById(id);
    return updated;
  }

  @override
  Future<InventoryItem> discardItem(String id,
      {required String reason, double? quantity}) async {
    final updated =
        await remote.discardItem(id, reason: reason, quantity: quantity);
    if (updated.status.value == 'discarded') {
      await db.deleteById(id);
    } else {
      await db.upsert(updated);
    }
    return updated;
  }

  @override
  Future<void> deleteItem(String id) async {
    await remote.deleteItem(id);
    await db.deleteById(id);
  }
}
