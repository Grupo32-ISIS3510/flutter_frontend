import 'package:second_serving_frontend/core/config/api_config.dart';
import 'package:second_serving_frontend/features/recipes/models/recipe.dart';
import 'package:second_serving_frontend/core/network/api_client.dart';

abstract class RecipeService {
  Future<List<RecipeSummary>> getSuggestions({int limit = 10});
  Future<RecipeListResponse> getRecipes({int skip = 0, int limit = 20});
  Future<RecipeDetail> getRecipeDetail(String id);
  Future<void> interact(String id, String action);

  /// BQ T3.6 — marca la receta como favorita en el backend.
  /// Idempotente: el backend acepta múltiples llamadas con el mismo id.
  Future<void> addFavorite(String id);

  /// BQ T3.6 — desmarca la receta como favorita en el backend.
  Future<void> removeFavorite(String id);
}

class RecipeServiceImpl implements RecipeService {
  final ApiClient _client;

  RecipeServiceImpl(this._client);

  @override
  Future<List<RecipeSummary>> getSuggestions({int limit = 10}) async {
    final response = await _client.get(
      ApiConfig.recipeSuggestions,
      queryParams: {'limit': '$limit'},
    );
    final list = response['data'] as List? ?? [];
    return list.map((e) => RecipeSummary.fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<RecipeListResponse> getRecipes({int skip = 0, int limit = 20}) async {
    final response = await _client.get(
      ApiConfig.recipes,
      queryParams: {'skip': '$skip', 'limit': '$limit'},
    );
    return RecipeListResponse.fromJson(response);
  }

  @override
  Future<RecipeDetail> getRecipeDetail(String id) async {
    final response = await _client.get(ApiConfig.recipeDetail(id));
    return RecipeDetail.fromJson(response);
  }

  @override
  Future<void> interact(String id, String action) async {
    await _client.post(ApiConfig.recipeInteract(id), body: {'action': action});
  }

  @override
  Future<void> addFavorite(String id) async {
    await _client.post(ApiConfig.recipeFavorite(id), body: {});
  }

  @override
  Future<void> removeFavorite(String id) async {
    await _client.delete(ApiConfig.recipeFavorite(id));
  }
}
