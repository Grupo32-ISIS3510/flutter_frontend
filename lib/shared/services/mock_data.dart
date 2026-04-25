import 'package:second_serving_frontend/features/analytics/models/analytics.dart';
import 'package:second_serving_frontend/shared/models/enums.dart';
import 'package:second_serving_frontend/features/inventory/models/inventory_item.dart';
import 'package:second_serving_frontend/shared/models/notification_preferences.dart';
import 'package:second_serving_frontend/features/recipes/models/recipe.dart';
import 'package:second_serving_frontend/features/auth/models/user.dart';

class MockData {
  static final user = User(
    id: 'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
    email: 'juan@example.com',
    fullName: 'Juan Pérez',
    isPremium: false,
    location: 'Bogotá, Colombia',
    createdAt: DateTime(2026, 1, 15),
  );

  static final List<InventoryItem> inventoryItems = [
    InventoryItem(
      id: 'inv-000',
      name: 'Aguacate',
      category: ItemCategory.fruits,
      quantity: 2,
      unit: 'unidades',
      unitPrice: 2500,
      purchaseDate: DateTime.now().subtract(const Duration(days: 2)),
      expiryDate: DateTime.now().add(const Duration(days: 1)),
      status: ItemStatus.active,
      notes: 'Ejemplo para contexto-aware',
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
    InventoryItem(
      id: 'inv-001',
      name: 'Leche entera',
      category: ItemCategory.dairy,
      quantity: 2,
      unit: 'litros',
      unitPrice: 3500,
      purchaseDate: DateTime.now().subtract(const Duration(days: 3)),
      expiryDate: DateTime.now().add(const Duration(days: 2)),
      status: ItemStatus.active,
      notes: null,
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
    ),
    InventoryItem(
      id: 'inv-002',
      name: 'Pechuga de pollo',
      category: ItemCategory.meat,
      quantity: 1.5,
      unit: 'kg',
      unitPrice: 14000,
      purchaseDate: DateTime.now().subtract(const Duration(days: 2)),
      expiryDate: DateTime.now().add(const Duration(days: 1)),
      status: ItemStatus.active,
      notes: 'Congelar si no se usa',
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
    InventoryItem(
      id: 'inv-003',
      name: 'Tomates',
      category: ItemCategory.vegetables,
      quantity: 6,
      unit: 'unidades',
      unitPrice: 800,
      purchaseDate: DateTime.now().subtract(const Duration(days: 4)),
      expiryDate: DateTime.now().add(const Duration(days: 5)),
      status: ItemStatus.active,
      notes: null,
      createdAt: DateTime.now().subtract(const Duration(days: 4)),
    ),
    InventoryItem(
      id: 'inv-004',
      name: 'Arroz integral',
      category: ItemCategory.grains,
      quantity: 3,
      unit: 'kg',
      unitPrice: 5200,
      purchaseDate: DateTime.now().subtract(const Duration(days: 10)),
      expiryDate: DateTime.now().add(const Duration(days: 90)),
      status: ItemStatus.active,
      notes: null,
      createdAt: DateTime.now().subtract(const Duration(days: 10)),
    ),
    InventoryItem(
      id: 'inv-005',
      name: 'Yogur griego',
      category: ItemCategory.dairy,
      quantity: 4,
      unit: 'unidades',
      unitPrice: 2800,
      purchaseDate: DateTime.now().subtract(const Duration(days: 5)),
      expiryDate: DateTime.now().subtract(const Duration(days: 1)),
      status: ItemStatus.active,
      notes: null,
      createdAt: DateTime.now().subtract(const Duration(days: 5)),
    ),
    InventoryItem(
      id: 'inv-006',
      name: 'Manzanas',
      category: ItemCategory.fruits,
      quantity: 5,
      unit: 'unidades',
      unitPrice: 1200,
      purchaseDate: DateTime.now().subtract(const Duration(days: 3)),
      expiryDate: DateTime.now().add(const Duration(days: 7)),
      status: ItemStatus.active,
      notes: null,
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
    ),
    InventoryItem(
      id: 'inv-007',
      name: 'Jugo de naranja',
      category: ItemCategory.beverages,
      quantity: 1,
      unit: 'litros',
      unitPrice: 6500,
      purchaseDate: DateTime.now().subtract(const Duration(days: 7)),
      expiryDate: DateTime.now().add(const Duration(days: 3)),
      status: ItemStatus.active,
      notes: null,
      createdAt: DateTime.now().subtract(const Duration(days: 7)),
    ),
    InventoryItem(
      id: 'inv-008',
      name: 'Galletas integrales',
      category: ItemCategory.snacks,
      quantity: 2,
      unit: 'paquetes',
      unitPrice: 4500,
      purchaseDate: DateTime.now().subtract(const Duration(days: 1)),
      expiryDate: DateTime.now().add(const Duration(days: 60)),
      status: ItemStatus.active,
      notes: null,
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
  ];

  static const List<String> expiringIngredientNames = [
    'Aguacate', 'Tomates cherry', 'Leche', 'Pollo', 'Banano', 'Arroz',
  ];

  static final List<RecipeSummary> recipeSummaries = [
    const RecipeSummary(
      id: 'rec-001',
      name: 'Ensalada de aguacate y tomate',
      description: '¡Úsalos antes de que maduren demasiado!',
      category: RecipeCategory.lunch,
      prepTimeMinutes: 15,
      servings: 2,
      imageUrl: null,
      inventoryMatches: 2,
    ),
    const RecipeSummary(
      id: 'rec-002',
      name: 'Smoothie de banano y leche',
      description: 'Perfecto para un snack rápido',
      category: RecipeCategory.breakfast,
      prepTimeMinutes: 5,
      servings: 2,
      imageUrl: null,
      inventoryMatches: 2,
    ),
    const RecipeSummary(
      id: 'rec-003',
      name: 'Arroz con vegetales salteados',
      description: 'Completa tu menú diario',
      category: RecipeCategory.dinner,
      prepTimeMinutes: 25,
      servings: 4,
      imageUrl: null,
      inventoryMatches: 3,
    ),
    const RecipeSummary(
      id: 'rec-004',
      name: 'Sopa de pollo con verduras',
      description: 'Usa el pollo antes de que se venza',
      category: RecipeCategory.lunch,
      prepTimeMinutes: 45,
      servings: 4,
      imageUrl: null,
      inventoryMatches: 3,
    ),
    const RecipeSummary(
      id: 'rec-005',
      name: 'Panqueques con banano',
      description: 'Desayuno perfecto con bananos maduros',
      category: RecipeCategory.breakfast,
      prepTimeMinutes: 20,
      servings: 3,
      imageUrl: null,
      inventoryMatches: 2,
    ),
  ];

  static const Map<String, List<String>> recipeMatchedIngredients = {
    'rec-001': ['Aguacate', 'Tomates'],
    'rec-002': ['Banano', 'Leche'],
    'rec-003': ['Tomates', 'Arroz', 'Zanahoria'],
    'rec-004': ['Pollo', 'Tomates', 'Zanahoria'],
    'rec-005': ['Banano', 'Leche'],
  };

  static final Map<String, RecipeDetail> recipeDetails = {
    'rec-001': RecipeDetail(
      id: 'rec-001',
      name: 'Ensalada de aguacate y tomate',
      description: '¡Úsalos antes de que maduren demasiado!',
      instructions: '''1. Lavar y cortar los tomates en rodajas.
2. Pelar y cortar el aguacate en cubos.
3. Picar finamente la cebolla morada y el cilantro.
4. Mezclar todo en un bowl grande.
5. Exprimir el jugo de un limón sobre la ensalada.
6. Agregar aceite de oliva, sal y pimienta al gusto.
7. Mezclar suavemente para no deshacer el aguacate.
8. Servir inmediatamente, decorar con semillas de sésamo.''',
      prepTimeMinutes: 15,
      servings: 2,
      category: RecipeCategory.lunch,
      imageUrl: null,
      ingredients: const [
        RecipeIngredient(id: 'ing-101', ingredientName: 'aguacate', quantity: 2, unit: 'unidades'),
        RecipeIngredient(id: 'ing-102', ingredientName: 'tomates', quantity: 3, unit: 'unidades'),
        RecipeIngredient(id: 'ing-103', ingredientName: 'cebolla morada', quantity: 0.5, unit: 'unidad'),
        RecipeIngredient(id: 'ing-104', ingredientName: 'cilantro', quantity: null, unit: 'al gusto'),
        RecipeIngredient(id: 'ing-105', ingredientName: 'limón', quantity: 1, unit: 'unidad'),
        RecipeIngredient(id: 'ing-106', ingredientName: 'aceite de oliva', quantity: 2, unit: 'cucharadas'),
      ],
      inventoryMatches: 2,
      createdAt: DateTime(2026, 1, 1),
    ),
    'rec-002': RecipeDetail(
      id: 'rec-002',
      name: 'Smoothie de banano y leche',
      description: 'Perfecto para un snack rápido y nutritivo.',
      instructions: '''1. Pelar los bananos y cortarlos en trozos.
2. Verter la leche en la licuadora.
3. Agregar los trozos de banano.
4. Añadir una cucharada de miel (opcional).
5. Agregar hielo si se desea frío.
6. Licuar por 30-40 segundos hasta obtener una mezcla homogénea.
7. Servir inmediatamente en un vaso alto.''',
      prepTimeMinutes: 5,
      servings: 2,
      category: RecipeCategory.breakfast,
      imageUrl: null,
      ingredients: const [
        RecipeIngredient(id: 'ing-201', ingredientName: 'banano', quantity: 2, unit: 'unidades'),
        RecipeIngredient(id: 'ing-202', ingredientName: 'leche', quantity: 400, unit: 'ml'),
        RecipeIngredient(id: 'ing-203', ingredientName: 'miel', quantity: 1, unit: 'cucharada'),
        RecipeIngredient(id: 'ing-204', ingredientName: 'hielo', quantity: null, unit: 'al gusto'),
      ],
      inventoryMatches: 2,
      createdAt: DateTime(2026, 1, 5),
    ),
    'rec-003': RecipeDetail(
      id: 'rec-003',
      name: 'Arroz con vegetales salteados',
      description: 'Completa tu menú diario con esta receta fácil.',
      instructions: '''1. Cocinar el arroz según las instrucciones del paquete.
2. Mientras tanto, lavar y picar los vegetales en trozos pequeños.
3. Calentar aceite en un wok o sartén grande a fuego alto.
4. Saltear la zanahoria y el brócoli por 3 minutos.
5. Agregar los tomates y cocinar 2 minutos más.
6. Añadir salsa de soya y revolver.
7. Incorporar el arroz cocido y mezclar bien.
8. Cocinar 2-3 minutos más revolviendo constantemente.
9. Servir caliente con semillas de sésamo.''',
      prepTimeMinutes: 25,
      servings: 4,
      category: RecipeCategory.dinner,
      imageUrl: null,
      ingredients: const [
        RecipeIngredient(id: 'ing-301', ingredientName: 'arroz', quantity: 2, unit: 'tazas'),
        RecipeIngredient(id: 'ing-302', ingredientName: 'tomates', quantity: 2, unit: 'unidades'),
        RecipeIngredient(id: 'ing-303', ingredientName: 'zanahoria', quantity: 2, unit: 'unidades'),
        RecipeIngredient(id: 'ing-304', ingredientName: 'brócoli', quantity: 1, unit: 'taza'),
        RecipeIngredient(id: 'ing-305', ingredientName: 'salsa de soya', quantity: 3, unit: 'cucharadas'),
        RecipeIngredient(id: 'ing-306', ingredientName: 'aceite', quantity: 2, unit: 'cucharadas'),
      ],
      inventoryMatches: 3,
      createdAt: DateTime(2026, 1, 10),
    ),
    'rec-004': RecipeDetail(
      id: 'rec-004',
      name: 'Sopa de pollo con verduras',
      description: 'Una sopa reconfortante ideal para usar pollo y verduras próximos a vencer.',
      instructions: '''1. Cortar la pechuga de pollo en trozos pequeños.
2. En una olla grande, calentar aceite a fuego medio.
3. Sofreír el pollo hasta que esté dorado (5-7 minutos).
4. Agregar los tomates picados y cocinar por 3 minutos.
5. Añadir la zanahoria cortada en rodajas y la cebolla.
6. Verter 1 litro de agua o caldo y llevar a ebullición.
7. Reducir el fuego y cocinar a fuego lento por 25 minutos.
8. Sazonar con sal, pimienta y cilantro al gusto.
9. Servir caliente con arroz o pan.''',
      prepTimeMinutes: 45,
      servings: 4,
      category: RecipeCategory.lunch,
      imageUrl: null,
      ingredients: const [
        RecipeIngredient(id: 'ing-401', ingredientName: 'pollo', quantity: 500, unit: 'g'),
        RecipeIngredient(id: 'ing-402', ingredientName: 'tomates', quantity: 3, unit: 'unidades'),
        RecipeIngredient(id: 'ing-403', ingredientName: 'cebolla', quantity: 1, unit: 'unidad'),
        RecipeIngredient(id: 'ing-404', ingredientName: 'zanahoria', quantity: 2, unit: 'unidades'),
        RecipeIngredient(id: 'ing-405', ingredientName: 'sal', quantity: null, unit: 'al gusto'),
      ],
      inventoryMatches: 3,
      createdAt: DateTime(2026, 1, 1),
    ),
    'rec-005': RecipeDetail(
      id: 'rec-005',
      name: 'Panqueques con banano',
      description: 'Desayuno perfecto con bananos maduros.',
      instructions: '''1. En un bowl, mezclar la harina, el azúcar y el polvo de hornear.
2. En otro bowl, batir el huevo con la leche y la mantequilla derretida.
3. Combinar los ingredientes secos con los líquidos hasta integrar.
4. Pelar y cortar el banano en rodajas finas.
5. Calentar una sartén antiadherente a fuego medio.
6. Verter un cucharón de mezcla y colocar rodajas de banano encima.
7. Cocinar hasta que aparezcan burbujas (2-3 minutos), voltear.
8. Cocinar 1-2 minutos más del otro lado.
9. Repetir con el resto de la mezcla.
10. Servir apilados con miel y más rodajas de banano.''',
      prepTimeMinutes: 20,
      servings: 3,
      category: RecipeCategory.breakfast,
      imageUrl: null,
      ingredients: const [
        RecipeIngredient(id: 'ing-501', ingredientName: 'banano', quantity: 2, unit: 'unidades'),
        RecipeIngredient(id: 'ing-502', ingredientName: 'leche', quantity: 200, unit: 'ml'),
        RecipeIngredient(id: 'ing-503', ingredientName: 'harina', quantity: 1.5, unit: 'tazas'),
        RecipeIngredient(id: 'ing-504', ingredientName: 'huevo', quantity: 1, unit: 'unidad'),
        RecipeIngredient(id: 'ing-505', ingredientName: 'mantequilla', quantity: 2, unit: 'cucharadas'),
        RecipeIngredient(id: 'ing-506', ingredientName: 'miel', quantity: null, unit: 'al gusto'),
      ],
      inventoryMatches: 2,
      createdAt: DateTime(2026, 1, 15),
    ),
  };

  static const dashboard = DashboardResponse(
    savings: SavingsResponse(
      savedCop: 45000,
      wastedCop: 11200,
      period: '2026-03',
    ),
    wasteSummary: WasteSummary(
      totalConsumed: 18,
      totalDiscarded: 4,
      mostWastedCategory: 'dairy',
      mostDiscardedItem: 'Yogur',
      noWasteStreakDays: 5,
    ),
    segment: UserSegment(
      segment: 'neutral',
      recipesCookedLast30Days: 2,
      openRate: 0.4,
    ),
    recipeImpact: recipeImpact,
    behaviorPatterns: behaviorPatterns,
  );

  static const recipeImpact = RecipeImpactResponse(
    totalWasteReductionPercentage: 68.2,
    totalValueSavedCop: 45000,
    impacts: [
      RecipeRecommendationImpact(
        recipeCategory: 'lunch',
        totalRecommended: 12,
        itemsConsumed: 10,
        itemsDiscarded: 2,
        wasteReductionPercentage: 78.4,
        estimatedValueSavedCop: 18500,
      ),
      RecipeRecommendationImpact(
        recipeCategory: 'breakfast',
        totalRecommended: 8,
        itemsConsumed: 6,
        itemsDiscarded: 2,
        wasteReductionPercentage: 66.7,
        estimatedValueSavedCop: 12200,
      ),
      RecipeRecommendationImpact(
        recipeCategory: 'dinner',
        totalRecommended: 7,
        itemsConsumed: 5,
        itemsDiscarded: 2,
        wasteReductionPercentage: 60.5,
        estimatedValueSavedCop: 10300,
      ),
      RecipeRecommendationImpact(
        recipeCategory: 'snack',
        totalRecommended: 5,
        itemsConsumed: 3,
        itemsDiscarded: 2,
        wasteReductionPercentage: 50.0,
        estimatedValueSavedCop: 4000,
      ),
    ],
  );

  static const behaviorPatterns = BehaviorPatternsResponse(
    summary:
        'Los usuarios proactivos responden antes a productos por vencer, cocinan más recetas sugeridas y desperdician menos inventario.',
    metrics: [
      BehaviorPatternMetric(
        metric: 'Recetas cocinadas en 30 días',
        passiveValue: 1.2,
        proactiveValue: 5.8,
        unit: 'recetas',
        insight: 'Mayor adopción de recomendaciones en usuarios proactivos.',
      ),
      BehaviorPatternMetric(
        metric: 'Apertura de alertas',
        passiveValue: 28,
        proactiveValue: 74,
        unit: '%',
        insight: 'Los proactivos interactúan más con recordatorios.',
      ),
      BehaviorPatternMetric(
        metric: 'Acciones antes de vencer',
        passiveValue: 18,
        proactiveValue: 67,
        unit: '%',
        insight: 'Más consumo o planificación antes de la fecha límite.',
      ),
      BehaviorPatternMetric(
        metric: 'Tasa de descarte',
        passiveValue: 31,
        proactiveValue: 9,
        unit: '%',
        insight: 'Los pasivos descartan una proporción mayor del inventario.',
      ),
    ],
  );

  static const List<WasteTrendItem> wasteTrends = [
    WasteTrendItem(month: '2026-01', category: 'dairy', itemsDiscarded: 3, valueLostCop: 9500),
    WasteTrendItem(month: '2026-01', category: 'vegetables', itemsDiscarded: 2, valueLostCop: 4200),
    WasteTrendItem(month: '2026-02', category: 'dairy', itemsDiscarded: 1, valueLostCop: 3500),
    WasteTrendItem(month: '2026-02', category: 'meat', itemsDiscarded: 1, valueLostCop: 14000),
    WasteTrendItem(month: '2026-03', category: 'dairy', itemsDiscarded: 2, valueLostCop: 5600),
    WasteTrendItem(month: '2026-03', category: 'fruits', itemsDiscarded: 1, valueLostCop: 3200),
  ];

  static const notificationPrefs = NotificationPreferences(
    daysBeforeExpiry: 3,
    quietHoursStart: 22,
    quietHoursEnd: 7,
    pushEnabled: true,
  );
}
