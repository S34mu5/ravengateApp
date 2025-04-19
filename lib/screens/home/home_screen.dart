import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/auth/google_auth_service.dart';
import '../../services/auth/biometric_auth_service.dart';
import '../auth/login/login_screen.dart';
import '../../controllers/auth_controller.dart';
import 'home_screen_ui.dart';
import '../../main.dart' as app;
import '../../services/cache/cache_service.dart';

/// Pantalla principal que se muestra después de un login exitoso
class HomeScreen extends StatelessWidget {
  final User user;
  final GoogleAuthService _authService = GoogleAuthService();

  HomeScreen({
    required this.user,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    print(
        'LOG: Construyendo HomeScreen para usuario: ${user.email ?? "desconocido"}');
    return HomeScreenUI(
      user: user,
      onLogout: () async {
        print(
            'LOG: Iniciando proceso de cierre de sesión para el usuario: ${user.email ?? "desconocido"}');
        try {
          await _authService.signOut();
          print(
              'LOG: Cierre de sesión exitoso para el usuario: ${user.email ?? "desconocido"}');

          // Limpiar la caché al cerrar sesión
          print('LOG: Limpiando caché de datos...');
          await CacheService.clearCache();
          print('LOG: Caché de datos limpiada exitosamente');

          if (context.mounted) {
            // Reinicializar servicios para prevenir errores de estado inconsistente
            print('LOG: Reinicializando servicios de autenticación');
            app.initializeAuthServices();

            print(
                'LOG: Navegando a la pantalla de login después del cierre de sesión');
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(
                builder: (context) => LoginScreen(
                  authController: app.authController,
                ),
              ),
              (route) => false,
            );
          }
        } catch (e) {
          print('LOG: Error al cerrar sesión: $e');
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error al cerrar sesión: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      },
    );
  }
}
