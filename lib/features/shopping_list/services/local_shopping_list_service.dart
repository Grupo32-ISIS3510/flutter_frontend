import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:second_serving_frontend/core/storage/app_database.dart';
import 'package:second_serving_frontend/features/shopping_list/models/shopping_item.dart';
import 'package:second_serving_frontend/shared/models/enums.dart';

/// DAO para la tabla shopping_list_items en SQLite.
/// Implementa CRUD local y cola offline de operaciones pendientes
/// (mismo patron que LocalInventoryService) para sincronizar con el
/// backend AWS cuando este disponible.
class LocalShoppingListService {
  static const _table = 'shopping_list_items';
  static const _tableName = 'shopping_list_items';

  Future<Database> get _db => AppDatabase.instance;

  Future<List<ShoppingItem>> getAll() async {
    final db = await _db;
    final rows = await db.query(_table, orderBy: 'purchased ASC, created_at DESC');
    return rows.map(_rowToItem).toList();
  }

  Future<ShoppingItem?> getById(String id) async {
    final db = await _db;
    final rows = await db.query(
      _table,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _rowToItem(rows.first);
  }

  Future<void> upsert(ShoppingItem item, {bool synced = true}) async {
    final db = await _db;
    await db.insert(
      _table,
      _itemToRow(item, synced: synced),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> delete(String id) async {
    final db = await _db;
    await db.delete(_table, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deletePurchased() async {
    final db = await _db;
    await db.delete(_table, where: 'purchased = ?', whereArgs: [1]);
  }

  Future<void> clearAll() async {
    final db = await _db;
    await db.delete(_table);
  }

  // ── Cola offline (mismo patron que inventory) ────────────────

  Future<void> enqueuePendingOperation({
    required String operation,
    String? itemId,
    required Map<String, dynamic> payload,
  }) async {
    final db = await _db;
    await db.insert('pending_operations', {
      'operation': operation,
      'table_name': _tableName,
      'item_id': itemId,
      'payload': jsonEncode(payload),
      'created_at': DateTime.now().toIso8601String(),
    });
    debugPrint('[LocalShoppingList] Enqueued offline op: $operation');
  }

  // ── Mappers ──────────────────────────────────────────────────

  ShoppingItem _rowToItem(Map<String, dynamic> row) {
    return ShoppingItem(
      id: row['id'] as String,
      name: row['name'] as String,
      category: ItemCategory.fromString(row['category'] as String),
      quantity: (row['quantity'] as num).toDouble(),
      unit: row['unit'] as String?,
      purchased: (row['purchased'] as int) == 1,
      source: ShoppingItemSource.fromString(row['source'] as String? ?? 'manual'),
      sourceRef: row['source_ref'] as String?,
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }

  Map<String, dynamic> _itemToRow(ShoppingItem item, {required bool synced}) {
    return {
      'id': item.id,
      'name': item.name,
      'category': item.category.value,
      'quantity': item.quantity,
      'unit': item.unit,
      'purchased': item.purchased ? 1 : 0,
      'source': item.source.value,
      'source_ref': item.sourceRef,
      'created_at': item.createdAt.toIso8601String(),
      'synced': synced ? 1 : 0,
    };
  }
}
