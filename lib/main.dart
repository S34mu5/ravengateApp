import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'screens/auth/login/login_screen.dart';
import 'screens/home/home_screen.dart';
import 'services/auth/biometric_auth_service.dart';
import 'services/auth/google_auth_service.dart';
import 'services/auth/email_password_auth_service.dart';
import 'controllers/auth_controller.dart';
import 'screens/auth/email_verification/email_verification_screen.dart';

// Referencia global al controlador de autenticación para acceder desde cualquier lugar
late AuthController authController;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize authentication services
  initializeAuthServices();

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

class MyApp extends StatelessWidget {
  final AuthController authController;

  const MyApp({
    required this.authController,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RavenGate App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
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
                          authController: authController,
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
                        authController: authController,
                      ),
                    ),
                  );
                },
              );
            }

            // Si está verificado o usó otro método, mostrar HomeScreen
            return HomeScreen(user: user);
          }

          return LoginScreen(authController: authController);
        },
      ),
    );
  }
}
