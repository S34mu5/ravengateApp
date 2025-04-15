import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Pantalla que se muestra cuando un usuario necesita verificar su email
class EmailVerificationScreen extends StatelessWidget {
  final String? email;
  final bool isNewRegistration;
  final VoidCallback onBackToLogin;

  const EmailVerificationScreen({
    this.email,
    this.isNewRegistration = false,
    required this.onBackToLogin,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isNewRegistration
                      ? Icons.mark_email_unread_outlined
                      : Icons.email_outlined,
                  size: 64,
                  color: isNewRegistration ? Colors.green : Colors.orange,
                ),
                const SizedBox(height: 24),
                Text(
                  isNewRegistration
                      ? 'Registration Successful!'
                      : 'Email Not Verified',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  isNewRegistration
                      ? 'We have sent a verification email to ${email ?? "your email address"}. Please check your inbox (and spam folder) to verify your account.'
                      : 'Please check your inbox and verify your email before signing in.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 8),
                if (email != null)
                  Text(
                    'Email: $email',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                const SizedBox(height: 36),
                ElevatedButton(
                  onPressed: onBackToLogin,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(200, 45),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                      isNewRegistration ? 'Return to Login' : 'Back to Login'),
                ),
                const SizedBox(height: 16),
                if (email != null)
                  TextButton(
                    onPressed: () async {
                      try {
                        if (isNewRegistration) {
                          // Para nuevos usuarios, intentamos iniciar sesión primero
                          // para obtener el usuario y enviar el email
                          final auth = FirebaseAuth.instance;
                          final currentUser = auth.currentUser;

                          if (currentUser != null &&
                              currentUser.email == email) {
                            await currentUser.sendEmailVerification();
                          } else {
                            // Si no hay usuario actual o no coincide, mostramos error
                            throw Exception(
                                'No user available to resend verification email');
                          }
                        } else {
                          // Para usuarios que intentan iniciar sesión, ya tenemos el usuario
                          final user = FirebaseAuth.instance.currentUser;
                          if (user != null) {
                            await user.sendEmailVerification();
                          } else {
                            throw Exception('No user is signed in');
                          }
                        }

                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'Verification email sent. Please check your inbox.'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
                    child: const Text('Resend Verification Email'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
