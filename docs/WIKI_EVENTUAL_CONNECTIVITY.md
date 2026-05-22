## 4.1 Scenarios Managed — Flutter

- Offline while browsing or loading recipe suggestions
- Offline while browsing inventory items on the home screen
- Network failure when saving scanned items from OCR (camera receipt scan)
- Network failure when manually creating an inventory item
- Network failure when recording telemetry events (scan, expiry accuracy, screen analytics)
- Reconnection with automatic re-sync triggered by `ConnectivityProvider`

## 4.2 Strategy Design — Flutter

- **Local-first reads:** `InventoryProvider.loadItems()` always queries local SQLite via `LocalInventoryService` first. `RecipeProvider.loadSuggestions()` reads from `LocalRecipeCacheService` (SharedPreferences) first. A network call is issued immediately after; if it succeeds, the local store and UI are updated. If it fails, the UI keeps showing cached data — the user never sees an empty screen.

- **Write-through on connectivity:** `InventoryProvider.addItem()` calls the backend first, then persists the returned object to SQLite via `LocalInventoryService.upsertItem()`. If the backend is unreachable, the operation is enqueued in the `pending_operations` table (SQLite) and the UI shows an orange snackbar: "Guardado localmente — se sincronizará cuando haya conexión". Returns `'synced'` or `'queued'` so the UI can distinguish both cases.

- **Retry policy via ConnectivityProvider:** `ConnectivityService` (Singleton, `connectivity_plus`) emits a `Stream<bool>` on every network change. `ConnectivityProvider` listens to this stream; on any offline→online transition, it automatically executes `syncPendingOperations()` (FIFO replay from SQLite), `flushToBackend()` on all telemetry services, and `loadItems()` to refresh with backend data.

- **Conflict resolution — Last-Write-Wins:** On a successful network sync, `InventoryProvider` executes `upsertAll(response.items)` on the local SQLite database, replacing stale local data with the authoritative backend state.

- **User feedback states:** `ConnectivityProvider` exposes `isOnline` and `isSyncing` to the UI. `_OfflineBanner` in `HomeScreen` shows a grey bar ("Sin conexión — los cambios se guardarán localmente") when offline, an orange bar with spinner ("Reconectado — sincronizando cambios...") when syncing, and disappears when online. `ScannedItemsReviewScreen` and `AddItemScreen` show context-aware snackbar messages distinguishing synced vs. queued items.

## 4.3 Behavior per Scenario

| Scenario | Expected App Behavior | Flutter Evidence |
|----------|----------------------|-----------------|
| Offline — read inventory | Last cached items are shown from SQLite; no empty screen, no crash | `InventoryProvider.loadItems()` reads from `LocalInventoryService.getAllItems()` inside the first `try` block; if network fails, `_items` retains local data |
| Offline — read recipes | Last cached suggestions shown from SharedPreferences; only recipes with `inventoryMatches > 0` displayed | `RecipeProvider.loadSuggestions()` reads from `LocalRecipeCacheService.getCachedSuggestions()` first; filters by `inventoryMatches > 0` |
| Offline — save scanned items (OCR) | Items enqueued locally; orange snackbar informs user | `InventoryProvider.addItem()` catches network exception, calls `LocalInventoryService.enqueuePendingOperation()`, returns `'queued'`; `ScannedItemsReviewScreen` shows "guardados localmente — se sincronizarán con conexión" |
| Offline — create item manually | Item enqueued locally; orange snackbar informs user | `AddItemScreen._save()` checks return value `'queued'` and shows orange SnackBar: "Guardado localmente — se sincronizará cuando haya conexión" |
| Offline — telemetry recording | Events saved to SharedPreferences, backend push fails silently | `ScanTelemetryService._saveLocally()`, `ExpiryTelemetryService._saveLocally()`, `ScreenAnalyticsService._saveLocally()` always persist first; `_tryPushToBackend()` catches exceptions silently |
| Reconnect | Automatic sync: pending CRUD replayed, telemetry flushed, inventory refreshed | `ConnectivityProvider._syncAll()` calls `syncPendingOperations()`, then `Future.wait([flushPendingToBackend(), flushToBackend(), flushToBackend()])`, then `loadItems()` |
| Permanent failure | Cached data remains visible; error message only if no cache exists | `RecipeProvider`: `_error` is set only `if (_suggestions.isEmpty)`; `InventoryProvider`: `_error` set only `if (_items.isEmpty)` — otherwise UI shows cached data |
