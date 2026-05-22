import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Singleton que gestiona la base de datos SQLite local.
/// Alineado con la estrategia de almacenamiento local para datos
/// estructurados (inventario) que requieren persistencia entre sesiones.
class AppDatabase {
  static const String _dbName = 'second_serving.db';
  static const int _dbVersion = 2;

  static Database? _database;

  static Future<Database> get instance async {
    _database ??= await _initDatabase();
    return _database!;
  }

  static Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE inventory_items (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        category TEXT NOT NULL,
        quantity REAL NOT NULL DEFAULT 1,
        unit TEXT,
        unit_price REAL,
        purchase_date TEXT NOT NULL,
        expiry_date TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'active',
        days_remaining INTEGER NOT NULL DEFAULT 0,
        notes TEXT,
        created_at TEXT NOT NULL,
        synced INTEGER NOT NULL DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_inventory_status ON inventory_items(status)
    ''');
    await db.execute('''
      CREATE INDEX idx_inventory_expiry ON inventory_items(expiry_date)
    ''');

    await db.execute('''
      CREATE TABLE pending_operations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        operation TEXT NOT NULL,
        table_name TEXT NOT NULL,
        item_id TEXT,
        payload TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    await _createShoppingListTable(db);
  }

  static Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createShoppingListTable(db);
    }
  }

  static Future<void> _createShoppingListTable(Database db) async {
    await db.execute('''
      CREATE TABLE shopping_list_items (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        category TEXT NOT NULL,
        quantity REAL NOT NULL DEFAULT 1,
        unit TEXT,
        purchased INTEGER NOT NULL DEFAULT 0,
        source TEXT NOT NULL DEFAULT 'manual',
        source_ref TEXT,
        created_at TEXT NOT NULL,
        synced INTEGER NOT NULL DEFAULT 1
      )
    ''');
    await db.execute('''
      CREATE INDEX idx_shopping_purchased ON shopping_list_items(purchased)
    ''');
  }

  static Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}
