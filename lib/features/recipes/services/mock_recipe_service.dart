import 'package:second_serving_frontend/features/recipes/models/recipe.dart';
import 'package:second_serving_frontend/shared/services/mock_data.dart';
import 'package:second_serving_frontend/features/recipes/services/recipe_service.dart';

class MockRecipeService implements RecipeService {
  @override
  Future<List<RecipeSummary>> getSuggestions({int limit = 10}) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return MockData.recipeSummaries.take(limit).toList();
  }

  @override
  Future<RecipeListResponse> getRecipes({int skip = 0, int limit = 20}) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final page = MockData.recipeSummaries.skip(skip).take(limit).toList();
    return RecipeListResponse(items: page, total: MockData.recipeSummaries.length);
  }

  @override
  Future<RecipeDetail> getRecipeDetail(String id) async {
    await Future.delayed(const Duration(milliseconds: 400));
    return MockData.recipeDetails[id] ?? MockData.recipeDetails.values.first;
  }

  @override
  Future<void> interact(String id, String action) async {
    await Future.delayed(const Duration(milliseconds: 300));
  }
}
