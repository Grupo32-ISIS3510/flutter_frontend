import 'package:second_serving_frontend/models/analytics.dart';
import 'package:second_serving_frontend/models/enums.dart';
import 'package:second_serving_frontend/models/inventory_item.dart';
import 'package:second_serving_frontend/models/notification_preferences.dart';
import 'package:second_serving_frontend/models/recipe.dart';
import 'package:second_serving_frontend/models/user.dart';

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
      id: 'inv-001',
      name: 'Leche entera',
      category: ItemCategory.dairy,
      quantity: 2,
      unit: 'litros',
      unitPrice: 3500,
      purchaseDate: DateTime.now().subtract(const Duration(days: 3)),
      expiryDate: DateTime.now().add(const Duration(days: 2)),
      status: ItemStatus.active,
      daysRemaining: 2,
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
      daysRemaining: 1,
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
      daysRemaining: 5,
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
      daysRemaining: 90,
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
      daysRemaining: -1,
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
      daysRemaining: 7,
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
      daysRemaining: 3,
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
      daysRemaining: 60,
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

  static final recipeDetail = RecipeDetail(
    id: 'rec-001',
    name: 'Sopa de pollo con verduras',
    description: 'Una sopa reconfortante ideal para usar pollo y verduras próximos a vencer.',
    instructions: '''1. Cortar la pechuga de pollo en trozos pequeños.
2. En una olla grande, calentar aceite a fuego medio.
3. Sofreír el pollo hasta que esté dorado (5-7 minutos).
4. Agregar los tomates picados y cocinar por 3 minutos.
5. Añadir 1 litro de agua o caldo y llevar a ebullición.
6. Reducir el fuego y cocinar a fuego lento por 25 minutos.
7. Sazonar con sal, pimienta y cilantro al gusto.
8. Servir caliente con arroz o pan.''',
    prepTimeMinutes: 45,
    servings: 4,
    category: RecipeCategory.lunch,
    imageUrl: null,
    ingredients: const [
      RecipeIngredient(id: 'ing-001', ingredientName: 'pollo', quantity: 500, unit: 'g'),
      RecipeIngredient(id: 'ing-002', ingredientName: 'tomates', quantity: 3, unit: 'unidades'),
      RecipeIngredient(id: 'ing-003', ingredientName: 'cebolla', quantity: 1, unit: 'unidad'),
      RecipeIngredient(id: 'ing-004', ingredientName: 'zanahoria', quantity: 2, unit: 'unidades'),
      RecipeIngredient(id: 'ing-005', ingredientName: 'sal', quantity: null, unit: 'al gusto'),
    ],
    inventoryMatches: 3,
    createdAt: DateTime(2026, 1, 1),
  );

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
