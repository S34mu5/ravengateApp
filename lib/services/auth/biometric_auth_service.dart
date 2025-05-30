import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';
import 'auth_service.dart';
import 'auth_methods.dart';
import 'auth_result.dart';
import '../../utils/logger.dart';

/// Implementation of AuthService for biometric authentication
class BiometricAuthService implements AuthService {
  final LocalAuthentication _localAuth;
  List<BiometricType>? _availableBiometrics;

  BiometricAuthService() : _localAuth = LocalAuthentication();

  @override
  AuthMethod get method => AuthMethod.biometric;

  @override
  Future<bool> isAvailable() async {
    try {
      AppLogger.debug('🔐 Verificando disponibilidad de biometría...');

      final bool isSupported = await _localAuth.isDeviceSupported();
      AppLogger.debug('📱 ¿El dispositivo soporta biometría?: $isSupported');
      if (!isSupported) {
        AppLogger.warning(
            '❌ El dispositivo no soporta autenticación biométrica');
        return false;
      }

      // Verificar si hay biometrías disponibles
      final bool canCheckBiometrics = await _localAuth.canCheckBiometrics;
      AppLogger.debug(
          '🔍 ¿Se pueden verificar biometrías?: $canCheckBiometrics');
      if (!canCheckBiometrics) {
        AppLogger.warning(
            '❌ No hay biometrías disponibles en este dispositivo');
        return false;
      }

      // Obtener lista de biometrías disponibles
      final List<BiometricType> _availableBiometrics =
          await _localAuth.getAvailableBiometrics();
      AppLogger.debug('📋 Biometrías disponibles: $_availableBiometrics');

      final bool hasAvailableBiometrics = _availableBiometrics.isNotEmpty;
      AppLogger.debug(hasAvailableBiometrics
          ? '✅ Biometrías disponibles'
          : '❌ No hay biometrías configuradas');

      return hasAvailableBiometrics;
    } on PlatformException catch (e) {
      AppLogger.error(
          'Error checking biometrics availability: ${e.message}', e);
      return false;
    } catch (e) {
      AppLogger.error('Unexpected error checking biometrics', e);
      return false;
    }
  }

  @override
  Future<AuthResult> authenticate() async {
    try {
      // Verify availability first
      final isAvailable = await this.isAvailable();
      if (!isAvailable) {
        return AuthResult(
          success: false,
          method: method,
          error: 'Biometric authentication is not available on this device',
        );
      }

      // Get authentication type description
      final String authType = _getAuthTypeDescription();

      final success = await _localAuth.authenticate(
        localizedReason: 'Por favor autentícate usando $authType',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );

      return AuthResult(
        success: success,
        method: method,
        error: success ? null : 'La autenticación biométrica falló',
      );
    } on PlatformException catch (e) {
      AppLogger.error(
          'Platform error in biometric authentication: ${e.message}', e);

      if (e.code == 'UserCancel') {
        return AuthResult(
          success: false,
          method: method,
          error: 'Usuario canceló la autenticación',
        );
      } else if (e.code == 'NotAvailable') {
        return AuthResult(
          success: false,
          method: method,
          error: 'Autenticación biométrica no disponible',
        );
      } else {
        return AuthResult(
          success: false,
          method: method,
          error: 'Error en autenticación biométrica: ${e.message}',
        );
      }
    } catch (e) {
      AppLogger.error('Unexpected error in biometric authentication', e);
      return AuthResult(
        success: false,
        method: method,
        error: 'Error inesperado en autenticación biométrica',
      );
    }
  }

  String _getAuthTypeDescription() {
    if (_availableBiometrics?.contains(BiometricType.face) ?? false) {
      return 'reconocimiento facial';
    } else if (_availableBiometrics?.contains(BiometricType.fingerprint) ??
        false) {
      return 'huella dactilar';
    } else if (_availableBiometrics?.contains(BiometricType.iris) ?? false) {
      return 'reconocimiento de iris';
    }
    return 'biometría';
  }

  String _getErrorMessage(PlatformException e) {
    switch (e.code) {
      case 'LockedOut':
        return 'Demasiados intentos fallidos. Por favor, espera antes de intentar de nuevo.';
      case 'PermanentlyLockedOut':
        return 'El dispositivo está bloqueado permanentemente. Por favor, configura la biometría de nuevo en los ajustes del sistema.';
      case 'PasscodeNotSet':
        return 'No hay un código de acceso configurado en el dispositivo. Por favor, configura uno en los ajustes del sistema.';
      case 'NotEnrolled':
        return 'No hay datos biométricos registrados. Por favor, configura la biometría en los ajustes del sistema.';
      case 'NotAvailable':
        return 'La autenticación biométrica no está disponible en este momento.';
      case 'OtherOperatingSystem':
        return 'La autenticación biométrica no está soportada en este sistema operativo.';
      case 'SecurityUpdate':
        return 'Se requiere una actualización de seguridad.';
      default:
        return 'Error en la autenticación biométrica: ${e.message}';
    }
  }
}
