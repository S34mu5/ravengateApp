import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../services/developer/developer_mode_service.dart';
import '../../../services/user/user_flights/user_flights_service.dart';
import '../../../utils/progress_dialog.dart';
import 'notifications_screen.dart'; // Importar la pantalla de notificaciones
import 'data_visualization_settings.dart'; // Importar la nueva pantalla de configuración
import 'language_settings_screen.dart'; // Importar la pantalla de configuración de idioma
import '../../../l10n/app_localizations.dart';
import '../../../utils/logger.dart';

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
  bool _developerModeEnabled = false;
  final TextEditingController _pinController = TextEditingController();
  int _pinAttempts = 0;

  @override
  void initState() {
    super.initState();
    _loadDeveloperModeStatus();
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _loadDeveloperModeStatus() async {
    final isEnabled = await DeveloperModeService.isDeveloperModeEnabled();
    setState(() {
      _developerModeEnabled = isEnabled;
    });

    if (!mounted) return;
  }

  Future<bool> _showPinDialog() async {
    // Resetear el controlador
    _pinController.clear();

    final bool? result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Developer Mode PIN'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter the developer PIN to continue:'),
            const SizedBox(height: 16),
            TextField(
              controller: _pinController,
              keyboardType: TextInputType.number,
              maxLength: 4,
              obscureText: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                counterText: '',
                hintText: '****',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final enteredPin = _pinController.text.trim();

              if (DeveloperModeService.verifyPin(enteredPin)) {
                Navigator.of(context).pop(true);
                _pinAttempts = 0;
              } else {
                _pinAttempts++;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(_pinAttempts >= 3
                        ? 'Incorrect PIN. Hint: Year of the RavenGate...'
                        : 'Incorrect PIN. Try again.'),
                    backgroundColor: Colors.red,
                  ),
                );
                Navigator.of(context).pop(false);
              }
            },
            child: const Text('Verify'),
          ),
        ],
      ),
    );

    return result == true;
  }

  Future<void> _toggleDeveloperMode(bool newValue) async {
    if (newValue && !_developerModeEnabled) {
      // Si está intentando activar el modo, pedir PIN
      final result = await _showPinDialog();

      if (result == true) {
        // PIN correcto, activar modo
        await DeveloperModeService.setDeveloperModeEnabled(true);
        setState(() {
          _developerModeEnabled = true;
        });

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Developer mode activated'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else if (!newValue && _developerModeEnabled) {
      // Desactivar modo sin pedir PIN
      await DeveloperModeService.setDeveloperModeEnabled(false);
      setState(() {
        _developerModeEnabled = false;
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Developer mode deactivated'),
          backgroundColor: Colors.blue,
        ),
      );
    }
  }

  Future<void> _runFirebaseDiagnostic() async {
    // Primero verificar si el modo desarrollador está activo
    final isEnabled = await DeveloperModeService.isDeveloperModeEnabled();
    if (!isEnabled) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Developer mode is not enabled'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Verificar si el widget sigue montado antes de mostrar diálogos
    if (!mounted || !context.mounted) return;

    // Mostrar un diálogo confirmando la acción
    final shouldRunDiagnostic = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Firebase Diagnostic'),
        content: const Text(
            'This will run a diagnostic to check and fix Firebase structure. Continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Run Diagnostic'),
          ),
        ],
      ),
    );

    if (shouldRunDiagnostic != true) return;

    // Mostrar indicador de progreso
    final progressDialog = ProgressDialog(
      context,
      type: ProgressDialogType.normal,
      isDismissible: false,
    );

    progressDialog.style(
      message: 'Running Firebase Diagnostic...',
      borderRadius: 10.0,
      backgroundColor: Colors.white,
      progressWidget: const CircularProgressIndicator(),
      elevation: 10.0,
      insetAnimCurve: Curves.easeInOut,
    );

    await progressDialog.show();

    try {
      // Ejecutar diagnóstico simple usando métodos disponibles
      // Actualizar información del usuario
      await UserFlightsService.updateUserInfo();

      // Forzar actualización de vuelos para verificar conectividad
      await UserFlightsService.getUserFlights(forceRefresh: true);

      // Forzar actualización de vuelos archivados
      await UserFlightsService.getUserArchivedFlightDates(forceRefresh: true);

      // Cerrar el diálogo de progreso
      if (progressDialog.isShowing) {
        await progressDialog.hide();
      }

      if (!mounted || !context.mounted) return;

      // Mostrar resultado
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Diagnosis completed. Check logs for details.'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 5),
        ),
      );
    } catch (e) {
      // Cerrar el diálogo de progreso
      if (progressDialog.isShowing) {
        await progressDialog.hide();
      }

      if (!mounted || !context.mounted) return;

      // Mostrar error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    AppLogger.info(
        'Construyendo UI de perfil para usuario: ${widget.user.displayName ?? "sin nombre"} (${widget.user.email ?? "sin email"})');
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 24.0),
        child: Center(
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
                style:
                    const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
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
                    Text(
                      localizations.preferences,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    // Configuración de notificaciones (movida arriba)
                    ListTile(
                      leading:
                          const Icon(Icons.notifications, color: Colors.blue),
                      title: Text(localizations.notificationSettings),
                      subtitle: Text(localizations.configureNotifications),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const NotificationsScreen(),
                          ),
                        );
                      },
                    ),
                    const Divider(),
                    // Configuración de visualización de datos
                    ListTile(
                      leading: const Icon(Icons.visibility, color: Colors.blue),
                      title: Text(localizations.dataVisualizationSettings),
                      subtitle:
                          Text(localizations.customizeDataDisplaySubtitle),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const DataVisualizationSettings(),
                          ),
                        );
                      },
                    ),
                    const Divider(),
                    // Configuración de idioma (ACTUALIZADO)
                    ListTile(
                      leading: const Icon(Icons.language, color: Colors.blue),
                      title: Text(localizations.languageSettings),
                      subtitle: Text(localizations.selectLanguage),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const LanguageSettingsScreen(),
                          ),
                        );
                      },
                    ),
                    const Divider(),
                    // Opción de Developer Mode
                    SwitchListTile(
                      title: Text(localizations.developerMode),
                      subtitle: Text(localizations.enableDeveloperModeSubtitle),
                      value: _developerModeEnabled,
                      activeColor: Colors.purple,
                      onChanged: _toggleDeveloperMode,
                    ),
                    // Botón de diagnóstico (solo visible si el modo desarrollador está activado)
                    if (_developerModeEnabled)
                      Padding(
                        padding: const EdgeInsets.only(left: 16.0, top: 8.0),
                        child: TextButton.icon(
                          onPressed: _runFirebaseDiagnostic,
                          icon: const Icon(Icons.bug_report,
                              color: Colors.purple),
                          label: const Text('Run Firebase Diagnostic',
                              style: TextStyle(color: Colors.purple)),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              OutlinedButton.icon(
                onPressed: () {
                  AppLogger.info(
                      'Usuario pulsó el botón de logout en la pantalla de perfil');
                  widget.onLogout();
                },
                icon: const Icon(Icons.logout),
                label: Text(localizations.logOut),
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
