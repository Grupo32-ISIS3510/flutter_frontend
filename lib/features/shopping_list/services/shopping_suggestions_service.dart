import 'package:second_serving_frontend/features/inventory/models/inventory_item.dart';
import 'package:second_serving_frontend/features/recipes/models/recipe.dart';
import 'package:second_serving_frontend/features/shopping_list/models/shopping_item.dart';
import 'package:second_serving_frontend/shared/models/enums.dart';

/// Sugerencia generada para mostrarle al usuario como candidato a agregar
/// a la lista de compras.
class ShoppingSuggestion {
  final String name;
  final ItemCategory category;
  final double quantity;
  final String? unit;
  final ShoppingItemSource source;
  final String reason;
  final String? sourceRef;

  const ShoppingSuggestion({
    required this.name,
    required this.category,
    required this.quantity,
    this.unit,
    required this.source,
    required this.reason,
    this.sourceRef,
  });
}

/// Genera sugerencias inteligentes para la lista de compras.
///
/// Dos fuentes de sugerencias:
///   1. Inventario reciente: items que ya no estan activos (consumidos)
///      y que probablemente el usuario necesite reponer.
///   2. Recetas: ingredientes que aparecen en las recetas sugeridas
///      por el motor pero no estan en el inventario actual.
class ShoppingSuggestionsService {
  /// Devuelve sugerencias deduplicadas contra items ya presentes en la lista.
  List<ShoppingSuggestion> generate({
    required List<InventoryItem> activeInventory,
    required List<InventoryItem> recentlyConsumed,
    required List<RecipeDetail> nearbyRecipes,
    required List<ShoppingItem> currentList,
  }) {
    final suggestions = <ShoppingSuggestion>[];

    final excluded = <String>{
      ...activeInventory.map((i) => _normalize(i.name)),
      ...currentList.map((i) => _normalize(i.name)),
    };

    // 1) Reposicion: items consumidos recientemente que ya no estan activos.
    for (final item in recentlyConsumed) {
      final key = _normalize(item.name);
      if (excluded.contains(key)) continue;
      excluded.add(key);
      suggestions.add(ShoppingSuggestion(
        name: item.name,
        category: item.category,
        quantity: item.quantity > 0 ? item.quantity : 1,
        unit: item.unit,
        source: ShoppingItemSource.consumed,
        reason: 'Lo consumiste recientemente',
      ));
    }

    // 2) Ingredientes faltantes de recetas sugeridas.
    for (final recipe in nearbyRecipes) {
      for (final ing in recipe.ingredients) {
        final key = _normalize(ing.ingredientName);
        if (excluded.contains(key)) continue;
        excluded.add(key);
        suggestions.add(ShoppingSuggestion(
          name: _capitalize(ing.ingredientName),
          category: _guessCategoryFromName(ing.ingredientName),
          quantity: ing.quantity ?? 1,
          unit: ing.unit,
          source: ShoppingItemSource.recipe,
          reason: 'Para preparar "${recipe.name}"',
          sourceRef: recipe.id,
        ));
      }
    }

    return suggestions;
  }

  String _normalize(String s) => s.trim().toLowerCase();

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1).toLowerCase();
  }

  // Heuristica simple para asignar categoria a un ingrediente de receta.
  // Reusa la misma logica conceptual que ReceiptParserService._guessCategory.
  ItemCategory _guessCategoryFromName(String name) {
    final lower = name.toLowerCase();
    const map = {
      ItemCategory.dairy: ['leche', 'yogur', 'yogurt', 'queso', 'crema', 'mantequilla'],
      ItemCategory.meat: ['pollo', 'carne', 'res', 'cerdo', 'pechuga', 'pescado', 'atun', 'salmon'],
      ItemCategory.fruits: ['manzana', 'banana', 'banano', 'naranja', 'limon', 'fresa', 'uva', 'mango', 'aguacate', 'papaya', 'fruta'],
      ItemCategory.vegetables: ['tomate', 'cebolla', 'papa', 'zanahoria', 'lechuga', 'pepino', 'brocoli', 'espinaca', 'pimenton', 'ajo', 'cilantro', 'verdura'],
      ItemCategory.grains: ['arroz', 'pasta', 'pan', 'harina', 'avena', 'cereal', 'lenteja', 'frijol', 'garbanzo'],
      ItemCategory.beverages: ['jugo', 'agua', 'gaseosa', 'cafe', 'te', 'bebida'],
      ItemCategory.snacks: ['galleta', 'chocolate', 'dulce', 'snack'],
    };
    for (final entry in map.entries) {
      for (final kw in entry.value) {
        if (lower.contains(kw)) return entry.key;
      }
    }
    return ItemCategory.other;
  }
}
