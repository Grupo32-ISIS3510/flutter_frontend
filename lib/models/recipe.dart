import 'package:second_serving_frontend/models/enums.dart';

class RecipeIngredient {
  final String id;
  final String ingredientName;
  final double? quantity;
  final String? unit;

  const RecipeIngredient({
    required this.id,
    required this.ingredientName,
    this.quantity,
    this.unit,
  });

  factory RecipeIngredient.fromJson(Map<String, dynamic> json) {
    return RecipeIngredient(
      id: json['id'] as String,
      ingredientName: json['ingredient_name'] as String,
      quantity: json['quantity'] != null
          ? double.parse(json['quantity'].toString())
          : null,
      unit: json['unit'] as String?,
    );
  }
}

class RecipeSummary {
  final String id;
  final String name;
  final String? description;
  final RecipeCategory category;
  final int? prepTimeMinutes;
  final int servings;
  final String? imageUrl;
  final int inventoryMatches;

  const RecipeSummary({
    required this.id,
    required this.name,
    this.description,
    required this.category,
    this.prepTimeMinutes,
    required this.servings,
    this.imageUrl,
    required this.inventoryMatches,
  });

  factory RecipeSummary.fromJson(Map<String, dynamic> json) {
    return RecipeSummary(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      category: RecipeCategory.fromString(json['category'] as String? ?? 'lunch'),
      prepTimeMinutes: json['prep_time_minutes'] as int?,
      servings: json['servings'] as int? ?? 1,
      imageUrl: json['image_url'] as String?,
      inventoryMatches: json['inventory_matches'] as int? ?? 0,
    );
  }
}

class RecipeDetail {
  final String id;
  final String name;
  final String? description;
  final String instructions;
  final int? prepTimeMinutes;
  final int servings;
  final RecipeCategory category;
  final String? imageUrl;
  final List<RecipeIngredient> ingredients;
  final int inventoryMatches;
  final DateTime createdAt;

  const RecipeDetail({
    required this.id,
    required this.name,
    this.description,
    required this.instructions,
    this.prepTimeMinutes,
    required this.servings,
    required this.category,
    this.imageUrl,
    required this.ingredients,
    required this.inventoryMatches,
    required this.createdAt,
  });

  factory RecipeDetail.fromJson(Map<String, dynamic> json) {
    return RecipeDetail(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      instructions: json['instructions'] as String,
      prepTimeMinutes: json['prep_time_minutes'] as int?,
      servings: json['servings'] as int? ?? 1,
      category: RecipeCategory.fromString(json['category'] as String? ?? 'lunch'),
      imageUrl: json['image_url'] as String?,
      ingredients: (json['ingredients'] as List)
          .map((e) => RecipeIngredient.fromJson(e as Map<String, dynamic>))
          .toList(),
      inventoryMatches: json['inventory_matches'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class RecipeListResponse {
  final List<RecipeSummary> items;
  final int total;

  const RecipeListResponse({required this.items, required this.total});

  factory RecipeListResponse.fromJson(Map<String, dynamic> json) {
    return RecipeListResponse(
      items: (json['items'] as List)
          .map((e) => RecipeSummary.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: json['total'] as int,
    );
  }
}
