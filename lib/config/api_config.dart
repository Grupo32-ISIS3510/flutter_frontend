class ApiConfig {
  static const bool useMock = true;

  static const String baseUrl = 'http://192.168.1.9:8000';
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

  // Notifications
  static const String notificationDevice = '$apiPrefix/notifications/device';
  static const String notificationPreferences = '$apiPrefix/notifications/preferences';

  // Analytics
  static const String analyticsSavings = '$apiPrefix/analytics/savings';
  static const String analyticsWaste = '$apiPrefix/analytics/waste';
  static const String analyticsSummary = '$apiPrefix/analytics/summary';
  static const String analyticsSegment = '$apiPrefix/analytics/segment';
  static const String analyticsDashboard = '$apiPrefix/analytics/dashboard';

  // Sync
  static const String syncPush = '$apiPrefix/sync/push';
  static const String syncPull = '$apiPrefix/sync/pull';
}
