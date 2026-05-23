# Shopping List — Architectural Strategies

The Smart Shopping List feature (Sprint 3) implements two of the strategies
required by the assignment:

* **(d) Eventual connectivity** — every mutation works fully offline and is
  synchronized to the backend (AWS) when connectivity returns.
* **(c) Caching** — the suggestion engine memoizes results with a TTL and
  content-based invalidation to avoid redundant computation on every
  `notifyListeners()`.

---

## 1. Eventual connectivity

### Data flow

```
   UI action (add/toggle/remove/clear)
              │
              ▼
   ShoppingListProvider          ◄── single source of truth in memory
              │
              ▼
   LocalShoppingListService      ◄── DAO over SQLite (local-first write)
              │
              ▼
   pending_operations table      ◄── offline queue
              │
              ▼
   ConnectivityProvider._syncAll ◄── flushes the queue when the device
              │                       is online (debounced)
              ▼
   Backend (AWS FastAPI)
```

### Design points

* **Local-first writes**: every mutation (`addManual`, `addFromSuggestion`,
  `togglePurchased`, `remove`, `clearPurchased`) is persisted to SQLite
  *before* the UI is notified. The user never has to wait for the network.
* **Offline queue**: `LocalShoppingListService.enqueuePendingOperation`
  inserts an `(operation, item_id, payload, created_at)` row in the
  `pending_operations` table. The queue is durable across app restarts.
* **Replay on reconnect**: `ConnectivityProvider` listens to
  `connectivity_plus`. When it transitions from offline → online it calls
  `_syncAll()`, which drains the queue against the shopping-list backend
  endpoints (`POST /shopping-list`, `PUT /shopping-list/{id}`,
  `DELETE /shopping-list/{id}`).
* **Idempotency**: each pending op carries the local item id, which is also
  the primary key on the backend. The backend implements an upsert so
  re-sending the same op is safe (important when the device loses
  connectivity mid-flush).

### What survives an offline session

| Action | Local? | Queued for backend? |
|---|---|---|
| Add manual item | ✅ | ✅ `create` |
| Add from suggestion | ✅ | ✅ `create` |
| Toggle purchased | ✅ | ✅ `update` |
| Remove item | ✅ | ✅ `delete` |
| Clear purchased (bulk) | ✅ | ✅ N × `delete` |

---

## 2. Caching

The suggestion engine (`ShoppingSuggestionsService`) is the most expensive
piece of the feature: on every refresh it iterates the active inventory, the
list of recently consumed items, the ingredients of every nearby recipe, and
performs deduplication against the current shopping list.

In the real flow `refreshSuggestions` is invoked **multiple times per minute**
(when the screen opens, when the provider rebuilds, when the user returns
from the background, after every inventory mutation). Most of those calls
have **identical inputs** and therefore produce the same output — a textbook
case for a memoization cache.

### Cache contract

| Aspect | Decision |
|---|---|
| Storage | In-memory inside `ShoppingSuggestionsService` (singleton per provider) |
| Scope | One entry (the last computed result) — sugestions are a derived view, not a dataset |
| Eviction | TTL: 5 minutes (`defaultTtl`, configurable via constructor) |
| Content-based invalidation | Hash over `(inventory ids + quantities, recently consumed ids + names, recipe ids, current list ids + purchased flag)` |
| Explicit invalidation | `invalidateCache()` called from the provider on every mutation |
| Observability | `cacheHits` / `cacheMisses` counters exposed for the viva-voce demo |

### Lookup algorithm

```
1. Compute hash H of all input collections.
2. If cache != null AND not expired AND cache.hash == H:
       hits++ ; return cached suggestions
3. Else:
       misses++ ; recompute ; store entry with createdAt = now, hash = H
```

### Why this design (and not others)

| Alternative | Why we rejected it |
|---|---|
| Disk cache (SharedPreferences / SQLite row) | Suggestions are a derived view from data that already lives on disk. Persisting them would duplicate state and complicate invalidation. |
| Global cache across users | Suggestions depend on per-user inventory; cross-user reuse is impossible. |
| Pure `Map<Key, Result>` without TTL | Could grow unbounded if inputs change frequently; TTL gives an upper bound on staleness even if invalidation is missed. |
| Recomputing every time (no cache) | The whole motivation: the engine was being invoked on every rebuild even with identical inputs. |

### Interaction with eventual connectivity

The cache is **provider-local in memory**, so:

* It is naturally cleared on app restart (no stale state survives a cold
  start).
* It is invalidated by every mutation that goes into the offline queue,
  which guarantees that the suggestions shown to the user always reflect
  the latest local state, even before sync to the backend happens.

### Cache effectiveness (demo for viva-voce)

To verify the cache works as expected during the defense, the UI can read
`ShoppingSuggestionsService.cacheHits` / `cacheMisses` after a few typical
interactions:

| Scenario | Expected miss | Expected hits |
|---|---|---|
| Open the screen for the first time | 1 | 0 |
| Pull-to-refresh without any mutation | 0 | 1 |
| Reopen the screen within 5 minutes without mutations | 0 | 1 |
| Add an item to the list | 1 | 0 (cache invalidated) |
| Wait 5+ minutes and refresh | 1 | 0 (TTL expired) |

---

## 3. Files involved

| File | Role |
|---|---|
| `lib/features/shopping_list/services/shopping_suggestions_service.dart` | Hosts the cache (TTL + content hash + metrics) |
| `lib/features/shopping_list/providers/shopping_list_provider.dart` | Calls `invalidateCache()` on every mutation |
| `lib/features/shopping_list/services/local_shopping_list_service.dart` | SQLite DAO + `enqueuePendingOperation` for the offline queue |
| `lib/core/network/connectivity_provider.dart` | Triggers `_syncAll()` on reconnect |
| `lib/core/storage/app_database.dart` | Schema for `shopping_list_items` and `pending_operations` |

---

## 4. Mapping to the assignment rubric

| Requirement | Where it's implemented |
|---|---|
| **(d) Eventual connectivity** for every feature | Offline queue + `ConnectivityProvider._syncAll()` |
| **(c) Caching** for at least one feature | `ShoppingSuggestionsService` with TTL + content hash + explicit invalidation |
