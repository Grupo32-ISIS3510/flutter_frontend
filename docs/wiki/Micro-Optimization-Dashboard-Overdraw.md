# Micro-optimization: Dashboard Overdraw Reduction

## 1. Context

During Sprint 3 we ran a performance audit on the Flutter frontend using the class notes on **Performance Pitfalls of Frontends (PPoF)** as a checklist. The audit was focused on the `DashboardScreen`, which is the most visited screen in the app and the one with the heaviest visual hierarchy (stats card, recipe-of-the-day card, expiring-items carousel, shopping-list shortcut, etc.).

The goal of the exercise was **not** to "make it faster" blindly, but to follow the methodology taught in class:

1. **Measure first** (Flutter DevTools, profile mode).
2. **Identify the real pitfall** (build vs paint vs raster).
3. **Apply a targeted micro-optimization**.
4. **Measure again** and compare.

## 2. Diagnosis (BEFORE)

App launched with `flutter run --profile` and inspected with Flutter DevTools → Performance tab.

### Evidence captured

| Indicator | Value |
|---|---|
| Average FPS | **52 FPS** |
| Build phase | 7.9 ms |
| Paint phase | **16.1 ms** |
| Raster phase | **19.9 ms** |
| DevTools warnings | `UI Jank Detected` + `Raster Jank Detected` |
| Rebuild Stats (selected frame) | `0` for every widget |

### Interpretation

- The **Build phase was not the bottleneck** → excessive rebuilds (PPoF #1) was **discarded** as the root cause.
- The bottleneck was clearly on the **paint/raster side**, which points directly to **PPoF #4: Overdraw** — the GPU is repainting too many overlapping opaque layers per frame.

### Code smell found

The dashboard used the same anti-pattern repeated in 4 places:

```dart
Container(
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.06),
        blurRadius: 16,
        offset: const Offset(0, 4),
      ),
    ],
  ),
  child: ...,
)
```

Each `BoxShadow` with `blurRadius` forces the GPU to perform a `saveLayer` + Gaussian blur, which is expensive and scales with the painted area. With several of these stacked on top of a gradient background and a `RefreshIndicator`, the raster thread was missing the 16 ms budget per frame.

## 3. Micro-optimization applied

All changes were made in `lib/features/home/screens/dashboard_screen.dart`.

| # | Location | Before | After | Rationale |
|---|---|---|---|---|
| 1 | `_buildStatsCard` (savings / CO₂ card) | `Container + BoxDecoration + boxShadow blur:16` | `Material + elevation:2` | Native compositor shadows instead of GPU blur |
| 2 | `_ExpiringItemCard` (× N items in carousel) | `Container + BoxDecoration + boxShadow blur:10` | `RepaintBoundary` + `Material + elevation:2` + `DecoratedBox` for the badge | Isolate repaint per card + cheaper shadow + flatter hierarchy |
| 3 | "Plan de hoy" recipe card | `Container + BoxDecoration + boxShadow blur:12` | `Material + elevation:2` | Same rationale as #1 |
| 4 | Empty-state container ("No hay plan") | `Container + BoxDecoration` (redundant) | Plain `Material` | Remove a redundant render layer |

### Why this works (techniques from class)

- **Material elevation** uses native Skia shadow primitives instead of a `saveLayer` + Gaussian blur → much cheaper for the GPU.
- **`RepaintBoundary`** isolates each card in its own layer: scrolling or animating one card does not invalidate the others.
- **`DecoratedBox + Padding`** instead of `Container` removes one `RenderObject` from the tree → flatter hierarchy, shorter layout/paint walk.

### Example diff (representative)

```dart
// BEFORE
Container(
  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(20),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.06),
        blurRadius: 16,
        offset: const Offset(0, 4),
      ),
    ],
  ),
  child: Row(...),
)

// AFTER
Material(
  color: Colors.white,
  elevation: 2,
  shadowColor: Colors.black.withValues(alpha: 0.12),
  borderRadius: BorderRadius.circular(20),
  child: Padding(
    padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
    child: Row(...),
  ),
)
```

## 4. Results (AFTER)

Same device, same scenario (scroll up/down on the dashboard for ~3 seconds), same DevTools setup.

| Metric | BEFORE | AFTER | Δ |
|---|---|---|---|
| Average FPS | 52 | **57** | **+9.6 %** |
| Build phase | 7.9 ms | **1.4 ms** | **−82 %** |
| Paint + Raster | 16.1 + 19.9 ms | **20.2 ms** (combined) | **≈ −44 %** |
| `UI Jank Detected` | Yes | **No** | Removed |
| `Raster Jank Detected` | Yes | Yes (reduced) | Partially resolved |
| `_ExpiringItemCard` rebuilds on selected frame | n/a | **0 / 24 instances** | `RepaintBoundary` working |

## 5. Honest conclusions

- The micro-optimization **achieved a measurable improvement** with a minimal, surgical change (only one file touched).
- The **UI thread bottleneck disappeared** (UI Jank gone, Build down 82 %).
- A **residual Raster Jank** remains, caused by other overdraw sources we deliberately left out of scope (background gradient, `RefreshIndicator`, image layers). This confirms the lesson from class: *micro-optimizations have a real but bounded impact; always measure before and after, and keep iterating only where the data justifies it*.

## 6. PPoF checklist mapping

| Pitfall (class notes) | Status in this exercise |
|---|---|
| #1 Excessive rebuilds | Discarded by Rebuild Stats evidence |
| #2 Heavy `build()` methods | Not relevant (build = 1.4 ms after) |
| #3 Object allocation in hot paths | Already addressed with `const` constructors |
| **#4 Overdraw** | **Root cause — fixed in this PR** |
| #5 Large lists without recycling | Already using `ListView.builder` |
