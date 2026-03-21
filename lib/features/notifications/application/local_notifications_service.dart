import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class LocalNotificationsService {
  LocalNotificationsService._();

  static final LocalNotificationsService instance = LocalNotificationsService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  static const String _channelId = 'expiring_items_channel';
  static const String _channelName = 'Alimentos próximos a vencer';
  static const String _channelDescription = 'Alertas inmediatas de alimentos por vencer';

  Future<void> initialize() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(settings);

    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelId,
            _channelName,
            description: _channelDescription,
            importance: Importance.high,
          ),
        );
  }

  Future<void> showExpiringSoonNotification({
    required String itemName,
    required int daysRemaining,
  }) async {
    final String subtitle = daysRemaining <= 0
        ? '$itemName — vence hoy'
        : '$itemName — vence en $daysRemaining día${daysRemaining == 1 ? '' : 's'}';

    const NotificationDetails details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );

    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      '⚠️ Alimentos próximos a vencer',
      subtitle,
      details,
    );
  }
}