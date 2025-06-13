import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/auth/google_auth_service.dart';
import '../auth/login/login_screen.dart';
import 'home_screen_ui.dart';
import '../../main.dart' as app;
import '../../services/cache/cache_service.dart';
import '../../utils/logger.dart';

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
    AppLogger.debug(
        'Construyendo HomeScreen para usuario: ${user.email ?? "desconocido"}');
    return HomeScreenUI(
      user: user,
      onLogout: () async {
        AppLogger.debug(
            'Iniciando logout para usuario: ${user.email ?? "desconocido"}');
        try {
          await _authService.signOut();
          AppLogger.info(
              'Logout exitoso para usuario: ${user.email ?? "desconocido"}');

          // Limpiar la caché al cerrar sesión
          AppLogger.debug('Limpiando caché de datos');
          await CacheService.clearCache();
          AppLogger.info('Caché limpiada');

          if (context.mounted) {
            // Reinicializar servicios para prevenir errores de estado inconsistente
            AppLogger.debug('Reinicializando servicios de autenticación');
            app.initializeAuthServices();

            AppLogger.debug('Navegando a LoginScreen tras logout');
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
          AppLogger.error('Error al cerrar sesión', e);
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
