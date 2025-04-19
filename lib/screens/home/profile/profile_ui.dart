import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../services/cache/cache_service.dart';

/// Widget que muestra la interfaz de usuario para la pantalla de perfil
class ProfileUI extends StatefulWidget {
  final User user;
  final VoidCallback onLogout;

  const ProfileUI({
    required this.user,
    required this.onLogout,
    super.key,
  });

  @override
  State<ProfileUI> createState() => _ProfileUIState();
}

class _ProfileUIState extends State<ProfileUI> {
  bool _norwegianEquivalenceEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadNorwegianPreference();
  }

  Future<void> _loadNorwegianPreference() async {
    final isEnabled = await CacheService.getNorwegianEquivalencePreference();
    setState(() {
      _norwegianEquivalenceEnabled = isEnabled;
    });
  }

  @override
  Widget build(BuildContext context) {
    print(
        'LOG: Construyendo UI de perfil para usuario: ${widget.user.displayName ?? "sin nombre"} (${widget.user.email ?? "sin email"})');
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 60,
            backgroundImage: widget.user.photoURL != null
                ? NetworkImage(widget.user.photoURL!)
                : null,
            child: widget.user.photoURL == null
                ? const Icon(Icons.person, size: 60)
                : null,
          ),
          const SizedBox(height: 24),
          Text(
            widget.user.displayName ?? 'User',
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            widget.user.email ?? '',
            style: const TextStyle(fontSize: 18, color: Colors.grey),
          ),
          const SizedBox(height: 32),
          // Preferencias del usuario
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Preferences',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Norwegian Airlines DY/D8 Equivalence'),
                  subtitle: const Text(
                      'Show flights with DY code when searching for D8 and vice versa'),
                  value: _norwegianEquivalenceEnabled,
                  activeColor: Colors.blue,
                  onChanged: (bool value) async {
                    setState(() {
                      _norwegianEquivalenceEnabled = value;
                    });
                    await CacheService.saveNorwegianEquivalencePreference(
                        value);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          OutlinedButton.icon(
            onPressed: () {
              print(
                  'LOG: Usuario pulsó el botón de logout en la pantalla de perfil');
              widget.onLogout();
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
