import 'package:flutter/material.dart';
import 'package:sign_in_button/sign_in_button.dart';
import '../../../services/auth/auth_methods.dart';

/// Stateless widget that handles only the UI of the login screen
class LoginScreenUI extends StatelessWidget {
  final List<AuthMethod> availableMethods;
  final Future<void> Function(AuthMethod) onAuthenticate;

  const LoginScreenUI({
    required this.availableMethods,
    required this.onAuthenticate,
    super.key,
  });

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'RavenGate',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              const Text(
                'Welcome to RavenGate',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                'Sign in to continue',
                style: TextStyle(fontSize: 16, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              if (availableMethods.contains(AuthMethod.google))
                SignInButton(
                  Buttons.google,
                  onPressed: () => onAuthenticate(AuthMethod.google),
                ),
              if (availableMethods.contains(AuthMethod.biometric)) ...[
                const SizedBox(height: 16),
                _buildAuthButton(
                  onPressed: () => onAuthenticate(AuthMethod.biometric),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.fingerprint,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Sign in with biometrics',
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
    );
  }
}
