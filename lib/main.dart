import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/theme/app_theme.dart';
import 'features/context_aware/presentation/product_detail_context_page.dart';
import 'features/notifications/application/push_notifications_service.dart';
import 'features/notifications/data/services/notifications_api_service.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final PushNotificationsService pushNotificationsService = PushNotificationsService(
    notificationsApiService: NotificationsApiService(
      baseUrl: 'http://localhost:8000',
    ),
    accessTokenProvider: _readAccessToken,
  );
  await pushNotificationsService.initialize();

  runApp(const MyApp());
}

Future<String?> _readAccessToken() async {
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  return preferences.getString('access_token');
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Second Serving',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const ProductDetailContextPage(),
    );
  }
}
