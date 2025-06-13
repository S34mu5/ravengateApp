import 'package:firebase_auth/firebase_auth.dart';
import 'auth_service.dart';
import 'auth_methods.dart';
import 'auth_result.dart';
import '../../utils/logger.dart';

/// Implementation of AuthService for email/password authentication
class EmailPasswordAuthService implements AuthService {
  final FirebaseAuth _auth;

  EmailPasswordAuthService() : _auth = FirebaseAuth.instance;

  @override
  AuthMethod get method => AuthMethod.emailPassword;

  @override
  Future<bool> isAvailable() async {
    // Email/password authentication is always available
    return true;
  }

  @override
  Future<AuthResult> authenticate() async {
    // Este método no se usa directamente ya que necesitamos email y password
    // La autenticación real se maneja en LoginScreen
    return AuthResult(
      success: false,
      method: method,
      error: 'This method requires email and password',
    );
  }

  /// Intenta iniciar sesión con email y password
  Future<AuthResult> signIn(String email, String password) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Verificar si el email está verificado
      if (!userCredential.user!.emailVerified) {
        AppLogger.info(
            'Usuario no verificado pero manteniendo sesión activa: ${userCredential.user!.email}');
        return AuthResult(
          success: true, // Cambiado a true para no gatillar logout
          method: method,
          error: 'Por favor, verifica tu email antes de iniciar sesión.',
          user: userCredential.user,
          additionalData: {'needs_verification': true}, // Indicador especial
        );
      }

      return AuthResult(
        success: true,
        method: method,
        user: userCredential.user,
      );
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'user-not-found':
          errorMessage = 'No account exists with this email';
          break;
        case 'wrong-password':
          errorMessage = 'Incorrect password';
          break;
        case 'invalid-email':
          errorMessage = 'The email is not valid';
          break;
        case 'user-disabled':
          errorMessage = 'This account has been disabled';
          break;
        default:
          errorMessage = e.message ?? 'Authentication error';
      }
      return AuthResult(
        success: false,
        method: method,
        error: errorMessage,
      );
    } catch (e) {
      return AuthResult(
        success: false,
        method: method,
        error: 'Unexpected error: $e',
      );
    }
  }

  /// Intenta registrar un nuevo usuario con email y password
  Future<AuthResult> signUp(String email, String password) async {
    try {
      AppLogger.info('Creating new user account for email: $email');
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      AppLogger.info(
          'User account created successfully: ${userCredential.user?.uid}');

      // Enviar email de verificación
      AppLogger.debug(
          'Attempting to send verification email to: ${userCredential.user?.email}');
      bool emailSent = false;
      try {
        if (userCredential.user != null) {
          AppLogger.debug('Setting language code to English');
          AppLogger.debug('Calling sendEmailVerification');
          await userCredential.user!.sendEmailVerification();
          emailSent = true;
          AppLogger.info('Verification email sent successfully');
          AppLogger.debug('Check spam folder if email not received');
        } else {
          AppLogger.error('Cannot send verification email: user is null');
        }
      } catch (verificationError) {
        AppLogger.error('Error sending verification email', verificationError);
      }

      // Ya no cerramos sesión automáticamente después del registro
      AppLogger.debug('No longer signing out user after registration');

      // Devolvemos un resultado especial para manejo del registro
      final message = emailSent
          ? 'We have sent you a verification email. Please check your inbox and verify your email address to complete your registration.'
          : 'Account created, but we could not send the verification email. Please try signing in and request a new verification email.';

      return AuthResult(
        success: true, // Cambiado a true para no gatillar logout
        method: method,
        user: userCredential
            .user, // Mantenemos el usuario para mostrar la pantalla de verificación
        error: message,
        additionalData: {'is_new_registration': true}, // Indicador especial
      );
    } on FirebaseAuthException catch (e) {
      AppLogger.error('Firebase Auth Exception during signup: ${e.code}', e);
      String errorMessage;
      switch (e.code) {
        case 'weak-password':
          errorMessage = 'The password is too weak';
          break;
        case 'email-already-in-use':
          errorMessage = 'An account already exists with this email';
          break;
        case 'invalid-email':
          errorMessage =
              'The email format is invalid. Please check that you entered a valid email address';
          break;
        case 'operation-not-allowed':
          errorMessage = 'Email/password registration is not enabled';
          break;
        default:
          errorMessage = e.message ?? 'Registration error';
      }
      return AuthResult(
        success: false,
        method: method,
        error: errorMessage,
      );
    } catch (e) {
      AppLogger.error('Unexpected error during signup', e);
      return AuthResult(
        success: false,
        method: method,
        error: 'Unexpected error: $e',
      );
    }
  }

  /// Reenvía el email de verificación al usuario actual
  Future<AuthResult> resendVerificationEmail() async {
    try {
      AppLogger.debug('Attempting to resend verification email');
      final user = _auth.currentUser;
      if (user == null) {
        AppLogger.warning('No user is signed in to resend verification email');
        return AuthResult(
          success: false,
          method: method,
          error: 'No user is signed in',
        );
      }

      AppLogger.debug('Resending verification email to: ${user.email}');
      try {
        await user.sendEmailVerification();
        AppLogger.info('Verification email resent successfully');
      } catch (e) {
        AppLogger.error('Error resending verification email', e);
        return AuthResult(
          success: false,
          method: method,
          error: 'Error sending verification email: $e',
        );
      }

      return AuthResult(
        success: true,
        method: method,
        user: user,
        error:
            'We have sent you a new verification email. Please check your inbox.',
      );
    } catch (e) {
      AppLogger.error('Unexpected error in resendVerificationEmail', e);
      return AuthResult(
        success: false,
        method: method,
        error: 'Unexpected error: $e',
      );
    }
  }

  /// Verifica manualmente si el email del usuario está verificado
  Future<bool> checkEmailVerification(String email) async {
    try {
      AppLogger.debug('Checking email verification status for: $email');

      // Esta es una mejor forma de verificar - no depende de iniciar sesión con el enlace
      try {
        // Si hay un usuario actual con el mismo email, usamos ese
        final currentUser = _auth.currentUser;
        if (currentUser != null && currentUser.email == email) {
          AppLogger.debug('Using current user to check verification status');
          // Recargar para obtener el estado más reciente
          await currentUser.reload();
          final isVerified = currentUser.emailVerified;
          AppLogger.debug(
              'Current user verification status: ${isVerified ? "Verified" : "Not Verified"}');
          return isVerified;
        }
      } catch (e) {
        AppLogger.warning('Error checking current user: $e');
        // Continuamos con los otros métodos
      }

      // El método fetchSignInMethodsForEmail no nos dice si está verificado
      // Simplemente nos dice qué métodos de inicio de sesión están disponibles

      AppLogger.warning(
          'Cannot determine verification status without signing in');
      AppLogger.warning(
          'Please try signing in first, then use the verification button');

      return false;
    } catch (e) {
      AppLogger.error('Error checking email verification', e);
      return false;
    }
  }
}
