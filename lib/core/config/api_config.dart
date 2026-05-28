class ApiConfig {
  static const bool useMock =
      false; // Cambiar a false para usar el backend real

  // Controles por módulo: true = forzar mock aunque useMock sea false
  // Cuando el backend esté listo con auth, cambiar useMock a false
  // y poner cada módulo en false según esté implementado
  static const bool useMockAuth = false;
  static const bool useMockInventory = false;
  static const bool useMockRecipes = false;
  static const bool useMockAnalytics = false;

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://3.16.198.192',
  );
  static const String apiPrefix = '/api/v1';

  static const Duration timeout = Duration(seconds: 30);

  // Auth
  static const String register = '$apiPrefix/auth/register';
  static const String login = '$apiPrefix/auth/login';
  static const String logout = '$apiPrefix/auth/logout';
  static const String me = '$apiPrefix/auth/me';

  // Inventory
  static const String inventory = '$apiPrefix/inventory';
  static const String inventoryExpiring = '$apiPrefix/inventory/expiring';
  static String inventoryItem(String id) => '$apiPrefix/inventory/$id';
  static String consumeItem(String id) => '$apiPrefix/inventory/$id/consume';
  static String discardItem(String id) => '$apiPrefix/inventory/$id/discard';

  // Recipes
  static const String recipes = '$apiPrefix/recipes/';
  static const String recipeSuggestions = '$apiPrefix/recipes/suggestions';
  static const String recipeSeed = '$apiPrefix/recipes/seed';
  static String recipeDetail(String id) => '$apiPrefix/recipes/$id';
  static String recipeInteract(String id) => '$apiPrefix/recipes/$id/interact';
  // Favorites (BQ T3.6)
  static String recipeFavorite(String id) => '$apiPrefix/recipes/$id/favorite';
  static const String recipeFavorites = '$apiPrefix/recipes/favorites';

  // Notifications
  static const String notificationDevice = '$apiPrefix/notifications/device';
  static const String notificationPreferences =
      '$apiPrefix/notifications/preferences';

  // Analytics
  static const String analyticsSavings = '$apiPrefix/analytics/savings';
  static const String analyticsWaste = '$apiPrefix/analytics/waste';
  static const String analyticsSummary = '$apiPrefix/analytics/summary';
  static const String analyticsSegment = '$apiPrefix/analytics/segment';
  static const String analyticsDashboard = '$apiPrefix/analytics/dashboard';
  static const String analyticsRecipeImpact =
      '$apiPrefix/analytics/waste-reduction-by-recipe-category';
  static const String analyticsBehaviorPatterns =
      '$apiPrefix/analytics/segments/patterns';
  static const String analyticsFavoritesDistribution =
      '$apiPrefix/analytics/favorites-distribution';
  // BQ T1.1 / T3.4 — generic analytics events (notification_received / _opened)
  static const String analyticsEvents = '$apiPrefix/analytics/events';

  // Telemetry
  static const String telemetryScanEvent = '$apiPrefix/telemetry/scan-events';
  static const String telemetryExpiryAccuracy =
      '$apiPrefix/telemetry/expiry-accuracy';
  static const String telemetryExpiryStats =
      '$apiPrefix/telemetry/expiry-stats';
  static const String telemetryScreenEvent =
      '$apiPrefix/telemetry/screen-events';
  static const String telemetryAbandonmentStats =
      '$apiPrefix/telemetry/abandonment-stats';
  static const String telemetryFeatureEvent =
      '$apiPrefix/telemetry/feature-events';
  static const String telemetryFeatureUsageStats =
      '$apiPrefix/telemetry/feature-usage-stats';

  // Sync
  static const String syncPush = '$apiPrefix/sync/push';
  static const String syncPull = '$apiPrefix/sync/pull';
}
