import 'package:go_router/go_router.dart';
import 'package:second_serving_frontend/screens/splash/splash_screen.dart';
import 'package:second_serving_frontend/screens/auth/login_screen.dart';
import 'package:second_serving_frontend/screens/home/home_screen.dart';

GoRouter createRouter() {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeScreen(),
      ),
    ],
  );
}
