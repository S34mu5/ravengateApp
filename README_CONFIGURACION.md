# 🚪 RavenGate App - Guía de Configuración

## 📋 Prerrequisitos

Antes de comenzar, asegúrate de tener instalado:

- **Flutter SDK** (versión 3.0 o superior)
- **Node.js** y **npm** (para Firebase CLI)
- **Git**
- **Android Studio** (para desarrollo Android)
- **Xcode** (para desarrollo iOS, solo en macOS)

## 🚀 Configuración Inicial

### 1. Clonar el Repositorio

```bash
git clone <URL_DEL_REPOSITORIO>
cd ravengateApp
```

### 2. Instalar Dependencias de Flutter

```bash
flutter pub get
```

### 3. Verificar Instalación de Flutter

```bash
flutter doctor
```

## 🔥 Configuración de Firebase

### 1. Instalar Firebase CLI

```bash
npm install -g firebase-tools
```

### 2. Instalar FlutterFire CLI

```bash
dart pub global activate flutterfire_cli
```

### 3. Iniciar Sesión en Firebase

```bash
firebase login
```

### 4. Configurar el Proyecto Firebase

Ejecuta el siguiente comando y selecciona el proyecto **ravengateapp**:

```bash
# En Windows (si flutterfire no está en PATH)
C:\Users\%USERNAME%\AppData\Local\Pub\Cache\bin\flutterfire.bat configure

# En macOS/Linux (si está en PATH)
flutterfire configure
```

**Opciones recomendadas:**

- Seleccionar proyecto: **ravengateapp**
- Plataformas: **Android, iOS, Web, Windows** (según necesites)

Este comando generará automáticamente el archivo `lib/firebase_options.dart` con la configuración correcta.

### 5. Verificar Configuración

Asegúrate de que el archivo `lib/firebase_options.dart` se haya creado correctamente.

## 📱 Configuración por Plataforma

### Android

1. **Archivo google-services.json:**

   - Descarga el archivo desde Firebase Console
   - Colócalo en `android/app/google-services.json`

2. **Configurar build.gradle:**
   - El proyecto ya debería estar configurado
   - Verifica que las dependencias de Firebase estén en `android/app/build.gradle`

### iOS

1. **Archivo GoogleService-Info.plist:**

   - Descarga el archivo desde Firebase Console
   - Colócalo en `ios/Runner/GoogleService-Info.plist`

2. **Configurar en Xcode:**
   - Abre `ios/Runner.xcworkspace`
   - Arrastra el archivo `GoogleService-Info.plist` al proyecto

### Web

La configuración se maneja automáticamente a través de `firebase_options.dart`.

## 🔐 Configuración de Autenticación

### Google Sign-In

1. **Android:**

   - El SHA-1 ya debería estar configurado en Firebase Console
   - Si tienes problemas, regenera el SHA-1:

   ```bash
   cd android
   ./gradlew signingReport
   ```

2. **iOS:**
   - Asegúrate de que el Bundle ID coincida con el configurado en Firebase
   - Verifica la configuración en `ios/Runner/Info.plist`

### Autenticación Biométrica

Las dependencias ya están incluidas en `pubspec.yaml`. No requiere configuración adicional.

## 🗄️ Configuración de Base de Datos

### MySQL (Opcional)

Si tu proyecto usa MySQL localmente:

1. Instala MySQL Server
2. Configura la base de datos según los scripts en `/database` (si existen)
3. Actualiza las credenciales de conexión en el código

## 🛠️ Comandos Útiles

### Ejecutar la Aplicación

```bash
# Android
flutter run -d android

# iOS
flutter run -d ios

# Web
flutter run -d chrome

# Windows
flutter run -d windows
```

### Limpiar Proyecto

```bash
flutter clean
flutter pub get
```

### Generar APK/Bundle

```bash
# APK de Debug
flutter build apk --debug

# APK de Release
flutter build apk --release

# Android App Bundle
flutter build appbundle --release
```

### Generar para iOS

```bash
# Solo en macOS
flutter build ios --release
```

## ⚠️ Solución de Problemas Comunes

### Error: "Target of URI doesn't exist: 'firebase_options.dart'"

**Solución:** Ejecuta `flutterfire configure` nuevamente.

### Error: "DefaultFirebaseOptions" no encontrado

**Solución:**

1. Verifica que `firebase_options.dart` exista
2. Ejecuta `flutter clean && flutter pub get`
3. Si persiste, ejecuta `flutterfire configure` nuevamente

### Problemas con Google Sign-In en Android

**Solución:**

1. Verifica el SHA-1 en Firebase Console
2. Asegúrate de que `google-services.json` esté actualizado
3. Limpia y reconstruye el proyecto

### Problemas con Permisos de Notificaciones

**Solución:**

1. Verifica permisos en `android/app/src/main/AndroidManifest.xml`
2. Para iOS, verifica `ios/Runner/Info.plist`

### Flutter Doctor Issues

**Solución:**

```bash
flutter doctor --android-licenses  # Acepta las licencias de Android
flutter doctor -v                  # Diagnóstico detallado
```

## 📚 Estructura del Proyecto

```
lib/
├── main.dart                 # Punto de entrada
├── firebase_options.dart     # Configuración de Firebase
├── controllers/              # Controladores de lógica
├── services/                 # Servicios (Auth, Notifications, etc.)
├── screens/                  # Pantallas de la aplicación
├── common/                   # Componentes reutilizables
└── utils/                    # Utilidades
```

## 🔧 Variables de Entorno

El proyecto usa Firebase para configuración. No necesitas archivos `.env` adicionales.

## 🚦 Testing

```bash
# Ejecutar tests
flutter test

# Ejecutar tests de integración
flutter drive --target=test_driver/app.dart
```

## 📞 Soporte

Si encuentras problemas durante la configuración:

1. Revisa que todos los prerrequisitos estén instalados
2. Verifica que Firebase esté correctamente configurado
3. Ejecuta `flutter doctor` para diagnosticar problemas
4. Revisa los logs de error en detalle

## 🎯 Próximos Pasos

Después de completar la configuración:

1. Ejecuta `flutter run` para probar la aplicación
2. Verifica que la autenticación funcione correctamente
3. Prueba las notificaciones y servicios de Firebase
4. Configura el entorno de producción si es necesario

---

¡Listo! 🎉 Tu aplicación RavenGate debería estar funcionando correctamente.
