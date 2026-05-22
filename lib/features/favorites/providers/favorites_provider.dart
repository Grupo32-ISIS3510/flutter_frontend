import 'package:flutter/material.dart';
import 'package:second_serving_frontend/features/favorites/data/favorites_local_db.dart';
import 'package:second_serving_frontend/features/favorites/models/favorite_recipe.dart';
import 'package:second_serving_frontend/shared/models/enums.dart';

/// ViewModel del feature de Recetas Favoritas (patrón MVVM).
///
/// Actúa como Subject del patrón Observer (vía [ChangeNotifier]): las vistas
/// que hacen `context.watch<FavoritesProvider>()` son los Observers y se
/// repintan cuando cambia la lista de favoritos.
///
/// Toda la fuente de verdad vive en SQLite local ([FavoritesLocalDb]):
///   - Mantiene un `Set<String>` de IDs en memoria para lookups O(1) desde los
///     botones de corazón (sin pegarle a la DB en cada `build`).
///   - Cada mutación escribe primero en disco y luego refresca el estado.
class FavoritesProvider extends ChangeNotifier {
  final FavoritesLocalDb _db;

  FavoritesProvider({FavoritesLocalDb? db})
      : _db = db ?? FavoritesLocalDb.instance;

  List<FavoriteRecipe> _favorites = [];
  Set<String> _favoriteIds = <String>{};
  Map<String, int> _categoryDistribution = <String, int>{};
  bool _isLoading = false;

  List<FavoriteRecipe> get favorites => _favorites;
  bool get isLoading => _isLoading;
  bool get isEmpty => _favorites.isEmpty;
  int get count => _favorites.length;

  /// BQ — Distribución de favoritos por categoría, ordenada de mayor a menor.
  /// Lista de (categoría, conteo) lista para pintar en la vista.
  List<MapEntry<RecipeCategory, int>> get categoryBreakdown {
    final entries = _categoryDistribution.entries
        .map((e) => MapEntry(RecipeCategory.fromString(e.key), e.value))
        .toList();
    entries.sort((a, b) => b.value.compareTo(a.value));
    return entries;
  }

  /// Categoría favorita dominante (respuesta directa a la BQ), o null si no hay.
  RecipeCategory? get topCategory =>
      categoryBreakdown.isEmpty ? null : categoryBreakdown.first.key;

  bool isFavorite(String id) => _favoriteIds.contains(id);

  /// Carga favoritos + distribución desde SQLite. Llamar al entrar a la vista
  /// o tras autenticarse.
  Future<void> load() async {
    _isLoading = true;
    notifyListeners();
    try {
      _favorites = await _db.getAll();
      _favoriteIds = _favorites.map((f) => f.id).toSet();
      _categoryDistribution = await _db.categoryDistribution();
    } catch (e) {
      debugPrint('[FavoritesProvider] load failed: $e');
    }
    _isLoading = false;
    notifyListeners();
  }

  /// Alterna el estado de favorito de una receta y persiste en disco.
  /// Devuelve el nuevo estado (true = quedó como favorita).
  Future<bool> toggle(FavoriteRecipe recipe) async {
    final wasFavorite = _favoriteIds.contains(recipe.id);
    if (wasFavorite) {
      await _db.remove(recipe.id);
    } else {
      await _db.add(recipe);
    }
    await load();
    return !wasFavorite;
  }

  /// Quita un favorito por id (usado desde la lista, p. ej. swipe/botón).
  Future<void> remove(String id) async {
    await _db.remove(id);
    await load();
  }

  /// Limpia el estado en memoria (p. ej. tras logout, después de borrar la DB).
  void reset() {
    _favorites = [];
    _favoriteIds = <String>{};
    _categoryDistribution = <String, int>{};
    notifyListeners();
  }
}
