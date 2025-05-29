import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'screens/auth/login/login_screen.dart';
import 'services/auth/biometric_auth_service.dart';
import 'services/auth/google_auth_service.dart';
import 'services/auth/email_password_auth_service.dart';
import 'controllers/auth_controller.dart';
import 'screens/auth/email_verification/email_verification_screen.dart';
import 'services/notifications/notification_service.dart';
import 'services/gate/gate_monitor_service.dart';
import 'screens/location/select_location_screen.dart';
import 'l10n/app_localizations.dart';
import 'services/localization/language_service.dart';

// Referencia global al controlador de autenticación para acceder desde cualquier lugar
late AuthController authController;
// Referencia global al servicio de monitoreo de cambios de puerta
late GateMonitorService gateMonitorService;
// Referencia global para cambiar idioma desde cualquier lugar
late Function(String) changeAppLanguage;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize authentication services
  initializeAuthServices();

  // Initialize notification service
  await initializeNotificationService();

  // Initialize gate monitoring service
  await initializeGateMonitorService();

  runApp(MyApp(authController: authController));
}

/// Inicializa o reinicializa los servicios de autenticación
void initializeAuthServices() {
  print('🔄 Inicializando servicios de autenticación...');
  final authServices = [
    BiometricAuthService(),
    GoogleAuthService(),
    EmailPasswordAuthService(),
  ];

  // Create the controller with the services
  authController = AuthController(authServices);
}

/// Inicializa el servicio de notificaciones
Future<void> initializeNotificationService() async {
  try {
    print('🔔 Inicializando servicio de notificaciones...');
    final notificationService = NotificationService();
    await notificationService.init();

    // Solicitar permisos para notificaciones
    final hasPermission = await notificationService.requestPermissions();
    print('✅ Servicio de notificaciones inicializado correctamente');
    print(
        '📱 Permisos de notificaciones: ${hasPermission ? 'concedidos' : 'denegados'}');
  } catch (e) {
    print('❌ Error al inicializar el servicio de notificaciones: $e');
  }
}

/// Inicializa el servicio de monitoreo de cambios de puerta
Future<void> initializeGateMonitorService() async {
  try {
    print('🚪 Inicializando servicio de monitoreo de cambios de puerta...');
    gateMonitorService = GateMonitorService();
    await gateMonitorService.initialize();

    // Escuchar cambios en el estado de autenticación para iniciar/detener monitoreo
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (user != null) {
        // Usuario autenticado, iniciar monitoreo
        print(
            '👤 Usuario autenticado, iniciando monitoreo de cambios de puerta');
        gateMonitorService.startMonitoring();
      } else {
        // Usuario desconectado, detener monitoreo
        print(
            '👤 Usuario desconectado, deteniendo monitoreo de cambios de puerta');
        gateMonitorService.stopMonitoring();
      }
    });

    print(
        '✅ Servicio de monitoreo de cambios de puerta inicializado correctamente');
  } catch (e) {
    print(
        '❌ Error al inicializar el servicio de monitoreo de cambios de puerta: $e');
  }
}

class MyApp extends StatefulWidget {
  final AuthController authController;

  const MyApp({
    required this.authController,
    super.key,
  });

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Locale? _currentLocale;

  @override
  void initState() {
    super.initState();
    _loadSavedLanguage();
  }

  /// Cargar el idioma guardado en las preferencias
  Future<void> _loadSavedLanguage() async {
    final savedLocale = await LanguageService.getSavedLanguage();
    setState(() {
      _currentLocale = savedLocale;
    });
  }

  /// Cambiar el idioma de la aplicación
  Future<void> changeLanguage(String languageCode) async {
    final success = await LanguageService.saveLanguage(languageCode);
    if (success) {
      setState(() {
        _currentLocale = Locale(languageCode);
      });
      print('LOG: Idioma cambiado a: $languageCode');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Si aún no se ha cargado el idioma, mostrar loading
    if (_currentLocale == null) {
      return const MaterialApp(
        home: Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    // Asignar la función global para cambiar idioma
    changeAppLanguage = changeLanguage;

    return MaterialApp(
      title: 'RavenGate App',
      // Configuración de internacionalización
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: _currentLocale,
      // Callback para cuando el sistema cambia el idioma
      localeResolutionCallback: (locale, supportedLocales) {
        // Si el idioma del sistema es soportado, usarlo
        if (locale != null) {
          for (var supportedLocale in supportedLocales) {
            if (supportedLocale.languageCode == locale.languageCode) {
              return supportedLocale;
            }
          }
        }
        // Fallback al primer idioma soportado (español)
        return supportedLocales.first;
      },
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4285F4), // Google Blue
          brightness: Brightness.light,
          // Colores principales
          primary: const Color(0xFF4285F4), // Google Blue
          onPrimary: Colors.white,
          primaryContainer: const Color(0xFFD2E3FC),
          onPrimaryContainer: const Color(0xFF062E6F),
          // Colores secundarios
          secondary: const Color(0xFF34A853), // Google Green
          onSecondary: Colors.white,
          secondaryContainer: const Color(0xFFCEEAD6),
          onSecondaryContainer: const Color(0xFF0F401B),
          // Colores de error
          error: const Color(0xFFEA4335), // Google Red
          onError: Colors.white,
          errorContainer: const Color(0xFFFDE7E7),
          onErrorContainer: const Color(0xFF5F1616),
          // Colores de superficie
          surface: Colors.white,
          onSurface: const Color(0xFF202124), // Google Gray 900
          surfaceVariant: const Color(0xFFF1F3F4), // Google Gray 100
          onSurfaceVariant: const Color(0xFF5F6368), // Google Gray 500
          outline: const Color(0xFFDADCE0), // Google Gray 200
        ),
        // Tipografía de Google Sans
        fontFamily: 'Roboto',
        textTheme: const TextTheme(
          displayLarge: TextStyle(fontSize: 57, fontWeight: FontWeight.w400),
          displayMedium: TextStyle(fontSize: 45, fontWeight: FontWeight.w400),
          displaySmall: TextStyle(fontSize: 36, fontWeight: FontWeight.w400),
          headlineLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w400),
          headlineMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w400),
          headlineSmall: TextStyle(fontSize: 24, fontWeight: FontWeight.w400),
          titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w500),
          titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
          bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
          bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
          labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
        ),
        // Estilos de componentes
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF202124), // Negro Google
          elevation: 0,
          centerTitle: false,
          iconTheme: IconThemeData(
            color: Color(0xFF202124), // Negro Google para íconos
          ),
          actionsIconTheme: IconThemeData(
            color: Color(0xFF202124), // Negro Google para íconos de acciones
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4285F4), // Google Blue
            foregroundColor: Colors.white,
            elevation: 2,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        cardTheme: CardTheme(
          elevation: 1,
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        dividerTheme: const DividerThemeData(
          thickness: 1,
          color: Color(0xFFE8EAED), // Google Gray 200
        ),
        // Material 3
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4285F4), // Google Blue
          brightness: Brightness.dark,
          // Colores principales en tema oscuro
          primary: const Color(0xFF8AB4F8), // Google Blue claro para oscuridad
          onPrimary: const Color(0xFF0D2C54),
          primaryContainer: const Color(0xFF3C4043), // Google Gray 800
          onPrimaryContainer: const Color(0xFFD2E3FC),
          // Colores secundarios
          secondary:
              const Color(0xFF81C995), // Google Green claro para oscuridad
          onSecondary: const Color(0xFF0F3B20),
          secondaryContainer: const Color(0xFF2D3130),
          onSecondaryContainer: const Color(0xFFCEEAD6),
          // Colores de error
          error: const Color(0xFFF28B82), // Google Red claro para oscuridad
          onError: const Color(0xFF601410),
          errorContainer: const Color(0xFF3D2222),
          onErrorContainer: const Color(0xFFF8D9D9),
          // Colores de superficie
          surface: const Color(0xFF202124), // Google Gray 900
          onSurface: const Color(0xFFE8EAED), // Google Gray 200
          surfaceVariant: const Color(0xFF3C4043), // Google Gray 800
          onSurfaceVariant: const Color(0xFFDADCE0), // Google Gray 300
          outline: const Color(0xFF5F6368), // Google Gray 500
        ),
        // Tipografía de Google Sans para tema oscuro
        fontFamily: 'Roboto',
        // Estilos para tema oscuro
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF202124), // Google Gray 900
          foregroundColor: Colors.white, // Blanco para texto en modo oscuro
          elevation: 0,
          centerTitle: false,
          iconTheme: IconThemeData(
            color: Colors.white, // Blanco para íconos en modo oscuro
          ),
          actionsIconTheme: IconThemeData(
            color:
                Colors.white, // Blanco para íconos de acciones en modo oscuro
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF8AB4F8), // Google Blue claro
            foregroundColor: const Color(0xFF202124),
            elevation: 2,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        cardTheme: CardTheme(
          color: const Color(0xFF303134), // Google Gray 850
          elevation: 1,
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        dividerTheme: const DividerThemeData(
          thickness: 1,
          color: Color(0xFF3C4043), // Google Gray 800
        ),
        // Material 3
        useMaterial3: true,
      ),
      themeMode: ThemeMode.light, // Usar siempre tema claro
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasData && snapshot.data != null) {
            // Verificar si el usuario está verificado
            final user = snapshot.data!;

            // Si el usuario inició sesión con email/password y no está verificado
            // NO cerramos la sesión, permitimos que siga el flujo y el LoginScreen maneje esto
            if (user.providerData
                    .any((info) => info.providerId == 'password') &&
                !user.emailVerified) {
              print('⚠️ User not verified in main.dart: ${user.email}');

              // Verificar si es un registro reciente (menos de 30 segundos)
              final creationTime = user.metadata.creationTime;
              final now = DateTime.now();
              if (creationTime != null &&
                  now.difference(creationTime).inSeconds < 30) {
                print(
                    '👤 Usuario recién creado, mostrando pantalla de verificación con estilo de registro nuevo');

                // Mostrar la pantalla con el icono verde para usuarios recién registrados
                return EmailVerificationScreen(
                  email: user.email,
                  isNewRegistration:
                      true, // Pantalla verde para nuevos registros
                  onBackToLogin: () {
                    // Solo cerrar sesión cuando el usuario presione el botón "Back to Login"
                    FirebaseAuth.instance.signOut();
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (context) => LoginScreen(
                          authController: widget.authController,
                        ),
                      ),
                    );
                  },
                );
              }

              // Si no es un registro reciente, mostrar la pantalla de verificación amarilla
              return EmailVerificationScreen(
                email: user.email,
                isNewRegistration:
                    false, // Pantalla amarilla para intentos de login
                onBackToLogin: () {
                  // Solo cerrar sesión cuando el usuario presione el botón "Back to Login"
                  FirebaseAuth.instance.signOut();
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (context) => LoginScreen(
                        authController: widget.authController,
                      ),
                    ),
                  );
                },
              );
            }

            // Si está verificado o usó otro método, mostrar la pantalla de selección de ubicación
            return SelectLocationScreen(user: user);
          }

          return LoginScreen(authController: widget.authController);
        },
      ),
    );
  }
}
