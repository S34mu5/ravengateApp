import 'auth_methods.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Result of an authentication attempt
class AuthResult {
  /// Whether the authentication was successful
  final bool success;

  /// Error message if authentication failed
  final String? error;

  /// Authentication method used
  final AuthMethod method;

  /// Firebase user if authentication was successful
  final User? user;

  /// Additional data that might be needed for special cases
  final Map<String, dynamic>? additionalData;

  const AuthResult({
    required this.success,
    this.error,
    required this.method,
    this.user,
    this.additionalData,
  });
}
