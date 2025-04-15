import 'package:firebase_auth/firebase_auth.dart';
import 'auth_service.dart';
import 'auth_methods.dart';
import 'auth_result.dart';

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
        print(
            '📧 Usuario no verificado pero manteniendo sesión activa: ${userCredential.user!.email}');
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
      print('📝 Creating new user account for email: $email');
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      print('✅ User account created successfully: ${userCredential.user?.uid}');

      // Enviar email de verificación
      print(
          '📧 Attempting to send verification email to: ${userCredential.user?.email}');
      bool emailSent = false;
      try {
        if (userCredential.user != null) {
          print('🌐 Setting language code to English');
          final settings = await _auth.setLanguageCode("en");
          print('📤 About to call sendEmailVerification()');
          await userCredential.user!.sendEmailVerification();
          emailSent = true;
          print('📨 Verification email request sent successfully 🎉');
          print('📬 Check spam folder if email not received');
        } else {
          print('❌ Cannot send verification email: user is null');
        }
      } catch (verificationError) {
        print('❌ Error sending verification email: $verificationError');
      }

      // Ya no cerramos sesión automáticamente después del registro
      print(
          '🚫 No longer signing out user after registration - verification screen will handle this');

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
      print(
          '❌ Firebase Auth Exception during signup: ${e.code} - ${e.message}');
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
      print('❌ Unexpected error during signup: $e');
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
      print('🔄 Attempting to resend verification email');
      final user = _auth.currentUser;
      if (user == null) {
        print('❌ No user is signed in to resend verification email');
        return AuthResult(
          success: false,
          method: method,
          error: 'No user is signed in',
        );
      }

      print('📧 Resending verification email to: ${user.email}');
      try {
        await user.sendEmailVerification();
        print('✅ Verification email resent successfully');
      } catch (e) {
        print('❌ Error resending verification email: $e');
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
      print('❌ Unexpected error in resendVerificationEmail: $e');
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
      print('🔍 Checking email verification status for: $email');

      // Esta es una mejor forma de verificar - no depende de iniciar sesión con el enlace
      try {
        // Si hay un usuario actual con el mismo email, usamos ese
        final currentUser = _auth.currentUser;
        if (currentUser != null && currentUser.email == email) {
          print('📋 Using current user to check verification status');
          // Recargar para obtener el estado más reciente
          await currentUser.reload();
          final isVerified = currentUser.emailVerified;
          print(
              '📋 Current user verification status: ${isVerified ? "Verified ✓" : "Not Verified ✗"}');
          return isVerified;
        }
      } catch (e) {
        print('⚠️ Error checking current user: $e');
        // Continuamos con los otros métodos
      }

      // El método fetchSignInMethodsForEmail no nos dice si está verificado
      // Simplemente nos dice qué métodos de inicio de sesión están disponibles

      print('⚠️ Cannot determine verification status without signing in');
      print('⚠️ Please try signing in first, then use the verification button');

      return false;
    } catch (e) {
      print('❌ Error checking email verification: $e');
      return false;
    }
  }
}
