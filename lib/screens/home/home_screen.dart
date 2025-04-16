import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/auth/google_auth_service.dart';
import '../../services/auth/biometric_auth_service.dart';
import '../auth/login/login_screen.dart';
import '../../controllers/auth_controller.dart';
import 'home_screen_ui.dart';
import '../../main.dart' as app;

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
    return HomeScreenUI(
      user: user,
      onLogout: () async {
        try {
          await _authService.signOut();
          if (context.mounted) {
            // Reinicializar servicios para prevenir errores de estado inconsistente
            app.initializeAuthServices();

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
