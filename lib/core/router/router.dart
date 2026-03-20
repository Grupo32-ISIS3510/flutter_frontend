import 'package:go_router/go_router.dart';
import 'package:second_serving_frontend/features/auth/providers/auth_provider.dart';
import 'package:second_serving_frontend/features/auth/screens/splash_screen.dart';
import 'package:second_serving_frontend/features/auth/screens/login_screen.dart';
import 'package:second_serving_frontend/features/auth/screens/register_screen.dart';
import 'package:second_serving_frontend/features/home/screens/home_screen.dart';
import 'package:second_serving_frontend/features/context_aware/presentation/product_detail_context_page.dart';
import 'package:second_serving_frontend/features/inventory/models/inventory_item.dart';

GoRouter createRouter(AuthProvider authProvider) {
  return GoRouter(
    initialLocation: '/',
    refreshListenable: authProvider,
    redirect: (context, state) {
      final authState = authProvider.state;
      final location = state.matchedLocation;

      if (authState == AuthState.initial || authState == AuthState.loading) {
        return null;
      }

      final isAuthenticated = authProvider.isAuthenticated;
      final isAuthRoute = location == '/login' || location == '/register';
      final isSplash = location == '/';

      if (!isAuthenticated && !isAuthRoute && !isSplash) {
        return '/login';
      }

      if (isAuthenticated && (isAuthRoute || isSplash)) {
        return '/home';
      }

      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
      GoRoute(
        path: '/context-aware',
        builder: (context, state) => ProductDetailContextPage(
          item: state.extra is InventoryItem
              ? state.extra as InventoryItem
              : null,
        ),
      ),
    ],
  );
}
