import 'auth_methods.dart';
import 'auth_result.dart';

/// Base interface for all authentication services
abstract class AuthService {
  /// Checks if the authentication method is available
  Future<bool> isAvailable();

  /// Attempts to authenticate the user
  Future<AuthResult> authenticate();

  /// Gets the authentication method implemented by this service
  AuthMethod get method;
}
