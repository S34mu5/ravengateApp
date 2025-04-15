import '../services/auth/auth_service.dart';
import '../services/auth/auth_methods.dart';
import '../services/auth/auth_result.dart';

/// Controlador que maneja la lógica de autenticación
class AuthController {
  final Map<AuthMethod, AuthService> _services;

  AuthController(List<AuthService> services)
      : _services = {for (var service in services) service.method: service};

  /// Obtiene un servicio de autenticación específico
  AuthService? getService(AuthMethod method) => _services[method];

  /// Verifica si un método de autenticación específico está disponible
  Future<bool> isMethodAvailable(AuthMethod method) async {
    final service = _services[method];
    if (service == null) return false;
    return await service.isAvailable();
  }

  /// Intenta autenticar al usuario usando un método específico
  Future<AuthResult> authenticateWith(AuthMethod method) async {
    final service = _services[method];
    if (service == null) {
      return AuthResult(
        success: false,
        method: method,
        error: 'Método de autenticación no disponible',
      );
    }
    return await service.authenticate();
  }

  /// Obtiene todos los métodos de autenticación disponibles
  Future<List<AuthMethod>> getAvailableMethods() async {
    final availableMethods = <AuthMethod>[];
    for (final entry in _services.entries) {
      if (await entry.value.isAvailable()) {
        availableMethods.add(entry.key);
      }
    }
    return availableMethods;
  }
}
