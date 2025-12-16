import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';

import '../api.dart';

class NotificationService {
  // FCM
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  // Local notifications
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  // Canal de notificaciones
  static const String _channelId = 'default';
  static const String _channelName = 'Notificaciones';
  static const String _channelDescription =
      'Canal por defecto de notificaciones';

  /// Inicialización global
  static Future<void> initialize() async {
    // Pedir permisos
    if (Platform.isIOS) {
      await _messaging.requestPermission(alert: true, badge: true, sound: true);
    } else if (Platform.isAndroid) {
      if (await Permission.notification.isDenied) {
        await Permission.notification.request();
      }
    }

    // Inicializar canal de notificaciones locales
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@drawable/ic_notification');

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
    );

    await _localNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        _handleNotificationTap(response.payload);
      },
    );

    // Crear canal Android >= 8
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.max,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

    // Listeners
    FirebaseMessaging.onMessage.listen(_onMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpenedApp);
  }

  /// Registrar dispositivo después del login
  static Future<void> registerDeviceAfterLogin() async {
    try {
      // Eliminar token FCM anterior
      await _messaging.deleteToken();
      print('🗑️ Token FCM anterior eliminado');

      // Obtener nuevo token
      final fcmToken = await _messaging.getToken();
      print('📱 Nuevo token FCM: $fcmToken');
      if (fcmToken == null) return;

      await storage.write(key: 'fcm_token', value: fcmToken);

      // Verificar si hay usuario logueado
      final accessToken = await storage.read(key: 'access');
      if (accessToken == null) return;

      // Enviar token al backend
      final response = await http.post(
        Uri.parse('$kBaseUrl/api/dispositivos/'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'token_fcm': fcmToken,
          'plataforma': Platform.isAndroid ? 'android' : 'ios',
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('✅ Token FCM registrado en backend');
      } else {
        print('❌ Error registrando token FCM: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error enviando token FCM: $e');
    }
  }

  /// Mostrar notificación local
  static Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          NotificationService._channelId,
          NotificationService._channelName,
          channelDescription: NotificationService._channelDescription,
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          ticker: 'ticker',
        );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
    );

    await _localNotifications.show(0, title, body, details, payload: payload);
  }

  /// Listener foreground
  static void _onMessage(RemoteMessage message) {
    print('📲 Foreground notification: ${message.notification?.title}');
    if (message.notification != null) {
      showNotification(
        title: message.notification!.title ?? 'Notificación',
        body: message.notification!.body ?? '',
        payload: message.data['tipo'],
      );
    }
  }

  /// Listener tap
  static void _onMessageOpenedApp(RemoteMessage message) {
    print('👆 Notification tapped: ${message.data}');
    _handleNotificationTap(message.data['tipo']);
  }

  static void _handleNotificationTap(String? tipo) {
    if (tipo == null) return;
    if (tipo == 'cita') {
      print('➡️ Abrir pantalla de citas');
      // Aquí puedes usar navigatorKey o Provider/Bloc para abrir la pantalla
    }
  }
}

/// ⚠️ Handler para background/terminated
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('📱 Background notification: ${message.messageId}');

  // Inicializar local notifications (solo una vez en background)
  const AndroidInitializationSettings androidSettings =
      AndroidInitializationSettings('@drawable/ic_notification');
  const InitializationSettings settings = InitializationSettings(
    android: androidSettings,
  );
  final FlutterLocalNotificationsPlugin plugin =
      FlutterLocalNotificationsPlugin();
  await plugin.initialize(settings);

  // Crear canal
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    NotificationService._channelId,
    NotificationService._channelName,
    description: NotificationService._channelDescription,
    importance: Importance.max,
  );
  await plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(channel);

  // Mostrar notificación
  if (message.notification != null) {
    await plugin.show(
      0,
      message.notification!.title ?? 'Notificación',
      message.notification!.body ?? '',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          NotificationService._channelId,
          NotificationService._channelName,
          channelDescription: NotificationService._channelDescription,
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          ticker: 'ticker',
        ),
      ),
    );
  }
}
