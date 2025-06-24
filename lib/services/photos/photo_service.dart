import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../utils/logger.dart';
import 'firebase_photo_service.dart';

/// Servicio para gestionar fotos de elementos de equipaje oversized
class PhotoService {
  static const String _photoKeysPrefix = 'oversize_photos_';
  static const int _maxImageQuality = 60; // Reducir calidad para menor tamaño
  static const double _maxImageWidth = 800; // Máximo ancho en píxeles

  final ImagePicker _picker = ImagePicker();

  /// Toma una foto con la cámara y la asocia a un elemento específico
  Future<String?> takePhoto({
    required String documentId,
    required String flightId,
    required String itemId,
    required String itemType, // Nuevo parámetro requerido
    DateTime? flightDate, // Fecha del vuelo para organizar carpetas
  }) async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: _maxImageQuality,
        maxWidth: _maxImageWidth,
      );

      if (photo == null) return null;

      // Intentar subir a Firebase primero si el usuario está autenticado
      AppLogger.debug('📱 Verificando autenticación...', null, 'PhotoService');
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        AppLogger.debug(
            '👤 Usuario autenticado: ${user.email}', null, 'PhotoService');
        try {
          AppLogger.info(
              '🚀 Llamando a FirebasePhotoService...', null, 'PhotoService');
          final result = await FirebasePhotoService.uploadOversizePhoto(
            documentId: documentId,
            itemType: itemType,
            itemId: itemId,
            photo: photo,
            flightId: flightId,
            flightDate: flightDate,
          );

          if (result != null) {
            AppLogger.info(
                '🎯 Firebase retornó resultado exitoso', null, 'PhotoService');
            // Guardar también una copia local como backup/caché
            final Uint8List imageBytes = await photo.readAsBytes();
            final String base64Image = base64Encode(imageBytes);
            await _savePhoto(documentId, flightId, itemId, base64Image);
            AppLogger.debug('💾 Copia local guardada', null, 'PhotoService');

            // Guardar metadatos de Firebase para mostrar sincronización
            await _saveFirebaseMetadata(documentId, flightId, itemId, result);
            AppLogger.debug('📋 Metadatos guardados', null, 'PhotoService');

            // Retornar el base64 local para la miniatura (Firebase es solo para backup)
            return base64Image;
          } else {
            AppLogger.warning('⚠️ Firebase retornó null', null, 'PhotoService');
          }
        } catch (e) {
          AppLogger.error('💥 Error en Firebase: $e', e, 'PhotoService');
          AppLogger.error('❌ Subida fallida - No se guardará la foto', null,
              'PhotoService');
          return null; // No guardar nada si Firebase falla
        }
      } else {
        AppLogger.debug('🔒 Usuario no autenticado', null, 'PhotoService');
        AppLogger.warning(
            '⚠️ Firebase Storage requiere autenticación', null, 'PhotoService');
        return null; // No permitir fotos sin autenticación
      }

      // Esta línea nunca debería alcanzarse, pero por seguridad
      AppLogger.error('🚫 Código no debería llegar aquí', null, 'PhotoService');
      return null;
    } catch (e) {
      AppLogger.error('Error tomando foto: $e', e, 'PhotoService');
      return null;
    }
  }

  /// Selecciona una foto de la galería y la asocia a un elemento específico
  Future<String?> pickFromGallery({
    required String documentId,
    required String flightId,
    required String itemId,
    required String itemType, // Nuevo parámetro requerido
    DateTime? flightDate, // Fecha del vuelo para organizar carpetas
  }) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: _maxImageQuality,
        maxWidth: _maxImageWidth,
      );

      if (image == null) return null;

      // Intentar subir a Firebase primero si el usuario está autenticado
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        try {
          AppLogger.info(
              'Subiendo foto a Firebase Storage...', null, 'PhotoService');
          final result = await FirebasePhotoService.uploadOversizePhoto(
            documentId: documentId,
            itemType: itemType,
            itemId: itemId,
            photo: image,
            flightId: flightId,
            flightDate: flightDate,
          );

          if (result != null) {
            AppLogger.info('Foto subida exitosamente a Firebase Storage', null,
                'PhotoService');
            // Guardar también una copia local como backup/caché
            final Uint8List imageBytes = await image.readAsBytes();
            final String base64Image = base64Encode(imageBytes);
            await _savePhoto(documentId, flightId, itemId, base64Image);

            // Guardar metadatos de Firebase para mostrar sincronización
            await _saveFirebaseMetadata(documentId, flightId, itemId, result);

            // Retornar el base64 local para la miniatura (Firebase es solo para backup)
            return base64Image;
          }
        } catch (e) {
          AppLogger.error(
              '💥 Error subiendo a Firebase: $e', e, 'PhotoService');
          AppLogger.error('❌ Subida fallida - No se guardará la foto', null,
              'PhotoService');
          return null; // No guardar nada si Firebase falla
        }
      } else {
        AppLogger.debug('🔒 Usuario no autenticado', null, 'PhotoService');
        AppLogger.warning(
            '⚠️ Firebase Storage requiere autenticación', null, 'PhotoService');
        return null; // No permitir fotos sin autenticación
      }

      // Esta línea nunca debería alcanzarse, pero por seguridad
      AppLogger.error('🚫 Código no debería llegar aquí', null, 'PhotoService');
      return null;
    } catch (e) {
      AppLogger.error('Error seleccionando foto: $e', e, 'PhotoService');
      return null;
    }
  }

  /// Obtiene la foto asociada a un elemento específico
  Future<String?> getPhoto({
    required String documentId,
    required String flightId,
    required String itemId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String key = _buildPhotoKey(documentId, flightId, itemId);
      return prefs.getString(key);
    } catch (e) {
      AppLogger.error('Error obteniendo foto: $e', e, 'PhotoService');
      return null;
    }
  }

  /// Verifica si la foto está sincronizada con Firebase
  Future<bool> isPhotoSynced({
    required String documentId,
    required String flightId,
    required String itemId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String metadataKey =
          '${_buildPhotoKey(documentId, flightId, itemId)}_firebase_metadata';
      final String? metadataJson = prefs.getString(metadataKey);

      if (metadataJson != null) {
        final Map<String, dynamic> metadata = jsonDecode(metadataJson);
        return metadata['is_synced'] == true;
      }

      return false;
    } catch (e) {
      AppLogger.error(
          'Error verificando sincronización: $e', e, 'PhotoService');
      return false;
    }
  }

  /// Obtiene metadatos de Firebase de una foto
  Future<Map<String, dynamic>?> getFirebaseMetadata({
    required String documentId,
    required String flightId,
    required String itemId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String metadataKey =
          '${_buildPhotoKey(documentId, flightId, itemId)}_firebase_metadata';
      final String? metadataJson = prefs.getString(metadataKey);

      if (metadataJson != null) {
        return jsonDecode(metadataJson);
      }

      return null;
    } catch (e) {
      AppLogger.error(
          'Error obteniendo metadatos de Firebase: $e', e, 'PhotoService');
      return null;
    }
  }

  /// Elimina la foto asociada a un elemento específico
  Future<bool> deletePhoto({
    required String documentId,
    required String flightId,
    required String itemId,
    String? itemType,
  }) async {
    try {
      AppLogger.info(
          '🗑️ Iniciando eliminación de foto...', null, 'PhotoService');

      // Intentar eliminar de Firebase primero si el usuario está autenticado
      final user = FirebaseAuth.instance.currentUser;
      bool firebaseDeleted = false;

      if (user != null && itemType != null) {
        try {
          AppLogger.info(
              '🔥 Eliminando de Firebase Storage...', null, 'PhotoService');
          firebaseDeleted = await FirebasePhotoService.deleteOversizePhoto(
            documentId: documentId,
            itemType: itemType,
            itemId: itemId,
          );

          if (firebaseDeleted) {
            AppLogger.info('✅ Foto eliminada de Firebase exitosamente', null,
                'PhotoService');
          } else {
            AppLogger.warning(
                '⚠️ No se encontró foto en Firebase para eliminar',
                null,
                'PhotoService');
          }
        } catch (e) {
          AppLogger.error(
              '💥 Error eliminando de Firebase: $e', e, 'PhotoService');
          // Continuar con eliminación local aunque Firebase falle
        }
      } else {
        AppLogger.debug('🔒 Usuario no autenticado o itemType no disponible',
            null, 'PhotoService');
      }

      // Eliminar datos locales
      AppLogger.debug('📱 Eliminando datos locales...', null, 'PhotoService');
      final prefs = await SharedPreferences.getInstance();
      final String key = _buildPhotoKey(documentId, flightId, itemId);
      final String metadataKey = '${key}_firebase_metadata';

      final bool localPhotoDeleted = await prefs.remove(key);
      final bool localMetadataDeleted = await prefs.remove(metadataKey);

      AppLogger.info(
          '📱 Datos locales eliminados - Foto: $localPhotoDeleted, Metadata: $localMetadataDeleted',
          null,
          'PhotoService');

      // Considerar exitoso si se eliminó de Firebase O localmente
      final bool success = firebaseDeleted || localPhotoDeleted;

      if (success) {
        AppLogger.info('✅ Foto eliminada completamente', null, 'PhotoService');
      } else {
        AppLogger.warning(
            '⚠️ No se encontró foto para eliminar', null, 'PhotoService');
      }

      return success;
    } catch (e) {
      AppLogger.error('💥 Error eliminando foto: $e', e, 'PhotoService');
      return false;
    }
  }

  /// Construye la clave única para almacenar la foto
  String _buildPhotoKey(String documentId, String flightId, String itemId) {
    return '$_photoKeysPrefix${documentId}_${flightId}_$itemId';
  }

  /// Guarda la foto en SharedPreferences
  Future<void> _savePhoto(
    String documentId,
    String flightId,
    String itemId,
    String base64Image,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final String key = _buildPhotoKey(documentId, flightId, itemId);
    await prefs.setString(key, base64Image);
  }

  /// Guarda metadatos de Firebase para indicar sincronización
  Future<void> _saveFirebaseMetadata(
    String documentId,
    String flightId,
    String itemId,
    Map<String, dynamic> firebaseResult,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final String metadataKey =
        '${_buildPhotoKey(documentId, flightId, itemId)}_firebase_metadata';
    final Map<String, dynamic> metadata = {
      'photo_id': firebaseResult['photo_id'],
      'synced_at': DateTime.now().toIso8601String(),
      'urls': firebaseResult['urls'],
      'photo_data':
          firebaseResult['photo_data'], // Incluir datos completos de la foto
      'is_synced': true,
    };
    await prefs.setString(metadataKey, jsonEncode(metadata));
  }

  /// Convierte base64 a bytes para mostrar la imagen
  static Uint8List? base64ToBytes(String? base64String) {
    if (base64String == null || base64String.isEmpty) return null;
    try {
      return base64Decode(base64String);
    } catch (e) {
      AppLogger.error(
          'Error convirtiendo base64 a bytes: $e', e, 'PhotoService');
      return null;
    }
  }
}
