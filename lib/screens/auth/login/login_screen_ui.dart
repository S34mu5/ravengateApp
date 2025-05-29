import 'package:flutter/material.dart';
import '../../../services/auth/auth_methods.dart';
import '../../../l10n/app_localizations.dart';
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
    final localizations = AppLocalizations.of(context)!;

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
                    Text(
                      localizations.appName,
                      style: const TextStyle(
                          fontSize: 32, fontWeight: FontWeight.bold),
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
                        : Text(
                            localizations.createAccount,
                            style: const TextStyle(
                                fontSize: 24, fontWeight: FontWeight.w500),
                            textAlign: TextAlign.center,
                          ),
                    SizedBox(height: 8 * spacingFactor),

                    // Texto secundario
                    Text(
                      _isLogin
                          ? localizations.signInToAccessAccount
                          : localizations.signUpToStart,
                      style: const TextStyle(fontSize: 16, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 24 * spacingFactor),

                    // Campos de formulario
                    _buildTextField(
                      controller: _emailController,
                      labelText: localizations.email,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return localizations.pleaseEnterYourEmail;
                        }
                        final emailRegExp =
                            RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                        if (!emailRegExp.hasMatch(value)) {
                          return localizations.pleaseEnterValidEmail;
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 12 * spacingFactor),
                    _buildTextField(
                      controller: _passwordController,
                      labelText: localizations.password,
                      isPassword: true,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return localizations.pleaseEnterYourPassword;
                        }
                        if (value.length < 6) {
                          return localizations.passwordMustBeAtLeast6Characters;
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
                      child: Text(_isLogin
                          ? localizations.signIn
                          : localizations.signUp),
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
                            ? localizations.dontHaveAccount
                            : localizations.alreadyHaveAccount,
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
                              SnackBar(
                                content: Text(
                                    localizations.pleaseEnterValidEmailFirst),
                                backgroundColor: Colors.orange,
                              ),
                            );
                          }
                        },
                        child: Text(
                          localizations.checkEmailVerification,
                          style: const TextStyle(color: Colors.blue),
                        ),
                      ),

                    // Divisor
                    SizedBox(height: 12 * spacingFactor),
                    Row(
                      children: [
                        const Expanded(child: Divider()),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(localizations.orContinueWith),
                        ),
                        const Expanded(child: Divider()),
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
                                  Text(
                                    localizations.continueWithGoogle,
                                    style: const TextStyle(
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
                                  Text(
                                    localizations.useBiometrics,
                                    style: const TextStyle(
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
                    Text(
                      localizations.termsAndPrivacy,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
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
