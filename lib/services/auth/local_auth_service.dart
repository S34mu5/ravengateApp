import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'auth_service.dart';
import 'auth_methods.dart';
import 'auth_result.dart';
import 'package:flutter/material.dart';

/// Implementación de AuthService usando el paquete local_auth
class LocalAuthService implements AuthService {
  final LocalAuthentication _localAuth;

  LocalAuthService() : _localAuth = LocalAuthentication();

  @override
  AuthMethod get method => AuthMethod.biometric;

  @override
  Future<bool> isAvailable() async {
    try {
      return await _localAuth.canCheckBiometrics;
    } catch (e) {
      debugPrint('Error al verificar biometría: $e');
      return false;
    }
  }

  @override
  Future<AuthResult> authenticate() async {
    try {
      final success = await _localAuth.authenticate(
        localizedReason: 'Por favor autentícate para iniciar sesión',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );

      return AuthResult(
        success: success,
        method: method,
        error: success ? null : 'Autenticación biométrica fallida',
      );
    } catch (e) {
      debugPrint('Error en autenticación biométrica: $e');
      return AuthResult(success: false, method: method, error: e.toString());
    }
  }
}
