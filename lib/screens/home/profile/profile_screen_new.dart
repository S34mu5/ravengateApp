import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'profile_ui_new.dart';

/// Componente que maneja la lógica y los datos para la pantalla de perfil
class ProfileScreen extends StatelessWidget {
  final User user;
  final VoidCallback onLogout;

  const ProfileScreen({
    required this.user,
    required this.onLogout,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    // Aquí podrías agregar lógica adicional como:
    // - Cargar datos adicionales del perfil desde una base de datos
    // - Manejo de estados de edición
    // - Lógica de configuración de usuario
    // - Gestión de preferencias

    return ProfileUI(
      user: user,
      onLogout: onLogout,
    );
  }
}
