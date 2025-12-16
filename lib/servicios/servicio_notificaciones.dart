import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:io';
import '../api.dart';

/// Handler para notificaciones en background (debe estar fuera de cualquier clase)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print(
    '📱 Notificación recibida en background: ${message.notification?.title}',
  );

  // Aquí puedes procesar la notificación en background
  // Por ejemplo, guardar en base de datos local, actualizar badges, etc.

  // Mostrar notificación local si es necesario
  if (message.notification != null) {
    await ServicioNotificaciones.mostrarNotificacionBackground(message);
  }
}

class ServicioNotificaciones {
  static final FirebaseMessaging _firebaseMessaging =
      FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static bool _inicializado = false;
  static String? _tokenFCM;
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String _tokenKey = 'fcm_token';

  /// Inicializar el servicio de notificaciones
  static Future<bool> inicializar() async {
    if (_inicializado) return true;

    try {
      // Solicitar permisos de Firebase
      NotificationSettings settings = await _firebaseMessaging
          .requestPermission(
            alert: true,
            announcement: false,
            badge: true,
            carPlay: false,
            criticalAlert: false,
            provisional: false,
            sound: true,
          );

      // Solicitar permisos de notificaciones locales
      await _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();

      if (settings.authorizationStatus != AuthorizationStatus.authorized) {
        print('❌ Permisos de notificaciones denegados');
        return false;
      }

      // Configurar notificaciones locales
      await _configurarNotificacionesLocales();

      // Obtener token FCM
      _tokenFCM = await _firebaseMessaging.getToken();
      print('🔑 Token FCM: $_tokenFCM');

      // Guardar token localmente para registrar después del login
      if (_tokenFCM != null) {
        await _guardarTokenLocalmente(_tokenFCM!);
        print('📱 Token FCM guardado localmente para registro posterior');
      }

      // Configurar handlers de mensajes
      await _configurarHandlers();

      // Configurar para recibir notificaciones en primer plano
      await _firebaseMessaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // Escuchar cambios de token
      _firebaseMessaging.onTokenRefresh.listen((newToken) {
        _tokenFCM = newToken;
        _guardarTokenLocalmente(newToken);
        print('🔄 Token FCM actualizado y guardado localmente');
      });

      _inicializado = true;
      print('✅ Servicio de notificaciones inicializado');
      return true;
    } catch (e) {
      print('❌ Error inicializando notificaciones: $e');
      return false;
    }
  }

  /// Configurar notificaciones locales
  static Future<void> _configurarNotificacionesLocales() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsIOS,
        );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Crear canal de notificaciones para Android
    if (!kIsWeb) {
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'clinica_channel',
        'Notificaciones de Clínica',
        description: 'Canal para notificaciones de la aplicación de clínica',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        showBadge: true,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(channel);
    }
  }

  /// Configurar handlers de mensajes FCM
  static Future<void> _configurarHandlers() async {
    // Mensaje cuando la app está en foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print(
        '📱 Mensaje recibido en foreground: ${message.notification?.title}',
      );

      print('🔥🔥🔥 MENSAJE FCM RECIBIDO 🔥🔥🔥');
      print('📱 Título: ${message.notification?.title}');
      print('📱 Cuerpo: ${message.notification?.body}');
      print('📱 Datos: ${message.data}');
      print('🔥🔥🔥 FIN MENSAJE FCM 🔥🔥🔥');

      _mostrarNotificacionLocal(message);
    });

    // Mensaje cuando la app está en background pero no terminada
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print(
        '📱 App abierta desde notificación: ${message.notification?.title}',
      );
      _manejarTapNotificacion(message.data);
    });

    // Verificar si la app fue abierta desde una notificación
    RemoteMessage? initialMessage = await _firebaseMessaging
        .getInitialMessage();
    if (initialMessage != null) {
      print(
        '📱 App iniciada desde notificación: ${initialMessage.notification?.title}',
      );
      _manejarTapNotificacion(initialMessage.data);
    }
  }

  /// Mostrar notificación local cuando la app está en foreground
  static Future<void> _mostrarNotificacionLocal(RemoteMessage message) async {
    print('🔔 Mostrando notificación local: ${message.notification?.title}');

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'clinica_channel',
          'Notificaciones de Clínica',
          channelDescription:
              'Canal para notificaciones de la aplicación de clínica',
          importance: Importance.high,
          priority: Priority.high,
          showWhen: true,
        );

    /*'clinica_channel',
      'Notificaciones de Clínica',
      channelDescription: 'Canal para notificaciones de la aplicación de clínica',
      importance: Importance.max,
      priority: Priority.max,
      showWhen: true,
      enableVibration: true,
      playSound: true,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.message,
      ticker: 'Nueva notificación de clínica',
    );*/

    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    await _localNotifications.show(
      message.hashCode,
      message.notification?.title ?? 'Notificación',
      message.notification?.body ?? '',
      platformChannelSpecifics,
      payload: message.data.toString(),
    );
  }

  /// Manejar tap en notificación local
  static void _onNotificationTap(NotificationResponse response) {
    print('📱 Tap en notificación local: ${response.payload}');
    // Aquí puedes agregar navegación específica
  }

  /// Manejar tap en notificación FCM
  static void _manejarTapNotificacion(Map<String, dynamic> data) {
    print('📱 Datos de notificación: $data');

    final tipo = data['tipo'];
    final id = data['cita_id'] ?? data['examen_id'];

    // Aquí puedes implementar navegación específica según el tipo
    switch (tipo) {
      case 'cita':
        print('🏥 Navegar a cita: $id');
        // Implementar navegación a detalles de cita
        break;
      case 'examen':
        print('🧪 Navegar a examen: $id');
        // Implementar navegación a resultados de examen
        break;
      default:
        print('📋 Navegar a notificaciones generales');
        // Implementar navegación a lista de notificaciones
        break;
    }
  }

  /// Registrar token FCM en el backend
  static Future<void> _registrarTokenEnBackend(String token) async {
    try {
      final res = await ApiNotificaciones.registrarDispositivo(token);
      print('✅ RES: $res');
      if (res['ok'] == true) {
        print('✅ Token FCM registrado en backend');
      } else {
        print('❌ Error registrando token: ${res['error']}');
      }
    } catch (e) {
      print('❌ Error registrando token en backend: $e');
    }
  }

  /// Verificar si las notificaciones están habilitadas
  static Future<bool> notificacionesHabilitadas() async {
    NotificationSettings settings = await _firebaseMessaging
        .getNotificationSettings();
    return settings.authorizationStatus == AuthorizationStatus.authorized;
  }

  /// Solicitar permisos de notificaciones
  static Future<bool> solicitarPermisos() async {
    NotificationSettings settings = await _firebaseMessaging
        .requestPermission();
    return settings.authorizationStatus == AuthorizationStatus.authorized;
  }

  /// Cancelar todas las notificaciones locales
  static Future<void> cancelarTodasLasNotificaciones() async {
    await _localNotifications.cancelAll();
  }

  /// Programar notificación local (para recordatorios)
  static Future<void> programarRecordatorio({
    required int id,
    required String titulo,
    required String mensaje,
    required DateTime fechaHora,
  }) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'clinica_channel',
          'Notificaciones de Clínica',
          channelDescription: 'Recordatorios de citas y exámenes',
          importance: Importance.max,
          priority: Priority.max,
          enableVibration: true,
          playSound: true,
          fullScreenIntent: true,
          category: AndroidNotificationCategory.reminder,
        );

    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails();

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    // Convertir DateTime a TZDateTime usando la zona horaria local
    final tz.TZDateTime scheduledDate = tz.TZDateTime.from(fechaHora, tz.local);

    await _localNotifications.zonedSchedule(
      id,
      titulo,
      mensaje,
      scheduledDate,
      platformChannelSpecifics,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      //uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// Cancelar notificación programada
  static Future<void> cancelarNotificacion(int id) async {
    await _localNotifications.cancel(id);
  }

  // ==================== REGISTRO DE DISPOSITIVOS FCM ====================

  /// Registrar dispositivo para notificaciones push
  static Future<void> registrarDispositivo() async {
    try {
      // 1. Obtener el token FCM
      String? token = await _firebaseMessaging.getToken();

      if (token != null) {
        print('📱 Token FCM obtenido: ${token.substring(0, 20)}...');
        print('📱 Token FCM FCM: 8888888');

        await _registrarTokenEnBackend(token);

        // 2. Guardar token localmente
        await _guardarTokenLocalmente(token);
        _tokenFCM = token;

        // 3. Enviar al servidor si usuario está logueado
        if (await _usuarioLogueado()) {
          await _enviarTokenAlServidor(token);
        }

        // 4. Configurar listeners
        _configurarListeners();
      }
    } catch (e) {
      print('❌ Error registrando dispositivo: $e');
    }
  }

  /// Registrar dispositivo después del login
  static Future<void> registrarDispositivoDespuesLogin() async {
    try {
      print('🔄 Iniciando registro de dispositivo después del login...');

      // Recuperar token guardado localmente
      String? tokenGuardado = await _obtenerTokenGuardado();
      print('TokenToken: $tokenGuardado');

      if (tokenGuardado != null) {
        print('📱 Usando token guardado: ${tokenGuardado.substring(0, 20)}...');
        await _enviarTokenAlServidor(tokenGuardado);
      } else {
        print('⚠️ No hay token guardado, obteniendo uno nuevo...');
        // Si no hay token guardado, obtener uno nuevo
        await registrarDispositivo();
      }
      //await registrarDispositivo();
    } catch (e) {
      print('❌ Error registrando dispositivo después del login: $e');
    }
  }

  /// Enviar token FCM al servidor Django
  static Future<void> _enviarTokenAlServidor(String token) async {
    try {
      final userToken = await storage.read(key: 'access');

      if (userToken == null) {
        print('⚠️ No hay token de usuario, no se puede registrar dispositivo');
        return;
      }

      final response = await ApiNotificaciones.registrarDispositivo(token);

      if (response['ok'] == true) {
        print('✅ Dispositivo registrado en servidor');
      } else {
        print('❌ Error registrando dispositivo: ${response['error']}');
      }
    } catch (e) {
      print('❌ Error enviando token al servidor: $e');
    }
  }

  /// Obtener plataforma del dispositivo
  static Future<String> _obtenerPlataforma() async {
    if (Platform.isAndroid) {
      return 'android';
    } else if (Platform.isIOS) {
      return 'ios';
    } else {
      return 'unknown';
    }
  }

  /// Verificar si el usuario está logueado
  static Future<bool> _usuarioLogueado() async {
    final token = await storage.read(key: 'access');
    return token != null;
  }

  /// Guardar token FCM localmente
  static Future<void> _guardarTokenLocalmente(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }

  /// Obtener token FCM guardado localmente
  static Future<String?> _obtenerTokenGuardado() async {
    return await _storage.read(key: _tokenKey);
  }

  /// Configurar listeners adicionales
  static void _configurarListeners() {
    // Los listeners principales ya están configurados en _configurarHandlers()
    // Este método se mantiene para compatibilidad pero no agrega listeners duplicados
    print('📡 Listeners de FCM ya configurados');
  }

  /// Mostrar notificación local cuando la app está en primer plano
  static Future<void> _mostrarNotificacionLocalPush(
    RemoteMessage message,
  ) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'clinica_channel',
          'Notificaciones de Clínica',
          channelDescription: 'Notificaciones push de la clínica',
          importance: Importance.max,
          priority: Priority.max,
          enableVibration: true,
          playSound: true,
          fullScreenIntent: true,
          category: AndroidNotificationCategory.message,
        );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails();

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      message.hashCode,
      message.notification?.title ?? 'Notificación',
      message.notification?.body ?? '',
      platformDetails,
    );
  }

  /// Manejar toque en notificación
  static void _manejarToqueNotificacion(Map<String, dynamic> data) {
    // Aquí puedes navegar a pantallas específicas según el tipo de notificación
    print('📱 Datos de notificación: $data');

    // Ejemplo de manejo según tipo
    if (data.containsKey('tipo')) {
      switch (data['tipo']) {
        case 'cita':
          // Navegar a pantalla de citas
          break;
        case 'resultado':
          // Navegar a pantalla de resultados
          break;
        case 'recordatorio':
          // Navegar a pantalla de recordatorios
          break;
        default:
          // Navegar a pantalla principal
          break;
      }
    }
  }

  /// Desactivar token FCM (logout)
  static Future<void> desactivarToken() async {
    try {
      final token = await _obtenerTokenGuardado();

      if (token != null) {
        // TODO: Implementar desactivarToken en la API
        print('⚠️ Método desactivarToken no implementado en la API');
      }

      // Limpiar token local
      await _storage.delete(key: _tokenKey);
      _tokenFCM = null;
    } catch (e) {
      print('❌ Error desactivando token: $e');
    }
  }

  /// Obtener token FCM actual
  static String? get tokenFCM => _tokenFCM;

  /// Método para probar notificaciones emergentes
  static Future<void> probarNotificacionEmergente() async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'clinica_channel',
          'Notificaciones de Clínica',
          channelDescription: 'Notificación de prueba',
          importance: Importance.max,
          priority: Priority.max,
          enableVibration: true,
          playSound: true,
          fullScreenIntent: true,
          category: AndroidNotificationCategory.message,
          ticker: 'Notificación de prueba',
        );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails();

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      999,
      '🔔 Prueba de Notificación',
      'Esta es una notificación de prueba para verificar que aparezca como emergente',
      platformDetails,
    );
  }

  /// Mostrar notificación cuando la app está en background
  static Future<void> mostrarNotificacionBackground(
    RemoteMessage message,
  ) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'clinica_channel',
          'Notificaciones de Clínica',
          channelDescription: 'Notificaciones push en background',
          importance: Importance.max,
          priority: Priority.max,
          enableVibration: true,
          playSound: true,
          fullScreenIntent: true,
          category: AndroidNotificationCategory.message,
          ticker: 'Nueva notificación',
        );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails();

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      message.hashCode,
      message.notification?.title ?? 'Notificación',
      message.notification?.body ?? 'Nueva notificación recibida',
      platformDetails,
      payload: message.data.toString(),
    );
  }
}
