import 'package:flutter/material.dart';
import '../../controllers/auth_controller.dart';
import '../../services/auth/auth_methods.dart';
import '../../services/auth/auth_result.dart';
import '../home/home_screen.dart';
import 'widgets/login_screen_ui.dart';

/// Container widget that handles authentication state and logic
class LoginScreen extends StatefulWidget {
  final AuthController authController;

  const LoginScreen({required this.authController, super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  List<AuthMethod> _availableMethods = [];

  @override
  void initState() {
    super.initState();
    print('🚀 LoginScreen - Iniciando...');
    _loadAvailableMethods();
  }

  Future<void> _loadAvailableMethods() async {
    print('📱 Cargando métodos de autenticación disponibles...');
    final methods = await widget.authController.getAvailableMethods();
    print(
        '✅ Métodos disponibles: ${methods.map((m) => m.toString()).join(", ")}');
    setState(() {
      _availableMethods = methods;
    });
  }

  Future<void> _authenticate(AuthMethod method) async {
    print('🔐 Iniciando autenticación con método: ${method.toString()}');
    final result = await widget.authController.authenticateWith(method);
    if (!mounted) return;

    if (result.success && result.user != null) {
      print('✅ Login exitoso:');
      print('  - Usuario: ${result.user?.displayName}');
      print('  - Email: ${result.user?.email}');
      print('  - Foto: ${result.user?.photoURL ?? "No disponible"}');

      // Navegar a HomeScreen
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => HomeScreen(user: result.user!),
        ),
      );
    } else {
      print('❌ Error en login: ${result.error ?? "Desconocido"}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${result.error ?? "Desconocido"}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    print(
        '🎨 Construyendo LoginScreen UI con ${_availableMethods.length} métodos');
    return LoginScreenUI(
      availableMethods: _availableMethods,
      onAuthenticate: _authenticate,
    );
  }
}
