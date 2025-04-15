import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../controllers/auth_controller.dart';
import '../../services/auth/auth_methods.dart';
import '../../services/auth/auth_result.dart';
import '../../services/auth/email_password_auth_service.dart';
import '../home/home_screen.dart';
import 'widgets/login_screen_ui.dart';
import 'widgets/email_verification_screen.dart';

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
    print('🚀 LoginScreen - Starting...');
    _loadAvailableMethods();
  }

  Future<void> _loadAvailableMethods() async {
    print('📱 Loading available authentication methods...');
    final methods = await widget.authController.getAvailableMethods();
    print(
        '✅ Available methods: ${methods.map((m) => m.toString()).join(", ")}');
    setState(() {
      _availableMethods = methods;
    });
  }

  Future<void> _authenticate(AuthMethod method) async {
    print('🔐 Starting authentication with method: ${method.toString()}');
    final result = await widget.authController.authenticateWith(method);
    _handleAuthResult(result);
  }

  Future<void> _handleEmailPasswordAuth(
    String email,
    String password,
    bool isLogin,
  ) async {
    print(
        '🔐 Starting email/password authentication (${isLogin ? 'login' : 'signup'})');

    try {
      // Mostrar indicador de carga
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Processing...'),
          duration: Duration(seconds: 1),
        ),
      );

      // Obtener el servicio de email/password
      final emailPasswordService = widget.authController
          .getService(AuthMethod.emailPassword) as EmailPasswordAuthService;

      // Para registro: proceso especial
      if (!isLogin) {
        print('📝 Processing signup...');
        final result = await emailPasswordService.signUp(email, password);

        // No usamos _handleAuthResult para registros
        if (!mounted) return;

        // Si hay un error real (no el mensaje de verificación de email)
        if (result.error != null &&
            !result.error!.contains('We have sent you a verification email')) {
          print('❌ Error in registration: ${result.error}');
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.error ?? 'Registration error'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
          return;
        }

        print('📧 Showing email verification screen');

        // Aquí navegar a la pantalla de verificación en lugar de mostrar SnackBar
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => EmailVerificationScreen(
              email: email,
              isNewRegistration: true,
              onBackToLogin: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (context) => LoginScreen(
                      authController: widget.authController,
                    ),
                  ),
                );
              },
            ),
          ),
        );
        return;
      }

      // Para login: proceso normal
      final result = await emailPasswordService.signIn(email, password);

      // Ya no necesitamos esta lógica personalizada porque será manejada por _handleAuthResult
      // y nuestro nuevo campo additionalData

      if (!mounted) return;
      _handleAuthResult(result);
    } catch (e) {
      print('❌ Error in email/password auth: $e');
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('An unexpected error occurred: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _checkEmailVerification(String email) async {
    try {
      print('🔍 Checking verification status for email: $email');

      // Obtener el servicio de email/password
      final emailPasswordService = widget.authController
          .getService(AuthMethod.emailPassword) as EmailPasswordAuthService;

      // Verificar estado del email
      final isVerified =
          await emailPasswordService.checkEmailVerification(email);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Email verification status: ${isVerified ? "Verified ✓" : "Not Verified ✗"}'),
          backgroundColor: isVerified ? Colors.green : Colors.orange,
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      print('❌ Error checking email verification: $e');
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error checking verification status: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _handleAuthResult(AuthResult result) {
    if (!mounted) return;

    // Ocultar cualquier SnackBar previo
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    // Caso especial: Usuario autenticado pero necesita verificación
    if (result.success &&
        result.user != null &&
        result.additionalData != null &&
        result.additionalData!['needs_verification'] == true) {
      print(
          '📧 Manejando caso especial: usuario necesita verificación de email');

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => EmailVerificationScreen(
            email: result.user!.email,
            isNewRegistration: false,
            onBackToLogin: () {
              // Solo cerrar sesión cuando el usuario presione el botón "Back to Login"
              FirebaseAuth.instance.signOut();
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) => LoginScreen(
                    authController: widget.authController,
                  ),
                ),
              );
            },
          ),
        ),
      );
      return;
    }

    // Si tenemos un usuario exitoso y está verificado (o no es email/password)
    if (result.success && result.user != null) {
      print('✅ Login successful:');
      print('  - User: ${result.user?.displayName}');
      print('  - Email: ${result.user?.email}');
      print('  - Photo: ${result.user?.photoURL ?? "Not available"}');

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => HomeScreen(user: result.user!),
        ),
      );
      return;
    }

    // Para cualquier otro error
    print('❌ Login error: ${result.error ?? "Unknown"}');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.error ?? 'Unknown error'),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    print(
        '🎨 Building LoginScreen UI with ${_availableMethods.length} methods');
    return LoginScreenUI(
      availableMethods: _availableMethods,
      onAuthenticate: _authenticate,
      onEmailPasswordAuth: _handleEmailPasswordAuth,
      onCheckEmailVerification: _checkEmailVerification,
    );
  }
}
