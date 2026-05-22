import 'package:second_serving_frontend/features/recipes/models/recipe.dart';
import 'package:second_serving_frontend/shared/models/enums.dart';

/// Modelo de una receta guardada como favorita por el usuario.
///
/// Persiste localmente (SQLite) los campos mínimos para renderizar la tarjeta
/// sin red, más `savedAt` (epoch ms) que permite ordenar por más reciente y
/// responder la BQ de distribución de categorías favoritas.
///
/// Se construye desde un [RecipeSummary] mediante [FavoriteRecipe.fromSummary]
/// y se serializa hacia/desde una fila de SQLite con [toRow]/[fromRow].
class FavoriteRecipe {
  final String id;
  final String name;
  final RecipeCategory category;
  final int? prepTimeMinutes;
  final int servings;
  final String? imageUrl;
  final int inventoryMatches;
  final DateTime savedAt;

  const FavoriteRecipe({
    required this.id,
    required this.name,
    required this.category,
    this.prepTimeMinutes,
    required this.servings,
    this.imageUrl,
    required this.inventoryMatches,
    required this.savedAt,
  });

  /// Crea un favorito a partir de una sugerencia/listado de recetas.
  factory FavoriteRecipe.fromSummary(RecipeSummary summary, {DateTime? savedAt}) {
    return FavoriteRecipe(
      id: summary.id,
      name: summary.name,
      category: summary.category,
      prepTimeMinutes: summary.prepTimeMinutes,
      servings: summary.servings,
      imageUrl: summary.imageUrl,
      inventoryMatches: summary.inventoryMatches,
      savedAt: savedAt ?? DateTime.now(),
    );
  }

  /// Crea un favorito a partir del detalle de una receta.
  factory FavoriteRecipe.fromDetail(RecipeDetail detail, {DateTime? savedAt}) {
    return FavoriteRecipe(
      id: detail.id,
      name: detail.name,
      category: detail.category,
      prepTimeMinutes: detail.prepTimeMinutes,
      servings: detail.servings,
      imageUrl: detail.imageUrl,
      inventoryMatches: detail.inventoryMatches,
      savedAt: savedAt ?? DateTime.now(),
    );
  }

  // -- Mapping SQLite ---------------------------------------------------------

  Map<String, Object?> toRow() {
    return {
      'id': id,
      'name': name,
      'category': category.value,
      'prep_time_minutes': prepTimeMinutes,
      'servings': servings,
      'image_url': imageUrl,
      'inventory_matches': inventoryMatches,
      'saved_at': savedAt.millisecondsSinceEpoch,
    };
  }

  factory FavoriteRecipe.fromRow(Map<String, Object?> row) {
    return FavoriteRecipe(
      id: row['id'] as String,
      name: row['name'] as String,
      category: RecipeCategory.fromString(row['category'] as String),
      prepTimeMinutes: row['prep_time_minutes'] as int?,
      servings: (row['servings'] as int?) ?? 1,
      imageUrl: row['image_url'] as String?,
      inventoryMatches: (row['inventory_matches'] as int?) ?? 0,
      savedAt: DateTime.fromMillisecondsSinceEpoch(row['saved_at'] as int),
    );
  }
}
