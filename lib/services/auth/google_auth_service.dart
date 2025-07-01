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
  })  : _googleSignIn = googleSignIn ?? GoogleSignIn.instance,
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
      // 1) Sesión ya iniciada en Firebase → devolvemos éxito inmediato
      final firebaseUser = _firebaseAuth.currentUser;
      if (firebaseUser != null) {
        return AuthResult(success: true, method: method, user: firebaseUser);
      }

      // 2) Inicializamos (necesario en la nueva API) y probamos autenticación ligera
      await _googleSignIn.initialize();

      GoogleSignInAccount? googleUser;
      try {
        googleUser = await _googleSignIn.attemptLightweightAuthentication();
      } catch (e) {
        AppLogger.warning('attemptLightweightAuthentication falló: $e');
      }

      // 3) Si sigue sin haber usuario, lanzamos flujo interactivo (authenticate)
      if (googleUser == null && _googleSignIn.supportsAuthenticate()) {
        try {
          googleUser = await _googleSignIn.authenticate();
        } catch (e) {
          AppLogger.warning('authenticate cancelado/error: $e');
        }
      }

      // Usuario canceló el diálogo o no se obtuvo cuenta
      if (googleUser == null) {
        return AuthResult(
          success: false,
          method: method,
          error: 'Inicio de sesión cancelado por el usuario',
        );
      }

      // 4) Intercambiamos credenciales con Firebase
      final googleAuth = googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      final userCredential =
          await _firebaseAuth.signInWithCredential(credential);

      return AuthResult(
        success: true,
        method: method,
        user: userCredential.user,
      );
    } catch (e) {
      AppLogger.error('GoogleAuthService.authenticate error', e);
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
