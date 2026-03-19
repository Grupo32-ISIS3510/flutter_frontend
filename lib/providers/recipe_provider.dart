import 'package:flutter/material.dart';
import 'package:second_serving_frontend/models/recipe.dart';
import 'package:second_serving_frontend/services/recipe_service.dart';

class RecipeProvider extends ChangeNotifier {
  final RecipeService _service;

  List<RecipeSummary> _suggestions = [];
  List<RecipeSummary> _recipes = [];
  RecipeDetail? _selectedRecipe;
  int _total = 0;
  bool _isLoading = false;
  String? _error;

  RecipeProvider(this._service);

  List<RecipeSummary> get suggestions => _suggestions;
  List<RecipeSummary> get recipes => _recipes;
  RecipeDetail? get selectedRecipe => _selectedRecipe;
  int get total => _total;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadSuggestions({int limit = 10}) async {
    _isLoading = true;
    notifyListeners();

    try {
      _suggestions = await _service.getSuggestions(limit: limit);
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
