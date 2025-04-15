import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'auth_service.dart';
import 'auth_methods.dart';
import 'auth_result.dart';

/// Implementation of AuthService for biometric authentication
class BiometricAuthService implements AuthService {
  final LocalAuthentication _localAuth;

  BiometricAuthService() : _localAuth = LocalAuthentication();

  @override
  AuthMethod get method => AuthMethod.biometric;

  @override
  Future<bool> isAvailable() async {
    try {
      return await _localAuth.canCheckBiometrics;
    } catch (e) {
      debugPrint('Error checking biometrics: $e');
      return false;
    }
  }

  @override
  Future<AuthResult> authenticate() async {
    try {
      final success = await _localAuth.authenticate(
        localizedReason: 'Please authenticate to sign in',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );

      return AuthResult(
        success: success,
        method: method,
        error: success ? null : 'Biometric authentication failed',
      );
    } catch (e) {
      debugPrint('Error in biometric authentication: $e');
      return AuthResult(success: false, method: method, error: e.toString());
    }
  }
}
