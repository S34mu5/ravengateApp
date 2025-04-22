import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'auth_service.dart';
import 'auth_methods.dart';
import 'auth_result.dart';

/// Implementation of AuthService for Google authentication
class GoogleAuthService implements AuthService {
  final GoogleSignIn _googleSignIn;
  final FirebaseAuth _auth;

  GoogleAuthService()
      : _googleSignIn = GoogleSignIn(
          // Configuración básica con solo los elementos esenciales
          scopes: ['email'],
          // El signInOption explícito puede ayudar con ciertos dispositivos
          signInOption: SignInOption.standard,
          // Agregamos hostedDomain: null para evitar restricciones de dominio
          hostedDomain: null,
        ),
        _auth = FirebaseAuth.instance;

  @override
  AuthMethod get method => AuthMethod.google;

  /// Cierra la sesión tanto en Firebase como en Google
  Future<void> signOut() async {
    try {
      print('🔄 Cerrando sesión...');
      await Future.wait([
        _auth.signOut(),
        _googleSignIn.signOut(),
      ]);
      print('✅ Sesión cerrada correctamente');
    } catch (e) {
      print('❌ Error al cerrar sesión: $e');
      throw Exception('Error al cerrar sesión: $e');
    }
  }

  @override
  Future<bool> isAvailable() async {
    try {
      print('📱 Verificando disponibilidad de Google Sign In...');
      return true;
    } catch (e) {
      print('❌ Error verificando Google Sign In: $e');
      return false;
    }
  }

  /// Verifica si hay una sesión activa
  Future<AuthResult> checkCurrentUser() async {
    try {
      // Verificar si hay usuario en Firebase
      final currentUser = _auth.currentUser;
      if (currentUser != null) {
        print('✅ Usuario ya tiene sesión activa: ${currentUser.email}');
        return AuthResult(
          success: true,
          method: method,
          user: currentUser,
        );
      }

      // Verificar si hay sesión de Google
      final googleUser = await _googleSignIn.signInSilently();
      if (googleUser != null) {
        print('✅ Recuperando sesión de Google: ${googleUser.email}');
        // Obtener credenciales y autenticar con Firebase
        final googleAuth = await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        final userCredential = await _auth.signInWithCredential(credential);
        return AuthResult(
          success: true,
          method: method,
          user: userCredential.user,
        );
      }

      return AuthResult(
        success: false,
        method: method,
        error: 'No hay sesión activa',
      );
    } catch (e) {
      print('❌ Error verificando sesión: $e');
      return AuthResult(
        success: false,
        method: method,
        error: e.toString(),
      );
    }
  }

  @override
  Future<AuthResult> authenticate() async {
    try {
      print('🔄 Iniciando flujo de Google Sign In...');

      // Verificamos si hay una sesión activa primero
      final currentSession = await checkCurrentUser();
      if (currentSession.success) {
        return currentSession;
      }

      // Si no hay sesión, pedimos seleccionar cuenta
      print('🔄 Solicitando selección de cuenta de Google...');

      // Manejo detallado de errores
      GoogleSignInAccount? googleUser;
      try {
        // Intento alternativo con desconexión previa
        // Esto puede ayudar en casos donde hay un estado inconsistente
        await _googleSignIn.signOut();
        googleUser = await _googleSignIn.signIn();

        if (googleUser == null) {
          print('❌ Usuario canceló el login de Google');
          return AuthResult(
            success: false,
            method: method,
            error: 'Google Sign In cancelled by user',
          );
        }
      } catch (signInError) {
        print('🔍 Error detallado en signIn: $signInError');

        // Análisis detallado del error
        final errorString = signInError.toString();
        if (errorString.contains('ApiException: 10')) {
          print(
              '⚠️ Error ApiException:10 - Problema con la configuración del proyecto');
          return AuthResult(
            success: false,
            method: method,
            error:
                'ERROR 10: La aplicación no está correctamente registrada en Google. Verifica que todas las huellas SHA-1 y SHA-256 estén configuradas en Firebase.',
          );
        } else if (errorString.contains('ApiException: 7')) {
          print('⚠️ Error ApiException:7 - Problema de red');
          return AuthResult(
            success: false,
            method: method,
            error:
                'ERROR 7: Problema de conectividad. Verifica tu conexión a Internet.',
          );
        } else if (errorString.contains('ApiException: 12500')) {
          print(
              '⚠️ Error ApiException:12500 - Problema con Google Play Services');
          return AuthResult(
            success: false,
            method: method,
            error:
                'ERROR 12500: Google Play Services no está disponible o actualizado.',
          );
        }

        // Mensaje genérico para otros errores
        return AuthResult(
          success: false,
          method: method,
          error: 'Error de autenticación: $errorString',
        );
      }

      print('✅ Usuario seleccionó cuenta: ${googleUser.email}');

      // Obtain the auth details from the request
      print('🔑 Obteniendo credenciales...');
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      print('🔐 Autenticando con Firebase...');
      final UserCredential userCredential =
          await _auth.signInWithCredential(credential);

      print('✅ Login completado para: ${userCredential.user?.displayName}');
      return AuthResult(
        success: true,
        method: method,
        user: userCredential.user,
      );
    } catch (e) {
      print('❌ Error en autenticación de Google: $e');
      return AuthResult(
        success: false,
        method: method,
        error: e.toString(),
      );
    }
  }
}
