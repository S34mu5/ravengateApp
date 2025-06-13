import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'auth_service.dart';
import 'auth_methods.dart';
import 'auth_result.dart';
import '../../utils/logger.dart';

/// Servicio de autenticación con Google, siguiendo buenas prácticas:
/// - Inyección de dependencias para facilitar pruebas.
/// - Manejo unificado de errores y cancelaciones.
class GoogleAuthService implements AuthService {
  final GoogleSignIn _googleSignIn;
  final FirebaseAuth _firebaseAuth;

  GoogleAuthService({
    GoogleSignIn? googleSignIn,
    FirebaseAuth? firebaseAuth,
  })  : _googleSignIn = googleSignIn ?? GoogleSignIn(scopes: ['email']),
        _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  @override
  AuthMethod get method => AuthMethod.google;

  @override
  Future<bool> isAvailable() async {
    // Google Sign-In está siempre disponible si las librerías cargan correctamente.
    return true;
  }

  @override
  Future<AuthResult> authenticate() async {
    try {
      // 1) Si ya hay usuario de Firebase, devolvemos sesión activa.
      final currentUser = _firebaseAuth.currentUser;
      if (currentUser != null) {
        return AuthResult(
          success: true,
          method: method,
          user: currentUser,
        );
      }

      // 2) Intento de sesión silenciosa en Google
      GoogleSignInAccount? googleUser;
      try {
        googleUser = await _googleSignIn.signInSilently();
      } catch (e) {
        AppLogger.warning('Error en signInSilently (ignorado): $e');
        // Continuamos con el flujo aunque falle el silencioso
      }

      // 3) Si no había sesión, pedimos interactivo
      if (googleUser == null) {
        try {
          googleUser = await _googleSignIn.signIn();
        } catch (e) {
          AppLogger.warning('Error en signIn interactivo: $e');
          if (e.toString().contains('PigeonUserDetails')) {
            // Ignoramos este error específico ya que no impide el funcionamiento
            AppLogger.info('Ignorando error de PigeonUserDetails');
          } else {
            // Para otros errores, retornamos el resultado de error
            return AuthResult(
              success: false,
              method: method,
              error: 'Error durante la autenticación con Google: $e',
            );
          }
        }
      }

      if (googleUser == null) {
        // El usuario canceló el flujo
        return AuthResult(
          success: false,
          method: method,
          error: 'Google Sign-In cancelado por el usuario',
        );
      }

      // 4) Obtenemos credenciales de Google
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // 5) Autenticamos en Firebase con las credenciales
      final result = await _firebaseAuth.signInWithCredential(credential);
      return AuthResult(
        success: true,
        method: method,
        user: result.user,
      );
    } catch (e) {
      AppLogger.error('Error en authenticate de GoogleAuthService', e);
      // Para el error específico de PigeonUserDetails, ignoramos
      if (e.toString().contains('PigeonUserDetails')) {
        // Si tenemos usuario en Firebase a pesar del error, consideramos exitoso
        final currentUser = _firebaseAuth.currentUser;
        if (currentUser != null) {
          AppLogger.info(
              'Usuario autenticado a pesar del error PigeonUserDetails');
          return AuthResult(
            success: true,
            method: method,
            user: currentUser,
          );
        }
      }

      // Devolvemos siempre string para simplificar manejo de errores
      return AuthResult(
        success: false,
        method: method,
        error: e.toString(),
      );
    }
  }

  Future<void> signOut() async {
    // Cerramos sesión en Firebase y Google secuencialmente
    await _firebaseAuth.signOut();
    await _googleSignIn.signOut();
  }
}
