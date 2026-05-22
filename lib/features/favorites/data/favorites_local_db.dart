import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:second_serving_frontend/features/favorites/models/favorite_recipe.dart';
import 'package:sqflite/sqflite.dart';

/// ═══════════════════════════════════════════════════════════════════
/// ESTRATEGIA DE ALMACENAMIENTO LOCAL — Recetas favoritas
/// ═══════════════════════════════════════════════════════════════════
///
/// Tier 2 (SQLite vía sqflite) — datos estructurados que deben persistir
/// entre sesiones y consultarse con filtros/agregaciones.
///
/// Esta tabla es 100% local: las favoritas son una señal de preferencia del
/// usuario que no depende del backend, por lo que la feature funciona
/// completa sin conexión (estrategia de conectividad eventual = local-only).
///
/// Equivalente nativo: Room (Android), CoreData (iOS).
///
/// Se accede como singleton: [FavoritesLocalDb.instance]. Llamar [initialize]
/// una vez en `main()` antes de usarlo.
class FavoritesLocalDb {
  FavoritesLocalDb._();
  static final FavoritesLocalDb instance = FavoritesLocalDb._();

  static const _dbName = 'favorites.db';
  static const _table = 'favorite_recipes';
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
            prep_time_minutes INTEGER,
            servings INTEGER NOT NULL DEFAULT 1,
            image_url TEXT,
            inventory_matches INTEGER NOT NULL DEFAULT 0,
            saved_at INTEGER NOT NULL
          )
        ''');
        // Índice para la BQ: agregación por categoría.
        await db.execute('CREATE INDEX idx_fav_category ON $_table(category)');
      },
    );
  }

  Database get _required {
    final db = _db;
    if (db == null) {
      throw StateError(
          'FavoritesLocalDb no inicializada. Llama a initialize() primero.');
    }
    return db;
  }

  /// Todos los favoritos, más recientes primero.
  Future<List<FavoriteRecipe>> getAll() async {
    final rows = await _required.query(_table, orderBy: 'saved_at DESC');
    return rows.map(FavoriteRecipe.fromRow).toList();
  }

  /// IDs de las recetas favoritas (para lookups O(1) en la UI).
  Future<Set<String>> getFavoriteIds() async {
    final rows = await _required.query(_table, columns: ['id']);
    return rows.map((r) => r['id'] as String).toSet();
  }

  Future<bool> isFavorite(String id) async {
    final rows = await _required.query(
      _table,
      columns: ['id'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  /// Inserta o reemplaza un favorito.
  Future<void> add(FavoriteRecipe favorite) async {
    await _required.insert(
      _table,
      favorite.toRow(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> remove(String id) async {
    await _required.delete(_table, where: 'id = ?', whereArgs: [id]);
  }

  /// BQ — Distribución de favoritos por categoría de receta.
  /// Devuelve { 'breakfast': 3, 'lunch': 5, ... } resuelto en SQL con GROUP BY.
  Future<Map<String, int>> categoryDistribution() async {
    final rows = await _required.rawQuery('''
      SELECT category, COUNT(*) AS total
      FROM $_table
      GROUP BY category
      ORDER BY total DESC
    ''');
    return {
      for (final row in rows) row['category'] as String: row['total'] as int,
    };
  }

  /// Borra todo. Llamar en logout para no filtrar favoritos entre cuentas.
  Future<void> clear() async {
    if (_db == null) return;
    try {
      await _required.delete(_table);
    } catch (e) {
      debugPrint('[FavoritesLocalDb] clear failed: $e');
    }
  }
}
