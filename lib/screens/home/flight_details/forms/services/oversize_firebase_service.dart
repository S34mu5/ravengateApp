import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/oversize_item_types.dart';
import '../../../../../utils/logger.dart';

/// Servicio para operaciones de Firebase relacionadas con elementos sobredimensionados
class OversizeFirebaseService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Registra múltiples elementos sobredimensionados
  static Future<void> registerItems({
    required String documentId,
    required String flightId,
    required OversizeItemType type,
    required int count,
    required bool isFragile,
    required bool requiresSpecialHandling,
    required String specialHandlingDetails,
  }) async {
    final User? user = _auth.currentUser;
    if (user == null) {
      throw Exception('Usuario no autenticado');
    }

    final String collectionName =
        OversizeItemTypeUtils.collectionNameForType(type);

    // Crear un batch para registrar múltiples documentos
    WriteBatch batch = _firestore.batch();

    // Crear un documento separado para cada item (cada uno con count = 1)
    for (int i = 0; i < count; i++) {
      final DocumentReference docRef = _firestore
          .collection('flights')
          .doc(documentId)
          .collection(collectionName)
          .doc();

      batch.set(docRef, {
        'timestamp': FieldValue.serverTimestamp(),
        'count': 1, // Siempre 1 por documento
        'flight_id': flightId,
        'document_id': documentId,
        'user_id': user.uid,
        'user_email': user.email,
        'action': 'registry',
        'type': type.name,
        'is_fragile': isFragile,
        'requires_special_handling': requiresSpecialHandling,
        'special_handling_details': specialHandlingDetails,
      });
    }

    // Ejecutar el batch
    await batch.commit();
  }

  /// Obtiene el conteo actual para un tipo específico
  static Future<int> getCurrentCount({
    required String documentId,
    required OversizeItemType type,
  }) async {
    try {
      final String collectionName =
          OversizeItemTypeUtils.collectionNameForType(type);

      final QuerySnapshot snapshot = await _firestore
          .collection('flights')
          .doc(documentId)
          .collection(collectionName)
          .get();

      int totalCount = 0;
      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        // Solo sumamos si no está eliminado
        if (!(data['deleted'] ?? false)) {
          totalCount += (data['count'] as int? ?? 0);
        }
      }

      return totalCount;
    } catch (e) {
      AppLogger.error('Error obteniendo conteo actual', e);
      rethrow;
    }
  }

  /// Obtiene el historial de elementos
  static Future<List<Map<String, dynamic>>> getItemHistory({
    required String documentId,
    required OversizeItemType type,
    int limit = 50,
  }) async {
    try {
      final String collectionName =
          OversizeItemTypeUtils.collectionNameForType(type);

      final QuerySnapshot snapshot = await _firestore
          .collection('flights')
          .doc(documentId)
          .collection(collectionName)
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();
    } catch (e) {
      AppLogger.error('Error obteniendo historial de elementos', e);
      rethrow;
    }
  }

  /// Marca un elemento como eliminado
  static Future<void> markItemAsDeleted({
    required String documentId,
    required OversizeItemType type,
    required String docId,
  }) async {
    final User? user = _auth.currentUser;
    if (user == null) {
      throw Exception('Usuario no autenticado');
    }

    final String collectionName =
        OversizeItemTypeUtils.collectionNameForType(type);

    await _firestore
        .collection('flights')
        .doc(documentId)
        .collection(collectionName)
        .doc(docId)
        .set(
      {
        'deleted': true,
        'deleted_at': FieldValue.serverTimestamp(),
        'deleted_by_user_id': user.uid,
        'deleted_by_user_email': user.email,
      },
      SetOptions(merge: true),
    );
  }

  /// Elimina todos los elementos de un tipo
  static Future<int> deleteAllItems({
    required String documentId,
    required OversizeItemType type,
  }) async {
    final User? user = _auth.currentUser;
    if (user == null) {
      throw Exception('Usuario no autenticado');
    }

    final String collectionName =
        OversizeItemTypeUtils.collectionNameForType(type);

    final QuerySnapshot snapshot = await _firestore
        .collection('flights')
        .doc(documentId)
        .collection(collectionName)
        .get();

    final docsToDelete = snapshot.docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return data['deleted'] != true;
    }).toList();

    if (docsToDelete.isEmpty) {
      return 0;
    }

    // Marcar todos como eliminados usando batch
    WriteBatch batch = _firestore.batch();
    for (final doc in docsToDelete) {
      batch.update(doc.reference, {
        'deleted': true,
        'deleted_at': FieldValue.serverTimestamp(),
        'deleted_by_user_id': user.uid,
        'deleted_by_user_email': user.email,
      });
    }

    await batch.commit();
    return docsToDelete.length;
  }
}
