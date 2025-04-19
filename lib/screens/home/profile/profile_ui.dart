import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Widget que muestra la interfaz de usuario para la pantalla de perfil
class ProfileUI extends StatelessWidget {
  final User user;
  final VoidCallback onLogout;

  const ProfileUI({
    required this.user,
    required this.onLogout,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    print(
        'LOG: Construyendo UI de perfil para usuario: ${user.displayName ?? "sin nombre"} (${user.email ?? "sin email"})');
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 60,
            backgroundImage:
                user.photoURL != null ? NetworkImage(user.photoURL!) : null,
            child: user.photoURL == null
                ? const Icon(Icons.person, size: 60)
                : null,
          ),
          const SizedBox(height: 24),
          Text(
            user.displayName ?? 'User',
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            user.email ?? '',
            style: const TextStyle(fontSize: 18, color: Colors.grey),
          ),
          const SizedBox(height: 32),
          OutlinedButton.icon(
            onPressed: () {
              print(
                  'LOG: Usuario pulsó el botón de logout en la pantalla de perfil');
              onLogout();
            },
            icon: const Icon(Icons.logout),
            label: const Text('Log Out'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}
