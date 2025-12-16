import 'package:firebase_messaging/firebase_messaging.dart';
import './servicios/local_notification_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // No necesitamos inicializar cada vez si ya se inicializó en main
  if (message.notification != null) {
    LocalNotificationService.show(
      title: message.notification!.title ?? 'Notificación',
      body: message.notification!.body ?? '',
    );
  }
}
