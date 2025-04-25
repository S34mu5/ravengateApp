import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../services/cache/cache_service.dart';
import '../../../services/developer/developer_mode_service.dart';
import '../../../services/user/user_flights_service.dart';
import '../../../utils/progress_dialog.dart';

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
  bool _delayNotificationsEnabled = true;
  bool _departureNotificationsEnabled = true;
  bool _gateChangeNotificationsEnabled = true;
  bool _developerModeEnabled = false;
  final TextEditingController _pinController = TextEditingController();
  int _pinAttempts = 0;

  @override
  void initState() {
    super.initState();
    _loadNorwegianPreference();
    _loadNotificationsPreference();
    _loadDepartureNotificationsPreference();
    _loadGateChangeNotificationsPreference();
    _loadDeveloperModeStatus();
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _loadNorwegianPreference() async {
    final isEnabled = await CacheService.getNorwegianEquivalencePreference();
    setState(() {
      _norwegianEquivalenceEnabled = isEnabled;
    });
  }

  Future<void> _loadNotificationsPreference() async {
    final isEnabled = await CacheService.getDelayNotificationsPreference();
    setState(() {
      _delayNotificationsEnabled = isEnabled;
    });
  }

  Future<void> _loadDepartureNotificationsPreference() async {
    final isEnabled = await CacheService.getDepartureNotificationsPreference();
    setState(() {
      _departureNotificationsEnabled = isEnabled;
    });
  }

  Future<void> _loadGateChangeNotificationsPreference() async {
    final isEnabled = await CacheService.getGateChangeNotificationsPreference();
    setState(() {
      _gateChangeNotificationsEnabled = isEnabled;
    });
  }

  Future<void> _loadDeveloperModeStatus() async {
    final isEnabled = await DeveloperModeService.isDeveloperModeEnabled();
    setState(() {
      _developerModeEnabled = isEnabled;
    });
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
      // Ejecutar el diagnóstico
      await UserFlightsService.ensureFirestoreStructure();

      // Cerrar el diálogo de progreso
      if (progressDialog.isShowing) {
        await progressDialog.hide();
      }

      if (!mounted) return;

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

      if (!mounted) return;

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
    print(
        'LOG: Construyendo UI de perfil para usuario: ${widget.user.displayName ?? "sin nombre"} (${widget.user.email ?? "sin email"})');
    return SingleChildScrollView(
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
                  const Divider(),
                  SwitchListTile(
                    title: const Text('Flight Delay Notifications'),
                    subtitle: const Text(
                        'Receive alerts when flights saved in My Departures are delayed'),
                    value: _delayNotificationsEnabled,
                    activeColor: Colors.blue,
                    onChanged: (bool value) async {
                      setState(() {
                        _delayNotificationsEnabled = value;
                      });
                      await CacheService.saveDelayNotificationsPreference(
                          value);
                    },
                  ),
                  const Divider(),
                  SwitchListTile(
                    title: const Text('Flight Departure Notifications'),
                    subtitle: const Text(
                        'Receive alerts when flights saved in My Departures have departed'),
                    value: _departureNotificationsEnabled,
                    activeColor: Colors.blue,
                    onChanged: (bool value) async {
                      setState(() {
                        _departureNotificationsEnabled = value;
                      });
                      await CacheService.saveDepartureNotificationsPreference(
                          value);
                    },
                  ),
                  const Divider(),
                  SwitchListTile(
                    title: const Text('Gate Change Notifications'),
                    subtitle: const Text(
                        'Receive alerts when flights saved in My Departures have gate changes'),
                    value: _gateChangeNotificationsEnabled,
                    activeColor: Colors.blue,
                    onChanged: (bool value) async {
                      setState(() {
                        _gateChangeNotificationsEnabled = value;
                      });
                      await CacheService.saveGateChangeNotificationsPreference(
                          value);
                    },
                  ),
                  const Divider(),
                  // Opción de Developer Mode
                  SwitchListTile(
                    title: const Text('Developer Mode'),
                    subtitle: const Text(
                        'Enable advanced diagnostics and debugging tools'),
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
                        icon:
                            const Icon(Icons.bug_report, color: Colors.purple),
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
                print(
                    'LOG: Usuario pulsó el botón de logout en la pantalla de perfil');
                widget.onLogout();
              },
              icon: const Icon(Icons.logout),
              label: const Text('Log Out'),
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
    );
  }
}
