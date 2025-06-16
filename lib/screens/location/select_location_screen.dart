import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../screens/home/home_screen.dart';
import '../../screens/auth/login/login_screen.dart';
import '../../l10n/app_localizations.dart';
import '../../main.dart' as app;
import '../../utils/logger.dart';

class SelectLocationScreen extends StatefulWidget {
  final User user;

  const SelectLocationScreen({
    required this.user,
    Key? key,
  }) : super(key: key);

  @override
  State<SelectLocationScreen> createState() => _SelectLocationScreenState();
}

class _SelectLocationScreenState extends State<SelectLocationScreen> {
  bool _isLoading = false;

  Future<void> _selectLocation(String location) async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Guardar la selección en SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selected_location', location);

      if (!mounted) return;

      // Navegar a la pantalla principal
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => HomeScreen(user: widget.user),
        ),
      );
    } catch (e) {
      AppLogger.error(
          'SelectLocationScreen - Error al guardar la ubicación', e);
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _logout() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Cerrar sesión usando Firebase Auth directamente
      await FirebaseAuth.instance.signOut();

      if (!mounted) return;

      // Reinicializar servicios para prevenir errores de estado inconsistente
      app.initializeAuthServices();

      // Navegar a la pantalla de inicio de sesión
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => LoginScreen(
            authController: app.authController,
          ),
        ),
      );
    } catch (e) {
      AppLogger.error('SelectLocationScreen - Error al cerrar sesión', e);
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cerrar sesión: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Location'),
        automaticallyImplyLeading: false,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _buildLocationCard(
                        title: 'Bins',
                        icon: Icons.dashboard,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: _buildLocationCard(
                        title: 'Oversize',
                        icon: Icons.inventory_2,
                        color: Colors.amber,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Botón de logout
                    Center(
                      child: OutlinedButton.icon(
                        onPressed: _logout,
                        icon: const Icon(Icons.logout),
                        label: Text(localizations.logOut),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildLocationCard({
    required String title,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 1.5,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: () => _selectLocation(title),
        borderRadius: BorderRadius.circular(16),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                backgroundColor: color,
                radius: 40,
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 40,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
