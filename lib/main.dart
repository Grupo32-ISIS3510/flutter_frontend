import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:second_serving_frontend/core/config/api_config.dart';
import 'package:second_serving_frontend/core/config/app_theme.dart';
import 'package:second_serving_frontend/core/router/router.dart';
import 'package:second_serving_frontend/features/analytics/providers/analytics_provider.dart';
import 'package:second_serving_frontend/features/auth/providers/auth_provider.dart';
import 'package:second_serving_frontend/features/inventory/providers/inventory_provider.dart';
import 'package:second_serving_frontend/features/recipes/providers/recipe_provider.dart';
import 'package:second_serving_frontend/core/network/api_client.dart';
import 'package:second_serving_frontend/features/analytics/services/analytics_service.dart';
import 'package:second_serving_frontend/features/auth/services/auth_service.dart';
import 'package:second_serving_frontend/features/inventory/services/inventory_service.dart';
import 'package:second_serving_frontend/features/recipes/services/recipe_service.dart';
import 'package:second_serving_frontend/features/auth/services/mock_auth_service.dart';
import 'package:second_serving_frontend/features/inventory/services/mock_inventory_service.dart';
import 'package:second_serving_frontend/features/recipes/services/mock_recipe_service.dart';
import 'package:second_serving_frontend/features/analytics/services/mock_analytics_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es', null);
  runApp(const SecondServingApp());
}

class SecondServingApp extends StatelessWidget {
  const SecondServingApp({super.key});

  @override
  Widget build(BuildContext context) {
    final apiClient = ApiClient();

    final AuthService authService =
        (ApiConfig.useMock || ApiConfig.useMockAuth)
            ? MockAuthService()
            : AuthServiceImpl(apiClient);
    final InventoryService inventoryService =
        (ApiConfig.useMock || ApiConfig.useMockInventory)
            ? MockInventoryService()
            : InventoryServiceImpl(apiClient);
    final RecipeService recipeService =
        (ApiConfig.useMock || ApiConfig.useMockRecipes)
            ? MockRecipeService()
            : RecipeServiceImpl(apiClient);
    final AnalyticsService analyticsService =
        (ApiConfig.useMock || ApiConfig.useMockAnalytics)
            ? MockAnalyticsService()
            : AnalyticsServiceImpl(apiClient);

    final authProvider = AuthProvider(authService, apiClient);
    final router = createRouter(authProvider);

    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authProvider),
        ChangeNotifierProvider(create: (_) => InventoryProvider(inventoryService)),
        ChangeNotifierProvider(create: (_) => RecipeProvider(recipeService)),
        ChangeNotifierProvider(create: (_) => AnalyticsProvider(analyticsService)),
      ],
      child: MaterialApp.router(
        title: 'Second Serving',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        routerConfig: router,
      ),
    );
  }
}
