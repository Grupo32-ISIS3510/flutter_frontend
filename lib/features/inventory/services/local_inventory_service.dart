import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:second_serving_frontend/core/storage/app_database.dart';
import 'package:second_serving_frontend/features/inventory/models/inventory_item.dart';
import 'package:second_serving_frontend/shared/models/enums.dart';

/// Servicio DAO para acceder a la tabla inventory_items en SQLite.
/// Implementa operaciones CRUD locales y manejo de cola offline.
class LocalInventoryService {
  Future<Database> get _db => AppDatabase.instance;

  // ── READ ──────────────────────────────────────────────────

  Future<List<InventoryItem>> getAllItems({int skip = 0, int limit = 20}) async {
    final db = await _db;
    final rows = await db.query(
      'inventory_items',
      where: 'status = ?',
      whereArgs: ['active'],
      orderBy: 'created_at DESC',
      limit: limit,
      offset: skip,
    );
    return rows.map(_rowToItem).toList();
  }

  Future<int> getItemCount() async {
    final db = await _db;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM inventory_items WHERE status = ?',
      ['active'],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<List<InventoryItem>> getExpiringItems({int days = 3}) async {
    final db = await _db;
    final now = DateTime.now();
    final cutoff = now.add(Duration(days: days));
    final cutoffStr =
        '${cutoff.year}-${cutoff.month.toString().padLeft(2, '0')}-${cutoff.day.toString().padLeft(2, '0')}';

    final rows = await db.query(
      'inventory_items',
      where: 'status = ? AND expiry_date <= ?',
      whereArgs: ['active', cutoffStr],
      orderBy: 'expiry_date ASC',
    );
    return rows.map(_rowToItem).toList();
  }

  Future<InventoryItem?> getItemById(String id) async {
    final db = await _db;
    final rows = await db.query(
      'inventory_items',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _rowToItem(rows.first);
  }

  // ── WRITE ─────────────────────────────────────────────────

  Future<void> upsertItem(InventoryItem item, {bool synced = true}) async {
    final db = await _db;
    await db.insert(
      'inventory_items',
      _itemToRow(item, synced: synced),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> upsertAll(List<InventoryItem> items) async {
    final db = await _db;
    final batch = db.batch();
    for (final item in items) {
      batch.insert(
        'inventory_items',
        _itemToRow(item, synced: true),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
    debugPrint('[LocalInventory] Synced ${items.length} items to SQLite');
  }

  Future<void> deleteItem(String id) async {
    final db = await _db;
    await db.delete('inventory_items', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearAll() async {
    final db = await _db;
    await db.delete('inventory_items');
  }

  // ── PENDING OPERATIONS (cola offline) ─────────────────────

  Future<void> enqueuePendingOperation({
    required String operation,
    String? itemId,
    required Map<String, dynamic> payload,
  }) async {
    final db = await _db;
    await db.insert('pending_operations', {
      'operation': operation,
      'table_name': 'inventory_items',
      'item_id': itemId,
      'payload': jsonEncode(payload),
      'created_at': DateTime.now().toIso8601String(),
    });
    debugPrint('[LocalInventory] Enqueued offline op: $operation');
  }

  Future<List<Map<String, dynamic>>> getPendingOperations() async {
    final db = await _db;
    return db.query('pending_operations', orderBy: 'id ASC');
  }

  Future<void> removePendingOperation(int id) async {
    final db = await _db;
    await db.delete('pending_operations', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> getPendingCount() async {
    final db = await _db;
    final result = await db.rawQuery('SELECT COUNT(*) as cnt FROM pending_operations');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // ── MAPPERS ───────────────────────────────────────────────

  InventoryItem _rowToItem(Map<String, dynamic> row) {
    final now = DateTime.now();
    final expiry = DateTime.parse(row['expiry_date'] as String);
    final daysRemaining = expiry.difference(now).inDays;

    return InventoryItem(
      id: row['id'] as String,
      name: row['name'] as String,
      category: _parseCategory(row['category'] as String),
      quantity: (row['quantity'] as num).toDouble(),
      unit: row['unit'] as String?,
      unitPrice: row['unit_price'] != null ? (row['unit_price'] as num).toDouble() : null,
      purchaseDate: DateTime.parse(row['purchase_date'] as String),
      expiryDate: expiry,
      status: _parseStatus(row['status'] as String),
      daysRemaining: daysRemaining,
      notes: row['notes'] as String?,
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }

  Map<String, dynamic> _itemToRow(InventoryItem item, {required bool synced}) {
    return {
      'id': item.id,
      'name': item.name,
      'category': item.category.value,
      'quantity': item.quantity,
      'unit': item.unit,
      'unit_price': item.unitPrice,
      'purchase_date': _formatDate(item.purchaseDate),
      'expiry_date': _formatDate(item.expiryDate),
      'status': item.status.value,
      'days_remaining': item.daysRemaining,
      'notes': item.notes,
      'created_at': item.createdAt.toIso8601String(),
      'synced': synced ? 1 : 0,
    };
  }

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  ItemCategory _parseCategory(String value) {
    return ItemCategory.fromString(value);
  }

  ItemStatus _parseStatus(String value) {
    return ItemStatus.fromString(value);
  }
}
