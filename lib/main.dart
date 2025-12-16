import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:timezone/data/latest.dart' as tz;

import 'firebase_options.dart';
//import './firebase_background_handler.dart'
//    as fbHandler; // 🔹 Import obligatorio
//import 'servicios/notification_service.dart';
import 'api.dart';
import 'pantallas/autenticacion/pantalla_login.dart';
import 'pantallas/principal/pantalla_principal.dart';

import 'servicios/notification_service.dart' as notif;

import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Pedir permisos en Android 13+
  if (Platform.isAndroid) {
    var status = await Permission.notification.status;
    if (!status.isGranted) {
      await Permission.notification.request();
    }
  }

  FirebaseMessaging.onBackgroundMessage(
    notif.firebaseMessagingBackgroundHandler,
  );

  tz.initializeTimeZones();

  await notif.NotificationService.initialize();

  // Inicializar servicio de notificaciones
  //await ServicioNotificaciones.inicializar();

  runApp(const ClinicaApp());
}

class ClinicaApp extends StatelessWidget {
  const ClinicaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Clínica',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
      home: const AuthGate(),
    );
  }
}

/// AuthGate considera logueado si hay token.
/// Si existe /api/me/ lo usa; si falla, usa el "user" guardado en el login.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool loading = true;
  bool logged = false;
  Map<String, dynamic>? me;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    // 1) si hay token damos por logueado
    final token = await storage.read(key: 'access');
    if (token != null) {
      // 🔔 REGISTRA (o refresca) EL TOKEN FCM
      await notif.NotificationService.registerDeviceAfterLogin();
      // 2) intentamos /api/me/
      try {
        final res = await ApiAuth.me();
        if (res['ok'] == true) {
          me = res['data'];
        } else {
          // 3) respaldo: user guardado en el login
          me = await ApiAuth.getStoredUser();
        }
      } catch (_) {
        me = await ApiAuth.getStoredUser();
      }
      setState(() {
        loading = false;
        logged = true;
      });
      return;
    }

    // sin token -> no logueado
    setState(() {
      loading = false;
      logged = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return logged ? PantallaPrincipal(me: me) : const PantallaLogin();
  }
}
