import 'package:second_serving_frontend/core/config/api_config.dart';
import 'package:second_serving_frontend/features/recipes/models/recipe.dart';
import 'package:second_serving_frontend/core/network/api_client.dart';

abstract class RecipeService {
  Future<List<RecipeSummary>> getSuggestions({int limit = 10});
  Future<RecipeListResponse> getRecipes({int skip = 0, int limit = 20});
  Future<RecipeDetail> getRecipeDetail(String id);
  Future<void> interact(String id, String action);
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
}
