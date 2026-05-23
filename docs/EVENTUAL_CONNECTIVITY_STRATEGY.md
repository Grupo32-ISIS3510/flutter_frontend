# 7. Eventual Connectivity Strategy

> Required: each functionality must have its corresponding eventual connectivity strategy.

## 7.1 Overview

Both features (OCR/Camera and Smart Recipes) implement connectivity-aware behavior so the app never shows blank screens, infinite spinners, or loses user data when the device is offline.

| Layer | Technology | Responsibility |
|-------|-----------|----------------|
| Detection | `connectivity_plus` → `ConnectivityService` (Singleton) | Real-time wifi/mobile/ethernet monitoring via `Stream<bool>` |
| Orchestration | `ConnectivityProvider` (ChangeNotifier / MVVM) | Listens for offline→online, triggers full sync pipeline |
| UI Feedback | `_OfflineBanner` in `HomeScreen` | Informs user of connectivity state without blocking interaction |

---

## 7.2 Feature 1 — OCR / Camera

- **Offline capability:** The entire scan pipeline runs **100% on-device** without any network call:
  - `CameraService` → device camera (no network)
  - `TextRecognitionService` → Google ML Kit on-device model (no network)
  - `ReceiptParserService` → Dart regex/heuristics (no network)

- **Saving items offline:**

| Step | Online | Offline |
|------|--------|---------|
| User confirms scanned items | `InventoryProvider.addItem()` → backend + SQLite | Backend call fails → operation enqueued in `pending_operations` (SQLite) |
| Sync on reconnect | N/A | `ConnectivityProvider` detects online → `syncPendingOperations()` replays FIFO queue |

- **Telemetry offline:**

| Service | Local storage | Flush on reconnect |
|---------|--------------|-------------------|
| `ScanTelemetryService` | SharedPreferences (`telemetry.scan_events`) | `flushPendingToBackend()` |
| `ExpiryTelemetryService` | SharedPreferences (`telemetry.expiry_accuracy`) | `flushToBackend()` |
| `ScreenAnalyticsService` | SharedPreferences (`telemetry.screen_events`) | `flushToBackend()` |

- **UI feedback (connectivity-aware):**
  - `InventoryProvider.addItem()` returns `'synced'` (backend OK) or `'queued'` (enqueued locally).
  - `ScannedItemsReviewScreen._saveAll()` shows different messages:
    - All synced → green: "3 productos agregados"
    - All queued → orange: "3 productos guardados localmente — se sincronizarán con conexión"
    - Mixed → orange: "2 sincronizados, 1 pendiente de sincronizar"
  - `AddItemScreen._save()` shows orange snackbar when item is queued offline.

- **Anti-patterns avoided:**
  - "Pantalla en blanco" → scan works entirely offline (on-device ML Kit)
  - "Pérdida de datos" → items enqueued in SQLite, persists across app restarts
  - "App bloqueada" → user continues using the app normally
  - "Error engañoso" → offline save shows informative message, not an error
  - "Conteo incorrecto" → queued items count as saved (they are — just locally)

### Evidence (OCR)
- Facade (on-device pipeline): `ReceiptScannerService.scan()` in `lib/features/inventory/services/receipt_scanner_service.dart`
- Offline queue: `LocalInventoryService.enqueuePendingOperation()` in `lib/features/inventory/services/local_inventory_service.dart`
- Connectivity-aware save: `InventoryProvider.addItem()` returns `'synced'` or `'queued'` in `lib/features/inventory/providers/inventory_provider.dart`
- Offline UI feedback: `ScannedItemsReviewScreen._saveAll()` in `lib/features/inventory/screens/scanned_items_review_screen.dart`
- Sync replay: `InventoryProvider.syncPendingOperations()` triggered by `ConnectivityProvider` on reconnect
- Telemetry local-first: `ScanTelemetryService._saveLocally()`, `ExpiryTelemetryService._saveLocally()`, `ScreenAnalyticsService._saveLocally()`

---

## 7.3 Feature 2 — Smart Recipes

- **Caching strategy:** "Cache then network" implemented in `RecipeProvider` using `LocalRecipeCacheService` (SharedPreferences).

| Method | Step 1 (cache) | Step 2 (network) | On network failure |
|--------|----------------|-------------------|-------------------|
| `loadSuggestions()` | Read cached suggestions → display instantly | Fetch from backend → update cache + UI | UI keeps showing cached data |
| `loadRecipes()` | Read cached recipe list → display instantly | Fetch from backend → update cache + UI | UI keeps showing cached data |
| `loadRecipeDetail(id)` | Read cached detail → display instantly | Fetch from backend → update cache + UI | UI keeps showing cached data |

- **Offline behavior (no mocks, only real data):**
  - With network: `RecipeServiceImpl` fetches from backend → `RecipeProvider` updates local cache + UI.
  - Without network: `RecipeProvider` reads from local cache (SharedPreferences) → user sees the real recipes they previously loaded.
  - If never loaded anything and no network: honest error message is shown — no fake/mock data is ever displayed to the user.

- **Cached entities:**

| Key | Contents |
|-----|----------|
| `cache.recipe_suggestions` | `List<RecipeSummary>` as JSON StringList |
| `cache.recipe_list` | `List<RecipeSummary>` as JSON StringList + total count |
| `cache.recipe_detail.<id>` | `RecipeDetail` as JSON String (per recipe) |

- **Anti-patterns avoided:**
  - "Pantalla en blanco" → cached real data displayed when offline
  - "Spinner infinito" → cached data displayed before network call completes
  - "Contenido perdido" → recipes persist in SharedPreferences across sessions
  - "Datos falsos" → no mock/hardcoded data shown in production; only real backend data or cached real data

### Evidence (Recipes)
- Cache service: `LocalRecipeCacheService` in `lib/features/recipes/services/local_recipe_cache_service.dart`
- Cache-then-network: `RecipeProvider.loadSuggestions()`, `loadRecipes()`, `loadRecipeDetail()` in `lib/features/recipes/providers/recipe_provider.dart`
- Backend service (direct, no mock fallback): `RecipeServiceImpl` in `lib/features/recipes/services/recipe_service.dart`
- Model serialization: `toJson()` / `fromJson()` on `RecipeSummary`, `RecipeDetail`, `RecipeIngredient` in `lib/features/recipes/models/recipe.dart`

---

## 7.4 Shared Infrastructure

- **ConnectivityService** (`lib/core/network/connectivity_service.dart`): Singleton, `connectivity_plus`, emits `Stream<bool>`.
- **ConnectivityProvider** (`lib/core/network/connectivity_provider.dart`): on offline→online triggers:
  1. `syncPendingOperations()` — replay inventory CRUD queue
  2. `flushPendingToBackend()` / `flushToBackend()` — batch telemetry push
  3. `loadItems()` — refresh inventory with fresh backend data
- **_OfflineBanner** (`lib/features/home/screens/home_screen.dart`):
  - Offline → grey bar: "Sin conexión — los cambios se guardarán localmente"
  - Syncing → orange bar: "Reconectado — sincronizando cambios..."
  - Online → banner hidden
- **DI registration**: `ConnectivityProvider` in `MultiProvider` in `main.dart`.
