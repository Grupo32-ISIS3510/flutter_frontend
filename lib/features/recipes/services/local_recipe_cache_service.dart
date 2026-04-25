import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:second_serving_frontend/features/recipes/models/recipe.dart';

/// Caché local de recetas en SharedPreferences.
///
/// Estrategia de conectividad eventual para Recetas:
///   - Cada vez que el backend responde, se cachean los datos localmente.
///   - En modo offline, se leen del caché → el usuario ve recetas reales,
///     no datos mock genéricos.
///   - Política de invalidación: se sobreescribe en cada respuesta exitosa
///     del backend (siempre frescos cuando hay red).
class LocalRecipeCacheService {
  static const String _suggestionsKey = 'cache.recipe_suggestions';
  static const String _recipesKey = 'cache.recipe_list';
  static const String _detailKeyPrefix = 'cache.recipe_detail.';

  // ── Sugerencias ──────────────────────────────────────────────

  Future<void> cacheSuggestions(List<RecipeSummary> suggestions) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = suggestions.map((r) => jsonEncode(r.toJson())).toList();
    await prefs.setStringList(_suggestionsKey, encoded);
    debugPrint('[RecipeCache] Cached ${suggestions.length} suggestions');
  }

  Future<List<RecipeSummary>> getCachedSuggestions() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_suggestionsKey);
    if (raw == null || raw.isEmpty) return [];
    return raw.map((s) {
      final json = jsonDecode(s) as Map<String, dynamic>;
      return RecipeSummary.fromJson(json);
    }).toList();
  }

  // ── Lista de recetas ─────────────────────────────────────────

  Future<void> cacheRecipes(RecipeListResponse response) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = response.items.map((r) => jsonEncode(r.toJson())).toList();
    await prefs.setStringList(_recipesKey, encoded);
    await prefs.setInt('${_recipesKey}_total', response.total);
    debugPrint('[RecipeCache] Cached ${response.items.length} recipes');
  }

  Future<RecipeListResponse?> getCachedRecipes() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_recipesKey);
    if (raw == null || raw.isEmpty) return null;
    final total = prefs.getInt('${_recipesKey}_total') ?? raw.length;
    final items = raw.map((s) {
      final json = jsonDecode(s) as Map<String, dynamic>;
      return RecipeSummary.fromJson(json);
    }).toList();
    return RecipeListResponse(items: items, total: total);
  }

  // ── Detalle de receta ────────────────────────────────────────

  Future<void> cacheDetail(RecipeDetail detail) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_detailKeyPrefix${detail.id}',
      jsonEncode(detail.toJson()),
    );
    debugPrint('[RecipeCache] Cached detail for "${detail.name}"');
  }

  Future<RecipeDetail?> getCachedDetail(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_detailKeyPrefix$id');
    if (raw == null) return null;
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return RecipeDetail.fromJson(json);
  }
}
