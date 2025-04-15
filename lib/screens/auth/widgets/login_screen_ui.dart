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
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 32),
                  const Text(
                    'RavenGate',
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),
                  Text(
                    _isLogin ? 'Welcome back' : 'Create account',
                    style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.w500),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _isLogin ? 'Sign in to continue' : 'Sign up to start',
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  _buildTextField(
                    controller: _emailController,
                    labelText: 'Email',
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your email';
                      }

                      // Expresión regular para validar email
                      final emailRegExp =
                          RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                      if (!emailRegExp.hasMatch(value)) {
                        return 'Please enter a valid email address';
                      }

                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
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
                  const SizedBox(height: 24),
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
                  if (_isLogin && widget.onCheckEmailVerification != null)
                    TextButton(
                      onPressed: () {
                        if (_emailController.text.isNotEmpty &&
                            _emailController.text.contains('@')) {
                          widget
                              .onCheckEmailVerification!(_emailController.text);
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
                  const SizedBox(height: 24),
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
                  const SizedBox(height: 24),
                  if (widget.availableMethods.contains(AuthMethod.google))
                    _buildAuthButton(
                      onPressed: () => widget.onAuthenticate(AuthMethod.google),
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
                    const SizedBox(height: 16),
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
                  const SizedBox(height: 24),
                  const Text(
                    'By continuing, you agree to our Terms of Service and Privacy Policy',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
