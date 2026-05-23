import 'package:flutter/material.dart';
import 'package:second_serving_frontend/features/recipes/models/recipe.dart';
import 'package:second_serving_frontend/features/recipes/services/recipe_service.dart';
import 'package:second_serving_frontend/features/recipes/services/local_recipe_cache_service.dart';
import 'package:second_serving_frontend/features/recipes/strategies/recipe_sort_strategy.dart';

/// Context del patrón Strategy: mantiene una referencia a la estrategia
/// activa y la aplica cada vez que se cargan o reordenan las sugerencias.
/// También actúa como Subject del patrón Observer (vía ChangeNotifier):
/// los widgets que hacen `context.watch` del RecipeProvider son los Observers.
///
/// Estrategia de conectividad eventual para Recetas:
///   1. Muestra datos cacheados localmente (respuesta instantánea)
///   2. Intenta obtener datos frescos del backend
///   3. Si el backend responde → actualiza caché y UI
///   4. Si el backend falla → la UI sigue mostrando datos cacheados
class RecipeProvider extends ChangeNotifier {
  final RecipeService _service;
  final LocalRecipeCacheService _cache = LocalRecipeCacheService();

  List<RecipeSummary> _rawSuggestions = [];
  List<RecipeSummary> _suggestions = [];
  List<RecipeSummary> _recipes = [];
  RecipeDetail? _selectedRecipe;
  int _total = 0;
  bool _isLoading = false;
  String? _error;

  final List<RecipeSortStrategy> availableStrategies = [
    SortByIngredientMatch(),
    SortByQuickPrep(),
    SortByExpiringSoon(),
  ];

  late RecipeSortStrategy _activeStrategy;

  RecipeProvider(this._service) {
    _activeStrategy = availableStrategies.first;
  }

  List<RecipeSummary> get suggestions => _suggestions;
  List<RecipeSummary> get recipes => _recipes;
  RecipeDetail? get selectedRecipe => _selectedRecipe;
  int get total => _total;
  bool get isLoading => _isLoading;
  String? get error => _error;
  RecipeSortStrategy get activeStrategy => _activeStrategy;

  /// Cambia la estrategia de ordenamiento en tiempo de ejecución
  /// y reordena las sugerencias actuales sin volver a llamar al backend.
  void setStrategy(RecipeSortStrategy strategy) {
    _activeStrategy = strategy;
    _suggestions = _activeStrategy.sort(_rawSuggestions);
    notifyListeners();
  }

  /// Cache-then-network: muestra sugerencias cacheadas de inmediato,
  /// luego refresca desde el backend y actualiza el caché.
  Future<void> loadSuggestions({int limit = 10}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    // 1) Leer del caché local (instantáneo)
    try {
      final cached = await _cache.getCachedSuggestions();
      final relevant = cached.where((r) => r.inventoryMatches > 0).toList();
      if (relevant.isNotEmpty) {
        _rawSuggestions = relevant;
        _suggestions = _activeStrategy.sort(relevant);
        _isLoading = false;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[RecipeProvider] Local cache read failed: $e');
    }

    // 2) Intentar red → actualizar caché y UI
    try {
      final fresh = await _service.getSuggestions(limit: limit);
      await _cache.cacheSuggestions(fresh);
      final relevant = fresh.where((r) => r.inventoryMatches > 0).toList();
      _rawSuggestions = relevant;
      _suggestions = _activeStrategy.sort(relevant);
    } catch (e) {
      if (_suggestions.isEmpty) {
        _error = e.toString();
      }
      debugPrint('[RecipeProvider] Network suggestions failed (using cache): $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Cache-then-network para la lista completa de recetas.
  Future<void> loadRecipes({int skip = 0, int limit = 20}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    // 1) Leer del caché local
    try {
      final cached = await _cache.getCachedRecipes();
      if (cached != null && cached.items.isNotEmpty) {
        _recipes = cached.items;
        _total = cached.total;
        _isLoading = false;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[RecipeProvider] Local recipes cache read failed: $e');
    }

    // 2) Intentar red → actualizar caché y UI
    try {
      final response = await _service.getRecipes(skip: skip, limit: limit);
      _recipes = response.items;
      _total = response.total;
      await _cache.cacheRecipes(response);
    } catch (e) {
      if (_recipes.isEmpty) {
        _error = e.toString();
      }
      debugPrint('[RecipeProvider] Network recipes failed (using cache): $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Cache-then-network para el detalle de una receta individual.
  Future<void> loadRecipeDetail(String id) async {
    _isLoading = true;
    _error = null;
    // Limpiar el detalle anterior: si la nueva receta no está en caché y la red
    // falla (offline), evita mostrar por error la receta cargada previamente.
    _selectedRecipe = null;
    notifyListeners();

    // 1) Leer del caché local
    try {
      final cached = await _cache.getCachedDetail(id);
      if (cached != null) {
        _selectedRecipe = cached;
        _isLoading = false;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[RecipeProvider] Local detail cache read failed: $e');
    }

    // 2) Intentar red → actualizar caché y UI
    try {
      _selectedRecipe = await _service.getRecipeDetail(id);
      await _cache.cacheDetail(_selectedRecipe!);
    } catch (e) {
      if (_selectedRecipe == null) {
        _error = e.toString();
      }
      debugPrint('[RecipeProvider] Network detail failed (using cache): $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> markAsCooked(String id) async {
    try {
      await _service.interact(id, 'cooked');
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> markAsViewed(String id) async {
    try {
      await _service.interact(id, 'viewed');
    } catch (_) {}
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
