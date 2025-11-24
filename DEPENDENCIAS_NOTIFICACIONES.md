# Dependencias para Notificaciones

Para que el sistema de notificaciones funcione correctamente, necesitas agregar las siguientes dependencias al archivo `pubspec.yaml`:

## Dependencias requeridas

```yaml
dependencies:
  flutter:
    sdk: flutter
  
  # Dependencias existentes...
  http: ^1.1.0
  flutter_secure_storage: ^9.0.0
  intl: ^0.18.1
  
  # NUEVAS DEPENDENCIAS PARA NOTIFICACIONES
  firebase_core: ^2.24.2
  firebase_messaging: ^14.7.10
  flutter_local_notifications: ^16.3.2
  timezone: ^0.9.2

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.0
```

## Configuración adicional requerida

### 1. Android (android/app/build.gradle)

Agrega en `android/app/build.gradle`:

```gradle
android {
    compileSdkVersion 34
    
    defaultConfig {
        minSdkVersion 21  // Mínimo para notificaciones
        targetSdkVersion 34
    }
}
```

### 2. Android Manifest (android/app/src/main/AndroidManifest.xml)

Agrega los permisos necesarios:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    
    <!-- Permisos para notificaciones -->
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.WAKE_LOCK" />
    <uses-permission android:name="android.permission.VIBRATE" />
    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
    <uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" />
    
    <application
        android:label="Clínica Móvil"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher">
        
        <!-- Configuración para notificaciones -->
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED"/>
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
                <action android:name="android.intent.action.QUICKBOOT_POWERON" />
                <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>
            </intent-filter>
        </receiver>
        
        <!-- Configuración de Firebase -->
        <meta-data
            android:name="com.google.firebase.messaging.default_notification_icon"
            android:resource="@drawable/ic_notification" />
        <meta-data
            android:name="com.google.firebase.messaging.default_notification_color"
            android:resource="@color/colorAccent" />
        <meta-data
            android:name="com.google.firebase.messaging.default_notification_channel_id"
            android:value="clinica_channel" />
            
        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTop"
            android:theme="@style/LaunchTheme"
            android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
            android:hardwareAccelerated="true"
            android:windowSoftInputMode="adjustResize">
            
            <meta-data
              android:name="io.flutter.embedding.android.NormalTheme"
              android:resource="@style/NormalTheme"
              />
            <intent-filter android:autoVerify="true">
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
        </activity>
        
        <meta-data
            android:name="flutterEmbedding"
            android:value="2" />
    </application>
</manifest>
```

### 3. iOS (ios/Runner/Info.plist)

Para iOS, agrega en `ios/Runner/Info.plist`:

```xml
<dict>
    <!-- Configuración existente... -->
    
    <!-- Permisos para notificaciones -->
    <key>UIBackgroundModes</key>
    <array>
        <string>fetch</string>
        <string>remote-notification</string>
    </array>
    
    <!-- Configuración de notificaciones locales -->
    <key>NSUserNotificationAlertStyle</key>
    <string>alert</string>
</dict>
```

### 4. Configuración de Firebase

1. **Crear proyecto en Firebase Console** (https://console.firebase.google.com/)
2. **Agregar app Android e iOS** al proyecto
3. **Descargar archivos de configuración**:
   - `google-services.json` para Android → `android/app/`
   - `GoogleService-Info.plist` para iOS → `ios/Runner/`

### 5. Configuración del backend

El backend debe tener los archivos de credenciales de Firebase:
- Crear carpeta `firebase/` en el directorio raíz del proyecto Django
- Colocar `service-account-key.json` en esa carpeta
- Este archivo se obtiene desde Firebase Console → Configuración del proyecto → Cuentas de servicio

## Inicialización en la app

Agrega en `main.dart`:

```dart
import 'package:firebase_core/firebase_core.dart';
import 'servicios/servicio_notificaciones.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicializar Firebase
  await Firebase.initializeApp();
  
  // Inicializar servicio de notificaciones
  await ServicioNotificaciones.inicializar();
  
  runApp(const ClinicaApp());
}
```

## Funcionalidades implementadas

✅ **Pantalla de notificaciones** - Lista todas las notificaciones del usuario
✅ **APIs de notificaciones** - Comunicación con el backend
✅ **Servicio de notificaciones** - Manejo de FCM y notificaciones locales
✅ **Integración con pantalla principal** - Acceso desde el menú principal
✅ **Filtros y búsqueda** - Por tipo y estado de notificación
✅ **Marcar como leída** - Individual y todas a la vez
✅ **Datos mock** - Para testing sin backend

## Funcionalidades del backend implementadas

✅ **Servicio de notificaciones** - Envío via FCM y email
✅ **Notificaciones de citas** - Confirmación, cancelación, reprogramación
✅ **Notificaciones de exámenes** - Nuevos exámenes y resultados disponibles
✅ **Registro de dispositivos** - Para tokens FCM
✅ **Gestión de notificaciones** - CRUD completo

## Próximos pasos

1. Agregar las dependencias al `pubspec.yaml`
2. Configurar Firebase en el proyecto
3. Configurar los archivos de Android e iOS
4. Probar las notificaciones en dispositivo real
5. Integrar con el backend de notificaciones existente
