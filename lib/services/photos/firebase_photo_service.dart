import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import '../../utils/logger.dart';
import '../../screens/home/flight_details/forms/models/oversize_item_types.dart';

/// Servicio para gestionar fotos en Firebase Storage y Firestore
class FirebasePhotoService {
  static const String _photosCollection = 'photos';
  static const String _oversizeSubcollection = 'oversize_photos';
  static const String _storageBasePath = 'oversize_photos';

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Genera una estructura de rutas organizadas por fecha y vuelo
  static String _buildOrganizedPath({
    required String documentId,
    required String itemType,
    required String itemId,
    String? flightId,
    DateTime? flightDate,
  }) {
    final DateTime date = flightDate ?? DateTime.now();
    final String year = date.year.toString();
    final String month = date.month.toString().padLeft(2, '0');

    // Calcular la semana del año
    final int dayOfYear = date.difference(DateTime(date.year, 1, 1)).inDays + 1;
    final int weekOfYear = ((dayOfYear - date.weekday + 10) / 7).floor();
    final String week = 'week_${weekOfYear.toString().padLeft(2, '0')}';

    final String day = date.day.toString().padLeft(2, '0');

    // Crear identificador de vuelo más descriptivo
    final String flightIdentifier =
        flightId != null ? '${flightId}_doc_$documentId' : 'doc_$documentId';

    // Estructura: oversize_photos/2024/01/week_03/15/LH123_doc_44316751/spare/35060740
    final String finalPath =
        '$_storageBasePath/$year/$month/$week/$day/$flightIdentifier/$itemType/$itemId';

    AppLogger.debug(
        '📅 Fecha del vuelo: ${date.toIso8601String().split('T')[0]}',
        null,
        'FirebasePhotoService');
    AppLogger.debug('🗓️ Año: $year, Mes: $month, Semana: $week, Día: $day',
        null, 'FirebasePhotoService');
    AppLogger.debug(
        '✈️ Vuelo: $flightIdentifier', null, 'FirebasePhotoService');

    return finalPath;
  }

  /// Sube una foto a Firebase Storage y guarda metadata en Firestore
  static Future<Map<String, dynamic>?> uploadOversizePhoto({
    required String documentId,
    required String itemType,
    required String itemId,
    required XFile photo,
    String? flightId,
    DateTime? flightDate,
  }) async {
    try {
      AppLogger.info(
          '🔄 Iniciando subida de foto...', null, 'FirebasePhotoService');
      AppLogger.debug(
          '📁 DocumentID: $documentId', null, 'FirebasePhotoService');
      AppLogger.debug('📋 ItemType: $itemType', null, 'FirebasePhotoService');
      AppLogger.debug('🔖 ItemID: $itemId', null, 'FirebasePhotoService');

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        AppLogger.error(
            '❌ Error - Usuario no autenticado', null, 'FirebasePhotoService');
        throw Exception('Usuario no autenticado');
      }

      AppLogger.debug('👤 Usuario autenticado: ${user.email}', null,
          'FirebasePhotoService');

      AppLogger.debug('🔍 Firebase Storage configurado correctamente', null,
          'FirebasePhotoService');

      // Generar ID único para la foto
      AppLogger.debug('🎲 Generando PhotoID...', null, 'FirebasePhotoService');
      final String photoId = _firestore.collection('temp').doc().id;
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      AppLogger.debug(
          '🆔 PhotoID generado: $photoId', null, 'FirebasePhotoService');

      // Leer los bytes de la imagen
      AppLogger.debug(
          '📖 Leyendo bytes de la imagen...', null, 'FirebasePhotoService');
      final Uint8List imageBytes = await photo.readAsBytes();
      AppLogger.debug('📏 Tamaño de imagen: ${imageBytes.length} bytes', null,
          'FirebasePhotoService');

      final String originalExtension = path.extension(photo.name).toLowerCase();
      final String safeExtension =
          originalExtension.isEmpty ? '.jpg' : originalExtension;
      AppLogger.debug(
          '📝 Extensión: $safeExtension', null, 'FirebasePhotoService');

      // Paths en Storage con nueva estructura organizada
      final String basePath = _buildOrganizedPath(
        documentId: documentId,
        itemType: itemType,
        itemId: itemId,
        flightId: flightId,
        flightDate: flightDate,
      );
      AppLogger.info(
          '🗂️ Estructura organizada: $basePath', null, 'FirebasePhotoService');
      final String originalPath = '$basePath/original_$timestamp$safeExtension';
      AppLogger.debug(
          '📂 Path completo: $originalPath', null, 'FirebasePhotoService');

      // Subir imagen original
      AppLogger.info('⬆️ Iniciando subida a Firebase Storage...', null,
          'FirebasePhotoService');
      final Reference originalRef = _storage.ref().child(originalPath);
      final UploadTask originalUpload = originalRef.putData(
        imageBytes,
        SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {
            'document_id': documentId,
            'item_type': itemType,
            'item_id': itemId,
            'photo_id': photoId,
            'uploaded_by': user.uid,
          },
        ),
      );

      AppLogger.debug('⏳ Esperando confirmación de subida...', null,
          'FirebasePhotoService');

      // Agregar timeout para evitar que se cuelgue indefinidamente
      final TaskSnapshot originalSnapshot = await originalUpload.timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          originalUpload.cancel();
          throw Exception(
              'Timeout: La subida a Firebase Storage tardó más de 30 segundos');
        },
      );

      AppLogger.info(
          '✅ Archivo subido exitosamente', null, 'FirebasePhotoService');

      AppLogger.debug(
          '🔗 Obteniendo URL de descarga...', null, 'FirebasePhotoService');
      final String originalUrl = await originalSnapshot.ref.getDownloadURL();
      AppLogger.debug('🌐 URL obtenida: ${originalUrl.substring(0, 50)}...',
          null, 'FirebasePhotoService');

      // Guardar metadata en Firestore
      AppLogger.info('💾 Guardando metadata en Firestore...', null,
          'FirebasePhotoService');

      // Debug: Verificar la construcción del item_ref
      final String collectionName = _getCollectionNameForItemType(itemType);
      final String itemRef = 'flights/$documentId/$collectionName/$itemId';
      AppLogger.info(
          '📍 item_ref construido: "$itemRef"', null, 'FirebasePhotoService');

      final Map<String, dynamic> photoData = {
        'item_type': itemType,
        'item_id': itemId,
        'item_ref': itemRef,
        'storage_path': basePath,
        'filename_prefix': timestamp,
        'url': originalUrl,
        'path': originalPath,
        'size_bytes': imageBytes.length,
        'uploaded_at': FieldValue.serverTimestamp(),
        'uploaded_by': {
          'uid': user.uid,
          'email': user.email,
          'displayName': user.displayName,
        },
        'photo_type': 'oversize',
        'metadata': {
          'original_name': photo.name,
          'mime_type': 'image/jpeg',
          'file_size': imageBytes.length,
        },
      };

      // Log detallado de los datos que se van a guardar
      AppLogger.debug(
          '📝 Datos a guardar en Firestore:', null, 'FirebasePhotoService');
      AppLogger.debug('  🆔 photoId: $photoId', null, 'FirebasePhotoService');
      AppLogger.debug('  📂 Ruta: photos/$documentId/oversize_photos/$photoId',
          null, 'FirebasePhotoService');
      AppLogger.debug(
          '  🔖 item_type: "$itemType"', null, 'FirebasePhotoService');
      AppLogger.debug('  🏷️ item_id: "$itemId"', null, 'FirebasePhotoService');
      AppLogger.debug(
          '  📍 item_ref: "$itemRef"', null, 'FirebasePhotoService');

      await _firestore
          .collection(_photosCollection)
          .doc(documentId)
          .collection(_oversizeSubcollection)
          .doc(photoId)
          .set(photoData);

      AppLogger.info(
          '🎉 Metadata guardada exitosamente', null, 'FirebasePhotoService');
      AppLogger.info(
          '✨ Proceso completado exitosamente', null, 'FirebasePhotoService');

      return {
        'photo_id': photoId,
        'photo_data': _createSerializablePhotoData(photoData),
        'url': originalUrl,
      };
    } catch (e) {
      AppLogger.error(
          '💥 Error durante la subida: $e', e, 'FirebasePhotoService');
      AppLogger.debug('🔍 Stack trace: ${StackTrace.current}', null,
          'FirebasePhotoService');
      rethrow;
    }
  }

  /// Obtiene todas las fotos de un elemento específico
  static Future<List<Map<String, dynamic>>> getOversizePhotos({
    required String documentId,
    required String itemType,
    required String itemId,
  }) async {
    try {
      AppLogger.info('🔍 Iniciando búsqueda de fotos en Firebase', null,
          'FirebasePhotoService');
      AppLogger.debug(
          '📋 Parámetros: documentId="$documentId", itemType="$itemType", itemId="$itemId"',
          null,
          'FirebasePhotoService');

      // Construir la ruta de la consulta para logging
      final String queryPath = 'photos/$documentId/oversize_photos';
      AppLogger.debug(
          '📂 Ruta de consulta: $queryPath', null, 'FirebasePhotoService');
      AppLogger.debug(
          '🔍 Filtros: item_id == "$itemId" AND item_type == "$itemType"',
          null,
          'FirebasePhotoService');

      final QuerySnapshot snapshot = await _firestore
          .collection(_photosCollection)
          .doc(documentId)
          .collection(_oversizeSubcollection)
          .where('item_id', isEqualTo: itemId)
          .where('item_type', isEqualTo: itemType)
          .orderBy('uploaded_at', descending: true)
          .get();

      AppLogger.info(
          '📊 Consulta completada. Documentos encontrados: ${snapshot.docs.length}',
          null,
          'FirebasePhotoService');

      if (snapshot.docs.isEmpty) {
        AppLogger.warning('❌ No se encontraron fotos para estos parámetros',
            null, 'FirebasePhotoService');

        // Hacer una consulta adicional para ver TODAS las fotos de este documentId
        AppLogger.debug('🔍 Verificando si hay fotos para este documentId...',
            null, 'FirebasePhotoService');

        final QuerySnapshot allPhotosSnapshot = await _firestore
            .collection(_photosCollection)
            .doc(documentId)
            .collection(_oversizeSubcollection)
            .get();

        AppLogger.debug(
            '📊 Total de fotos en el documento: ${allPhotosSnapshot.docs.length}',
            null,
            'FirebasePhotoService');

        if (allPhotosSnapshot.docs.isNotEmpty) {
          AppLogger.debug(
              '📝 Muestras de fotos existentes:', null, 'FirebasePhotoService');
          for (int i = 0; i < allPhotosSnapshot.docs.length && i < 3; i++) {
            final doc = allPhotosSnapshot.docs[i];
            final data = doc.data() as Map<String, dynamic>;
            AppLogger.debug(
                '  📸 Foto ${i + 1}: itemId="${data['item_id']}", itemType="${data['item_type']}"',
                null,
                'FirebasePhotoService');
          }
        }

        return [];
      }

      final List<Map<String, dynamic>> result = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'photo_id': doc.id,
          ...data,
        };
      }).toList();

      AppLogger.info(
          '✅ Se encontraron ${result.length} fotos para itemId: $itemId',
          null,
          'FirebasePhotoService');

      return result;
    } catch (e) {
      AppLogger.error('💥 Error obteniendo fotos de Firebase: $e', e,
          'FirebasePhotoService');
      AppLogger.debug('🔍 Stack trace completo: ${StackTrace.current}', null,
          'FirebasePhotoService');
      return [];
    }
  }

  /// Obtiene todas las fotos oversize de un vuelo
  static Future<List<Map<String, dynamic>>> getAllOversizePhotos({
    required String documentId,
  }) async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection(_photosCollection)
          .doc(documentId)
          .collection(_oversizeSubcollection)
          .orderBy('uploaded_at', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'photo_id': doc.id,
          ...data,
        };
      }).toList();
    } catch (e) {
      AppLogger.error('Error obteniendo todas las fotos oversize: $e', e,
          'FirebasePhotoService');
      return [];
    }
  }

  /// Elimina una foto específica por photoId o por identificadores del item
  static Future<bool> deleteOversizePhoto({
    required String documentId,
    String? photoId,
    String? itemType,
    String? itemId,
  }) async {
    if (photoId == null && (itemType == null || itemId == null)) {
      AppLogger.error('Se requiere photoId o itemType+itemId para eliminar',
          null, 'FirebasePhotoService');
      return false;
    }
    try {
      AppLogger.info(
          '🗑️ Iniciando eliminación de foto...', null, 'FirebasePhotoService');

      // Si no tenemos photoId, buscar por itemType e itemId
      DocumentSnapshot? photoDoc;
      if (photoId != null) {
        AppLogger.debug(
            '🔍 Buscando por photoId: $photoId', null, 'FirebasePhotoService');
        photoDoc = await _firestore
            .collection(_photosCollection)
            .doc(documentId)
            .collection(_oversizeSubcollection)
            .doc(photoId)
            .get();
      } else {
        AppLogger.debug('🔍 Buscando por itemType: $itemType, itemId: $itemId',
            null, 'FirebasePhotoService');
        final QuerySnapshot querySnapshot = await _firestore
            .collection(_photosCollection)
            .doc(documentId)
            .collection(_oversizeSubcollection)
            .where('item_type', isEqualTo: itemType)
            .where('item_id', isEqualTo: itemId)
            .limit(1)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          photoDoc = querySnapshot.docs.first;
        }
      }

      if (photoDoc == null || !photoDoc.exists) {
        AppLogger.warning('Foto no encontrada', null, 'FirebasePhotoService');
        return false;
      }

      final Map<String, dynamic> photoData =
          photoDoc.data() as Map<String, dynamic>;
      final String? imagePath = photoData['path'];

      if (imagePath != null) {
        AppLogger.debug('📁 Eliminando archivo de Storage...', null,
            'FirebasePhotoService');

        try {
          AppLogger.debug(
              '🗑️ Eliminando: $imagePath', null, 'FirebasePhotoService');
          await _storage.ref().child(imagePath).delete();
          AppLogger.info('🗑️ Archivo eliminado de Storage exitosamente', null,
              'FirebasePhotoService');
        } catch (e) {
          AppLogger.warning(
              '⚠️ Error eliminando archivo: $e', e, 'FirebasePhotoService');
        }
      } else {
        AppLogger.warning('⚠️ No se encontró path en los datos de la foto',
            null, 'FirebasePhotoService');
      }

      // Eliminar documento de Firestore
      AppLogger.debug('📄 Eliminando documento de Firestore...', null,
          'FirebasePhotoService');
      await photoDoc.reference.delete();

      AppLogger.info('✅ Foto eliminada completamente de Firebase', null,
          'FirebasePhotoService');
      return true;
    } catch (e) {
      AppLogger.error(
          'Error eliminando foto de Firebase: $e', e, 'FirebasePhotoService');
      return false;
    }
  }

  /// Limpia fotos huérfanas (elementos que ya no existen)
  static Future<void> cleanupOrphanedPhotos({
    required String documentId,
  }) async {
    try {
      final List<Map<String, dynamic>> allPhotos = await getAllOversizePhotos(
        documentId: documentId,
      );

      for (final photo in allPhotos) {
        final String itemRef = photo['item_ref'] ?? '';
        if (itemRef.isNotEmpty) {
          // Verificar si el elemento padre aún existe
          final DocumentSnapshot itemDoc = await _firestore.doc(itemRef).get();

          if (!itemDoc.exists ||
              (itemDoc.data() as Map<String, dynamic>?)
                      ?.containsKey('deleted') ==
                  true) {
            // El elemento ya no existe o está eliminado, eliminar la foto
            await deleteOversizePhoto(
              documentId: documentId,
              photoId: photo['photo_id'],
            );
          }
        }
      }
    } catch (e) {
      AppLogger.error(
          'Error limpiando fotos huérfanas: $e', e, 'FirebasePhotoService');
    }
  }

  /// Obtiene el nombre correcto de la colección para un tipo de item
  static String _getCollectionNameForItemType(String itemType) {
    final OversizeItemType type = OversizeItemTypeUtils.stringToType(itemType);
    final String collectionName =
        OversizeItemTypeUtils.collectionNameForType(type);

    // Debug log para verificar la conversión
    AppLogger.info('🔄 Conversión de tipo: "$itemType" -> "$collectionName"',
        null, 'FirebasePhotoService');

    return collectionName;
  }

  /// Crea una versión serializable de los datos de la foto
  static Map<String, dynamic> _createSerializablePhotoData(
      Map<String, dynamic>? photoData) {
    if (photoData == null) return {};

    final Map<String, dynamic> serializable =
        Map<String, dynamic>.from(photoData);
    // Reemplazar FieldValue.serverTimestamp() con timestamp actual
    serializable['uploaded_at'] = DateTime.now().toIso8601String();

    return serializable;
  }
}
