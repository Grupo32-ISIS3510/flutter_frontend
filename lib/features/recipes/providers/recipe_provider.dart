import 'package:flutter/material.dart';
import 'package:second_serving_frontend/features/recipes/models/recipe.dart';
import 'package:second_serving_frontend/features/recipes/services/recipe_service.dart';
import 'package:second_serving_frontend/features/recipes/strategies/recipe_sort_strategy.dart';

/// Context del patrón Strategy: mantiene una referencia a la estrategia
/// activa y la aplica cada vez que se cargan o reordenan las sugerencias.
/// También actúa como Subject del patrón Observer (vía ChangeNotifier):
/// los widgets que hacen context.watch<RecipeProvider>() son los Observers.
class RecipeProvider extends ChangeNotifier {
  final RecipeService _service;

  List<RecipeSummary> _rawSuggestions = [];
  List<RecipeSummary> _suggestions = [];
  List<RecipeSummary> _recipes = [];
  RecipeDetail? _selectedRecipe;
  int _total = 0;
  bool _isLoading = false;
  String? _error;

  /// Lista de estrategias disponibles para la UI
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

  Future<void> loadSuggestions({int limit = 10}) async {
    _isLoading = true;
    notifyListeners();

    try {
      _rawSuggestions = await _service.getSuggestions(limit: limit);
      _suggestions = _activeStrategy.sort(_rawSuggestions);
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadRecipes({int skip = 0, int limit = 20}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _service.getRecipes(skip: skip, limit: limit);
      _recipes = response.items;
      _total = response.total;
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadRecipeDetail(String id) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _selectedRecipe = await _service.getRecipeDetail(id);
    } catch (e) {
      _error = e.toString();
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
