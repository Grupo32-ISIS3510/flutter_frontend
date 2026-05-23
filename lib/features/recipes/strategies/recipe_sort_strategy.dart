import 'package:second_serving_frontend/features/recipes/models/recipe.dart';

/// PATRÓN STRATEGY — Interfaz que define una familia de algoritmos de
/// ordenamiento/priorización de recetas, intercambiables en tiempo de ejecución.
///
/// Cada estrategia concreta encapsula un criterio diferente para ordenar
/// la lista de recetas sugeridas. El contexto (RecipeProvider) delega
/// la lógica de ordenamiento a la estrategia activa sin conocer su
/// implementación interna.
abstract class RecipeSortStrategy {
  String get label;
  String get icon;
  List<RecipeSummary> sort(List<RecipeSummary> recipes);
}

/// Prioriza recetas que usan más ingredientes del inventario del usuario.
/// Criterio: mayor inventoryMatches primero.
class SortByIngredientMatch implements RecipeSortStrategy {
  @override
  String get label => 'Más ingredientes';

  @override
  String get icon => '🥕';

  @override
  List<RecipeSummary> sort(List<RecipeSummary> recipes) {
    final sorted = List<RecipeSummary>.from(recipes);
    sorted.sort((a, b) => b.inventoryMatches.compareTo(a.inventoryMatches));
    return sorted;
  }
}

/// Prioriza recetas rápidas de preparar.
/// Criterio: menor prepTimeMinutes primero (null va al final).
class SortByQuickPrep implements RecipeSortStrategy {
  @override
  String get label => 'Más rápidas';

  @override
  String get icon => '⚡';

  @override
  List<RecipeSummary> sort(List<RecipeSummary> recipes) {
    final sorted = List<RecipeSummary>.from(recipes);
    sorted.sort((a, b) {
      final aTime = a.prepTimeMinutes ?? 999;
      final bTime = b.prepTimeMinutes ?? 999;
      return aTime.compareTo(bTime);
    });
    return sorted;
  }
}

/// Prioriza recetas que combinan coincidencia de ingredientes con rapidez.
/// Criterio compuesto: score = inventoryMatches * 10 - prepTimeMinutes.
class SortByExpiringSoon implements RecipeSortStrategy {
  @override
  String get label => 'Por vencer';

  @override
  String get icon => '⏰';

  @override
  List<RecipeSummary> sort(List<RecipeSummary> recipes) {
    final sorted = List<RecipeSummary>.from(recipes);
    sorted.sort((a, b) {
      final aScore = a.inventoryMatches * 10 - (a.prepTimeMinutes ?? 30);
      final bScore = b.inventoryMatches * 10 - (b.prepTimeMinutes ?? 30);
      return bScore.compareTo(aScore);
    });
    return sorted;
  }
}
