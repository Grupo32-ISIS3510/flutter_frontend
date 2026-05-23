import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:second_serving_frontend/core/config/api_config.dart';
import 'package:second_serving_frontend/core/config/app_theme.dart';
import 'package:second_serving_frontend/core/connectivity/connectivity_service.dart';
import 'package:second_serving_frontend/core/router/router.dart';
import 'package:second_serving_frontend/core/widgets/offline_banner.dart';
import 'package:second_serving_frontend/features/analytics/providers/analytics_provider.dart';
import 'package:second_serving_frontend/features/analytics/providers/savings_detail_provider.dart';
import 'package:second_serving_frontend/features/analytics/data/waste_cache.dart';
import 'package:second_serving_frontend/features/auth/providers/auth_provider.dart';
import 'package:second_serving_frontend/features/favorites/data/favorites_local_db.dart';
import 'package:second_serving_frontend/features/favorites/providers/favorites_provider.dart';
import 'package:second_serving_frontend/features/inventory/data/inventory_local_db.dart';
import 'package:second_serving_frontend/features/inventory/providers/inventory_provider.dart';
import 'package:second_serving_frontend/features/inventory/services/cached_inventory_service.dart';
import 'package:second_serving_frontend/features/recipes/providers/recipe_provider.dart';
import 'package:second_serving_frontend/features/shopping_list/providers/shopping_list_provider.dart';
import 'package:second_serving_frontend/core/network/api_client.dart';
import 'package:second_serving_frontend/features/analytics/services/analytics_service.dart';
import 'package:second_serving_frontend/features/auth/services/auth_service.dart';
import 'package:second_serving_frontend/features/inventory/services/inventory_service.dart';
import 'package:second_serving_frontend/features/recipes/services/recipe_service.dart';
import 'package:second_serving_frontend/features/auth/services/mock_auth_service.dart';
import 'package:second_serving_frontend/features/inventory/services/mock_inventory_service.dart';
import 'package:second_serving_frontend/features/recipes/services/mock_recipe_service.dart';
import 'package:second_serving_frontend/features/analytics/services/mock_analytics_service.dart';
import 'package:second_serving_frontend/features/notifications/application/push_notifications_service.dart';
import 'package:second_serving_frontend/features/notifications/application/local_notifications_service.dart';
import 'package:second_serving_frontend/features/notifications/data/services/notifications_api_service.dart';
import 'package:second_serving_frontend/firebase_options.dart';
import 'package:second_serving_frontend/core/network/connectivity_provider.dart';
import 'package:second_serving_frontend/features/inventory/services/scan_telemetry_service.dart';
import 'package:second_serving_frontend/features/inventory/services/expiry_telemetry_service.dart';
import 'package:second_serving_frontend/features/inventory/services/screen_analytics_service.dart';
import 'package:second_serving_frontend/features/analytics/services/feature_usage_telemetry_service.dart';

const FlutterSecureStorage _secureStorage = FlutterSecureStorage();
late final PushNotificationsService _pushNotificationsService;
final ConnectivityService _connectivityService = ConnectivityService();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Future.wait([
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]),
    initializeDateFormatting('es', null),
    LocalNotificationsService.instance.initialize(),
    _connectivityService.initialize(),
    InventoryLocalDb.instance.initialize(),
    FavoritesLocalDb.instance.initialize(),
  ]);

  _pushNotificationsService = PushNotificationsService(
    notificationsApiService: NotificationsApiService(
      baseUrl: ApiConfig.baseUrl,
    ),
    accessTokenProvider: _readAccessToken,
  );

  runApp(const SecondServingApp());

  unawaited(_initializeFirebaseAndPush());
}

Future<String?> _readAccessToken() async {
  return _secureStorage.read(key: 'auth_token');
}

Future<void> _initializeFirebaseAndPush() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await _pushNotificationsService.initialize();
  } catch (_) {}
}

Future<void> _syncPushTokenAfterAuth() async {
  await _pushNotificationsService.syncTokenIfPossible();
}

class SecondServingApp extends StatefulWidget {
  const SecondServingApp({super.key});

  @override
  State<SecondServingApp> createState() => _SecondServingAppState();
}

class _SecondServingAppState extends State<SecondServingApp> {
  late final ApiClient _apiClient;
  late final AuthProvider _authProvider;
  late final InventoryProvider _inventoryProvider;
  late final RecipeProvider _recipeProvider;
  late final FavoritesProvider _favoritesProvider;
  late final AnalyticsProvider _analyticsProvider;
  late final SavingsDetailProvider _savingsDetailProvider;
  late final WasteCache _wasteCache;
  late final ShoppingListProvider _shoppingListProvider;
  late final ConnectivityProvider _connectivityProvider;
  late final RecipeService _recipeService;
  late final FeatureUsageTelemetryService _featureUsageTelemetry;
  late final GoRouter _router;

  StreamSubscription<String>? _pushTapSubscription;
  StreamSubscription<String>? _localTapSubscription;

  @override
  void initState() {
    super.initState();
    _apiClient = ApiClient();

    final AuthService authService = (ApiConfig.useMock || ApiConfig.useMockAuth)
        ? MockAuthService()
        : AuthServiceImpl(_apiClient);
    final InventoryService inventoryService =
        (ApiConfig.useMock || ApiConfig.useMockInventory)
        ? MockInventoryService()
        : CachedInventoryService(
            remote: InventoryServiceImpl(_apiClient),
            db: InventoryLocalDb.instance,
          );
    _recipeService = (ApiConfig.useMock || ApiConfig.useMockRecipes)
        ? MockRecipeService()
        : RecipeServiceImpl(_apiClient);
    final AnalyticsService analyticsService =
        (ApiConfig.useMock || ApiConfig.useMockAnalytics)
        ? MockAnalyticsService()
        : AnalyticsServiceImpl(_apiClient);

    _authProvider = AuthProvider(
      authService,
      _apiClient,
      onAuthenticated: _syncPushTokenAfterAuth,
      onLogout: () async {
        await InventoryLocalDb.instance.clear();
        await FavoritesLocalDb.instance.clear();
        await _wasteCache.clear();
        _favoritesProvider.reset();
      },
    );
    _analyticsProvider = AnalyticsProvider(analyticsService);
    _wasteCache = WasteCache();
    _savingsDetailProvider = SavingsDetailProvider(
      analyticsService,
      _wasteCache,
      connectivityService: _connectivityService,
    );
    _inventoryProvider = InventoryProvider(
      inventoryService,
      onInventoryMutated: () => _analyticsProvider.loadMonthlySavings(),
    );
    _recipeProvider = RecipeProvider(_recipeService);
    _favoritesProvider = FavoritesProvider(connectivity: _connectivityService);
    _shoppingListProvider = ShoppingListProvider();
    _featureUsageTelemetry = FeatureUsageTelemetryService(apiClient: _apiClient);
    _connectivityProvider = ConnectivityProvider(
      connectivityService: _connectivityService,
      inventoryProvider: _inventoryProvider,
      expiryTelemetry: ExpiryTelemetryService(apiClient: _apiClient),
      screenAnalytics: ScreenAnalyticsService(apiClient: _apiClient),
      scanTelemetry: ScanTelemetryService(apiClient: _apiClient),
      featureUsage: _featureUsageTelemetry,
    );
    _router = createRouter(_authProvider);

    _pushTapSubscription = _pushNotificationsService.onNotificationTap.listen(
      _handleNotificationRoute,
    );
    _localTapSubscription = LocalNotificationsService.instance.onNotificationTap
        .listen(_handleNotificationRoute);

    final String? pendingRoute = _pushNotificationsService
        .consumePendingTapRoute();
    if (pendingRoute != null) {
      scheduleMicrotask(() => _handleNotificationRoute(pendingRoute));
    }
  }

  void _handleNotificationRoute(String route) {
    if (!mounted) {
      return;
    }
    _router.go(route);
  }

  @override
  void dispose() {
    _pushTapSubscription?.cancel();
    _localTapSubscription?.cancel();
    _connectivityProvider.dispose();
    _inventoryProvider.dispose();
    _recipeProvider.dispose();
    _favoritesProvider.dispose();
    _shoppingListProvider.dispose();
    _analyticsProvider.dispose();
    _savingsDetailProvider.dispose();
    _authProvider.dispose();
    _apiClient.dispose();
    unawaited(_connectivityService.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ConnectivityService>.value(value: _connectivityService),
        Provider<ApiClient>.value(value: _apiClient),
        Provider<RecipeService>.value(value: _recipeService),
        Provider<FeatureUsageTelemetryService>.value(value: _featureUsageTelemetry),
        ChangeNotifierProvider.value(value: _authProvider),
        ChangeNotifierProvider.value(value: _inventoryProvider),
        ChangeNotifierProvider.value(value: _recipeProvider),
        ChangeNotifierProvider.value(value: _favoritesProvider),
        ChangeNotifierProvider.value(value: _analyticsProvider),
        ChangeNotifierProvider.value(value: _savingsDetailProvider),
        ChangeNotifierProvider.value(value: _shoppingListProvider),
        ChangeNotifierProvider.value(value: _connectivityProvider),
      ],
      child: MaterialApp.router(
        title: 'Second Serving',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('es'), Locale('en')],
        routerConfig: _router,
        builder: (context, child) =>
            OfflineBanner(child: child ?? const SizedBox.shrink()),
      ),
    );
  }
}
