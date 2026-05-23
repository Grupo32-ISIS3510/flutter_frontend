import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:second_serving_frontend/features/inventory/models/inventory_item.dart';
import 'package:second_serving_frontend/shared/models/enums.dart';
import 'package:sqflite/sqflite.dart';

/// Cache local del inventario en SQLite.
///
/// Esquema v1 — refleja el modelo [InventoryItem] del backend con un campo
/// extra `synced_at` (epoch ms) para saber cuándo se actualizó cada fila.
///
/// Se accede como singleton: [InventoryLocalDb.instance]. Llamar [initialize]
/// una vez en `main()` antes de usarlo.
class InventoryLocalDb {
  InventoryLocalDb._();
  static final InventoryLocalDb instance = InventoryLocalDb._();

  static const _dbName = 'inventory.db';
  static const _table = 'inventory_items';
  static const _schemaVersion = 1;

  Database? _db;

  Future<void> initialize() async {
    if (_db != null) return;
    final dbPath = await getDatabasesPath();
    _db = await openDatabase(
      p.join(dbPath, _dbName),
      version: _schemaVersion,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE $_table (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            category TEXT NOT NULL,
            quantity REAL NOT NULL,
            unit TEXT,
            unit_price REAL,
            purchase_date TEXT NOT NULL,
            expiry_date TEXT NOT NULL,
            status TEXT NOT NULL,
            notes TEXT,
            created_at TEXT NOT NULL,
            synced_at INTEGER NOT NULL
          )
        ''');
        await db
            .execute('CREATE INDEX idx_status ON $_table(status)');
        await db
            .execute('CREATE INDEX idx_expiry ON $_table(expiry_date)');
      },
    );
  }

  Database get _required {
    final db = _db;
    if (db == null) {
      throw StateError(
          'InventoryLocalDb no inicializada. Llama a initialize() primero.');
    }
    return db;
  }

  /// Lee items activos paginados (mismo contrato que el endpoint del backend).
  Future<List<InventoryItem>> getActiveItems({int? skip, int? limit}) async {
    final rows = await _required.query(
      _table,
      where: 'status = ?',
      whereArgs: [ItemStatus.active.value],
      orderBy: 'expiry_date ASC',
      limit: limit,
      offset: skip,
    );
    return rows.map(_fromRow).toList();
  }

  /// Items activos cuya fecha de vencimiento cae dentro de [days] desde hoy.
  Future<List<InventoryItem>> getExpiringWithinDays(int days) async {
    final now = DateTime.now();
    final cutoff = DateTime(now.year, now.month, now.day)
        .add(Duration(days: days));
    final cutoffStr = _dateOnly(cutoff);
    final rows = await _required.query(
      _table,
      where: 'status = ? AND expiry_date <= ?',
      whereArgs: [ItemStatus.active.value, cutoffStr],
      orderBy: 'expiry_date ASC',
    );
    return rows.map(_fromRow).toList();
  }

  /// Reemplazo total atómico. Útil para refrescar la cache con la respuesta
  /// completa del backend.
  Future<void> replaceAll(List<InventoryItem> items) async {
    final db = _required;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.transaction((txn) async {
      await txn.delete(_table);
      final batch = txn.batch();
      for (final item in items) {
        batch.insert(_table, _toRow(item, syncedAt: now));
      }
      await batch.commit(noResult: true);
    });
  }

  /// Inserta o actualiza un item. Útil tras una mutación exitosa.
  Future<void> upsert(InventoryItem item) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _required.insert(
      _table,
      _toRow(item, syncedAt: now),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteById(String id) async {
    await _required.delete(_table, where: 'id = ?', whereArgs: [id]);
  }

  /// Borra todo el contenido. Llamar en logout para no filtrar inventario
  /// entre cuentas.
  Future<void> clear() async {
    if (_db == null) return;
    try {
      await _required.delete(_table);
    } catch (e) {
      debugPrint('[InventoryLocalDb] clear failed: $e');
    }
  }

  // -- Mapping helpers --------------------------------------------------------

  Map<String, Object?> _toRow(InventoryItem item, {required int syncedAt}) {
    return {
      'id': item.id,
      'name': item.name,
      'category': item.category.value,
      'quantity': item.quantity,
      'unit': item.unit,
      'unit_price': item.unitPrice,
      'purchase_date': _dateOnly(item.purchaseDate),
      'expiry_date': _dateOnly(item.expiryDate),
      'status': item.status.value,
      'notes': item.notes,
      'created_at': item.createdAt.toIso8601String(),
      'synced_at': syncedAt,
    };
  }

  InventoryItem _fromRow(Map<String, Object?> row) {
    return InventoryItem(
      id: row['id'] as String,
      name: row['name'] as String,
      category: ItemCategory.fromString(row['category'] as String),
      quantity: (row['quantity'] as num).toDouble(),
      unit: row['unit'] as String?,
      unitPrice: row['unit_price'] != null
          ? (row['unit_price'] as num).toDouble()
          : null,
      purchaseDate: DateTime.parse(row['purchase_date'] as String),
      expiryDate: DateTime.parse(row['expiry_date'] as String),
      status: ItemStatus.fromString(row['status'] as String),
      notes: row['notes'] as String?,
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }

  String _dateOnly(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
