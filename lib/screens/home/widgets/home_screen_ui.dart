import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Widget que maneja la UI de la pantalla principal
class HomeScreenUI extends StatelessWidget {
  final User user;
  final VoidCallback onLogout;

  const HomeScreenUI({
    required this.user,
    required this.onLogout,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('RavenGate'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: onLogout,
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              '¡Login Exitoso!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            CircleAvatar(
              radius: 40,
              backgroundImage:
                  user.photoURL != null ? NetworkImage(user.photoURL!) : null,
              child: user.photoURL == null
                  ? const Icon(Icons.person, size: 40)
                  : null,
            ),
            const SizedBox(height: 16),
            Text(
              'Bienvenido ${user.displayName ?? "Usuario"}',
              style: const TextStyle(fontSize: 18),
            ),
            Text(
              user.email ?? '',
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
