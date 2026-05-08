# 6. Local Storage Strategy

> Required: at least 1 strategy per mobile app.

## 6.2 Flutter

- **Storage tech:** SQLite via `sqflite` (equivalent to Room on Android) for structured inventory data. `SharedPreferences` for lightweight key-value persistence covering telemetry events, weather caching, and notification deduplication. `flutter_secure_storage` (AES on Android, Keychain on iOS) for sensitive session tokens.

- **Stored entities:**

| Store | Technology | Contents |
|-------|-----------|----------|
| `second_serving_database` | SQLite (`sqflite`) | `InventoryItem`: id, name, category, quantity, unit, unit_price, purchase_date, expiry_date, status, days_remaining, notes, created_at, synced |
| `pending_operations` | SQLite (`sqflite`) | id, operation, table_name, item_id, payload (JSON), created_at |
| `telemetry.scan_events` | SharedPreferences | List of JSON-encoded `ScanEvent`: timestamp, success, failure_reason, products_detected, duration_ms |
| `telemetry.expiry_accuracy` | SharedPreferences | List of JSON-encoded `ExpiryAccuracyEvent`: timestamp, category, ocr_detected_date, ocr_date, user_confirmed_date, accurate |
| `telemetry.screen_events` | SharedPreferences | List of JSON-encoded `ScreenEvent`: timestamp, screen_name, event_type, exit_reason, dwell_time_ms |
| `contextAware.weatherSnapshot` | SharedPreferences | cache_data (full JSON `WeatherSnapshot`), fetchedAt (TTL = 1 hour) |
| `auth_token` | flutter_secure_storage | JWT access_token (AES-encrypted on Android, Keychain on iOS) |

- **Persistence policy:**
  - SQLite data persists across app restarts and process death. It is the single source of truth for inventory state on the Flutter client.
  - `LocalInventoryService` exposes query methods filtered by status (`active`), expiry date range, and individual item lookup by ID.
  - Available query filters: by expiry status (expiring within N days), by active status, and by item ID.
  - SharedPreferences entries for telemetry are append-only lists that are flushed to the backend via `flushToBackend()` / `flushPendingToBackend()` methods.
  - `WeatherCacheService` validates entries at read time against a 1-hour TTL (`_validFor = Duration(hours: 1)`). Stale entries are ignored and overwritten on the next successful network response.
  - All SharedPreferences writes use async operations internally (equivalent to `apply()` on Android), ensuring the main thread is never blocked.

- **Sync integration:**
  - `InventoryProvider` keeps SQLite and the backend in sync by executing `upsertAll(response.items)` on every successful network response, replacing stale local data with fresh server data.
  - When a write operation (create, update, consume, discard, delete) fails due to network unavailability, it is enqueued in the `pending_operations` table with its full payload.
  - `syncPendingOperations()` iterates the queue in FIFO order, replaying each operation against the backend and removing it from the queue on success.
  - Every telemetry service (`ScanTelemetryService`, `ExpiryTelemetryService`, `ScreenAnalyticsService`) follows the same pattern: save locally first, attempt backend push, and expose a `flushToBackend()` method for batch retry.
  - `RecipeServiceWithFallback` implements "Network falling back to cache" — attempts the real backend first; on failure or empty response, falls back to mock data, ensuring the UI never shows blank content.

## 6.3 Evidence

- Flutter SQLite schema: `AppDatabase` (`lib/core/storage/app_database.dart`) with `openDatabase()`, version 1, two tables (`inventory_items` with 13 columns + 2 indexes, `pending_operations` with 5 columns).
- Flutter SQLite DAO: `LocalInventoryService` (`lib/features/inventory/services/local_inventory_service.dart`) with full CRUD operations, batch upsert, expiring items query, and offline queue management.
- Flutter SharedPreferences: keys and TTL logic verified in `ScanTelemetryService`, `ExpiryTelemetryService`, `ScreenAnalyticsService`, and `WeatherCacheService`.
- Flutter secure storage: token persistence in `AuthProvider` via `flutter_secure_storage`.
- Flutter InventoryProvider: "Cache then network" strategy implemented in `loadItems()` and `loadExpiringItems()` (`lib/features/inventory/providers/inventory_provider.dart`).
