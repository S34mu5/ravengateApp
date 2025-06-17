import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../../utils/logger.dart';

/// Servicio para manejo de fotos de elementos sobredimensionados
/// NOTA: Requiere agregar image_picker y firebase_storage al pubspec.yaml
class OversizePhotoService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Pregunta al usuario si desea tomar una foto y prepara para procesar
  static Future<bool> promptForPhoto({
    required BuildContext context,
    required String flightId,
    required String documentId,
    required List<String> itemDocumentIds,
    required String itemType,
  }) async {
    AppLogger.info(
        'OversizePhotoService.promptForPhoto iniciado - items: ${itemDocumentIds.length}, type: $itemType');

    final bool? shouldTakePhoto = await _showPhotoConfirmationDialog(context);
    if (shouldTakePhoto != true) return false;

    try {
      // TODO: Aquí iría la captura real de foto cuando se agreguen las dependencias
      // final photo = await _capturePhoto();
      // if (photo == null) return false;

      // Por ahora, simulamos que se tomó una foto y actualizamos los documentos
      await _updateDocumentsWithPhotoFlag(
        documentId: documentId,
        itemDocumentIds: itemDocumentIds,
        itemType: itemType,
        hasPhoto: true,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '✅ Foto programada para ${itemDocumentIds.length} elemento(s) (funcionalidad en desarrollo)'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }

      return true;
    } catch (e) {
      AppLogger.error('Error en proceso de foto', e);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al procesar foto: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }
  }

  /// Muestra diálogo de confirmación para tomar foto
  static Future<bool?> _showPhotoConfirmationDialog(
      BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.camera_alt, color: Colors.amber),
            SizedBox(width: 8),
            Text('Capturar Foto'),
          ],
        ),
        content: const Text(
          '¿Deseas tomar una foto de este(os) elemento(s)?\n\n'
          'La foto se asociará a todos los elementos registrados en esta operación.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.white,
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.camera_alt, size: 18),
                SizedBox(width: 4),
                Text('Sí, tomar foto'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Actualiza los documentos con la información de foto
  static Future<void> _updateDocumentsWithPhotoFlag({
    required String documentId,
    required List<String> itemDocumentIds,
    required String itemType,
    required bool hasPhoto,
  }) async {
    final WriteBatch batch = _firestore.batch();

    for (final itemDocId in itemDocumentIds) {
      final DocumentReference itemRef = _firestore
          .collection('flights')
          .doc(documentId)
          .collection(_getCollectionNameForType(itemType))
          .doc(itemDocId);

      batch.update(itemRef, {
        'has_photo': hasPhoto,
        'photo_pending':
            hasPhoto, // Flag temporal hasta implementar upload real
        'photo_request_timestamp': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
    AppLogger.info(
        'Documentos actualizados con flag de foto: ${itemDocumentIds.length} items');
  }

  /// Obtiene el nombre de colección para un tipo de item
  static String _getCollectionNameForType(String itemType) {
    switch (itemType) {
      case 'trolley':
        return 'oversize_trolleys';
      case 'avih':
        return 'oversize_avihs';
      case 'weap':
        return 'oversize_weaps';
      case 'spare':
      default:
        return 'oversize_items';
    }
  }

  /// Genera la ruta de almacenamiento para la foto
  static String generateStoragePath({
    required String flightId,
    required String documentId,
  }) {
    final DateTime now = DateTime.now();
    final String year = now.year.toString();
    final String month = now.month.toString().padLeft(2, '0');
    final String week = _getWeekOfYear(now).toString().padLeft(2, '0');

    // Ruta: photos/oversize/año/mes/semana/numerodevuelofecha_docid_timestamp
    final String fileName =
        '${flightId}_${documentId}_${now.millisecondsSinceEpoch}';
    return 'photos/oversize/$year/$month/$week/$fileName';
  }

  /// Calcula el número de semana del año
  static int _getWeekOfYear(DateTime date) {
    final DateTime firstDayOfYear = DateTime(date.year, 1, 1);
    final int daysSinceFirstDay = date.difference(firstDayOfYear).inDays;
    return ((daysSinceFirstDay + firstDayOfYear.weekday - 1) / 7).ceil();
  }
}
