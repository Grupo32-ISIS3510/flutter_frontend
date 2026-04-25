import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
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
import 'package:second_serving_frontend/features/auth/providers/auth_provider.dart';
import 'package:second_serving_frontend/features/inventory/data/inventory_local_db.dart';
import 'package:second_serving_frontend/features/inventory/providers/inventory_provider.dart';
import 'package:second_serving_frontend/features/inventory/services/cached_inventory_service.dart';
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
import 'package:second_serving_frontend/features/notifications/application/push_notifications_service.dart';
import 'package:second_serving_frontend/features/notifications/application/local_notifications_service.dart';
import 'package:second_serving_frontend/features/notifications/data/services/notifications_api_service.dart';
import 'package:second_serving_frontend/firebase_options.dart';
import 'package:second_serving_frontend/core/network/connectivity_provider.dart';
import 'package:second_serving_frontend/features/inventory/services/scan_telemetry_service.dart';
import 'package:second_serving_frontend/features/inventory/services/expiry_telemetry_service.dart';
import 'package:second_serving_frontend/features/inventory/services/screen_analytics_service.dart';

const FlutterSecureStorage _secureStorage = FlutterSecureStorage();
late final PushNotificationsService _pushNotificationsService;
final ConnectivityService _connectivityService = ConnectivityService();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es', null);
  await LocalNotificationsService.instance.initialize();
  await _connectivityService.initialize();
  await InventoryLocalDb.instance.initialize();

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
  late final AnalyticsProvider _analyticsProvider;
  late final ConnectivityProvider _connectivityProvider;
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
    final RecipeService recipeService =
        (ApiConfig.useMock || ApiConfig.useMockRecipes)
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
      onLogout: InventoryLocalDb.instance.clear,
    );
    _analyticsProvider = AnalyticsProvider(analyticsService);
    _inventoryProvider = InventoryProvider(
      inventoryService,
      onInventoryMutated: () => _analyticsProvider.loadMonthlySavings(),
    );
    _recipeProvider = RecipeProvider(recipeService);
    _connectivityProvider = ConnectivityProvider(
      connectivityService: _connectivityService,
      inventoryProvider: _inventoryProvider,
      expiryTelemetry: ExpiryTelemetryService(apiClient: _apiClient),
      screenAnalytics: ScreenAnalyticsService(apiClient: _apiClient),
      scanTelemetry: ScanTelemetryService(apiClient: _apiClient),
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
    _analyticsProvider.dispose();
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
        ChangeNotifierProvider.value(value: _authProvider),
        ChangeNotifierProvider.value(value: _inventoryProvider),
        ChangeNotifierProvider.value(value: _recipeProvider),
        ChangeNotifierProvider.value(value: _analyticsProvider),
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
