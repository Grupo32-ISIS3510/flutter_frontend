import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:second_serving_frontend/config/api_config.dart';
import 'package:second_serving_frontend/config/app_theme.dart';
import 'package:second_serving_frontend/config/router.dart';
import 'package:second_serving_frontend/providers/analytics_provider.dart';
import 'package:second_serving_frontend/providers/auth_provider.dart';
import 'package:second_serving_frontend/providers/inventory_provider.dart';
import 'package:second_serving_frontend/providers/recipe_provider.dart';
import 'package:second_serving_frontend/services/api_client.dart';
import 'package:second_serving_frontend/services/analytics_service.dart';
import 'package:second_serving_frontend/services/auth_service.dart';
import 'package:second_serving_frontend/services/inventory_service.dart';
import 'package:second_serving_frontend/services/recipe_service.dart';
import 'package:second_serving_frontend/services/mock/mock_auth_service.dart';
import 'package:second_serving_frontend/services/mock/mock_inventory_service.dart';
import 'package:second_serving_frontend/services/mock/mock_recipe_service.dart';
import 'package:second_serving_frontend/services/mock/mock_analytics_service.dart';

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

    final router = createRouter();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider(authService)),
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
