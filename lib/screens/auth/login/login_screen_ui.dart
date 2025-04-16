import 'package:flutter/material.dart';
import 'package:sign_in_button/sign_in_button.dart';
import '../../../services/auth/auth_methods.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// Widget that handles the UI of the login screen
class LoginScreenUI extends StatefulWidget {
  final List<AuthMethod> availableMethods;
  final Future<void> Function(AuthMethod) onAuthenticate;
  final Future<void> Function(String email, String password, bool isLogin)
      onEmailPasswordAuth;
  final Future<void> Function(String email)? onCheckEmailVerification;

  const LoginScreenUI({
    required this.availableMethods,
    required this.onAuthenticate,
    required this.onEmailPasswordAuth,
    this.onCheckEmailVerification,
    super.key,
  });

  @override
  State<LoginScreenUI> createState() => _LoginScreenUIState();
}

class _LoginScreenUIState extends State<LoginScreenUI> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLogin = true;
  bool _isPasswordVisible = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Widget _buildAuthButton({
    required VoidCallback onPressed,
    required Widget child,
  }) {
    return Container(
      height: 50,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
            side: BorderSide(color: Colors.grey.shade300),
          ),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 1,
        ),
        child: child,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String labelText,
    required String? Function(String?) validator,
    bool isPassword = false,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: labelText,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  _isPasswordVisible ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: () {
                  setState(() {
                    _isPasswordVisible = !_isPasswordVisible;
                  });
                },
              )
            : null,
      ),
      obscureText: isPassword && !_isPasswordVisible,
      validator: validator,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Calcula el factor de escala basado en la altura disponible
            final double heightFactor =
                constraints.maxHeight / 800; // Altura de referencia
            final double spacingFactor = heightFactor < 1 ? heightFactor : 1;

            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Logo/título con tamaño adaptado
                    SizedBox(height: 16 * spacingFactor),
                    const Text(
                      'RavenGate',
                      style:
                          TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 24 * spacingFactor),

                    // Icono o texto según estado de login/signup
                    _isLogin
                        ? Center(
                            child: Image.asset(
                              'assets/images/ravengateIconBlack.png',
                              height: 120 * spacingFactor,
                              width: 120 * spacingFactor,
                            ),
                          )
                        : const Text(
                            'Create account',
                            style: TextStyle(
                                fontSize: 24, fontWeight: FontWeight.w500),
                            textAlign: TextAlign.center,
                          ),
                    SizedBox(height: 8 * spacingFactor),

                    // Texto secundario
                    Text(
                      _isLogin
                          ? 'Sign in to access your account'
                          : 'Sign up to start',
                      style: const TextStyle(fontSize: 16, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 24 * spacingFactor),

                    // Campos de formulario
                    _buildTextField(
                      controller: _emailController,
                      labelText: 'Email',
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your email';
                        }
                        final emailRegExp =
                            RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                        if (!emailRegExp.hasMatch(value)) {
                          return 'Please enter a valid email address';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 12 * spacingFactor),
                    _buildTextField(
                      controller: _passwordController,
                      labelText: 'Password',
                      isPassword: true,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your password';
                        }
                        if (value.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16 * spacingFactor),

                    // Botón principal
                    ElevatedButton(
                      onPressed: () {
                        if (_formKey.currentState!.validate()) {
                          widget.onEmailPasswordAuth(
                            _emailController.text,
                            _passwordController.text,
                            _isLogin,
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(_isLogin ? 'Sign in' : 'Sign up'),
                    ),

                    // Botón para cambiar entre login/signup
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _isLogin = !_isLogin;
                        });
                      },
                      child: Text(
                        _isLogin
                            ? 'Don\'t have an account? Sign up'
                            : 'Already have an account? Sign in',
                      ),
                    ),

                    // Botón de verificación (condicional)
                    if (_isLogin && widget.onCheckEmailVerification != null)
                      TextButton(
                        onPressed: () {
                          if (_emailController.text.isNotEmpty &&
                              _emailController.text.contains('@')) {
                            widget.onCheckEmailVerification!(
                                _emailController.text);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'Please enter a valid email address first'),
                                backgroundColor: Colors.orange,
                              ),
                            );
                          }
                        },
                        child: const Text(
                          'Check email verification status',
                          style: TextStyle(color: Colors.blue),
                        ),
                      ),

                    // Divisor
                    SizedBox(height: 12 * spacingFactor),
                    const Row(
                      children: [
                        Expanded(child: Divider()),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Text('Or continue with'),
                        ),
                        Expanded(child: Divider()),
                      ],
                    ),
                    SizedBox(height: 12 * spacingFactor),

                    // Opciones de login alternativas
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (widget.availableMethods
                              .contains(AuthMethod.google))
                            _buildAuthButton(
                              onPressed: () =>
                                  widget.onAuthenticate(AuthMethod.google),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const FaIcon(
                                    FontAwesomeIcons.google,
                                    size: 24,
                                    color: Colors.red,
                                  ),
                                  const SizedBox(width: 12),
                                  const Text(
                                    'Continue with Google',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (widget.availableMethods
                              .contains(AuthMethod.biometric)) ...[
                            SizedBox(height: 16 * spacingFactor),
                            _buildAuthButton(
                              onPressed: () =>
                                  widget.onAuthenticate(AuthMethod.biometric),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.fingerprint,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 12),
                                  const Text(
                                    'Use biometrics',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Texto de términos y condiciones
                    const Text(
                      'By continuing, you agree to our Terms of Service and Privacy Policy',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 8),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
