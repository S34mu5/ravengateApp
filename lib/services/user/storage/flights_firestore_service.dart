import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../utils/logger.dart';

/// Servicio para manejar todas las operaciones de Firestore relacionadas con vuelos
class FlightsFirestoreService {
  /// Guardar un vuelo en Firestore
  static Future<bool> saveFlight(
      String userId, Map<String, dynamic> flightData) async {
    try {
      // Reference to user's flights collection
      final userFlightsRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('saved_flights');

      // First, ensure the user document exists with readable information
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Set user data for better readability in Firebase console
        await FirebaseFirestore.instance.collection('users').doc(userId).set({
          'email': user.email,
          'displayName': user.displayName,
          'last_active': FieldValue.serverTimestamp(),
          // Don't overwrite existing data
        }, SetOptions(merge: true));
      }

      // Check if flight already exists by flight_ref or flight_id
      QuerySnapshot? existingFlights;
      bool flightAlreadyExists = false;
      bool flightWasArchived = false;
      String? existingDocId;

      // IMPORTANTE: Usar ÚNICAMENTE flight_ref para identificar vuelos
      // No usar flight_id como criterio de búsqueda para evitar confusiones
      if (flightData['flight_ref'] != null) {
        existingFlights = await userFlightsRef
            .where('flight_ref', isEqualTo: flightData['flight_ref'])
            .get();

        if (existingFlights.docs.isNotEmpty) {
          // Flight already exists by reference
          flightAlreadyExists = true;
          existingDocId = existingFlights.docs.first.id;

          // Check if it was archived
          final docData =
              existingFlights.docs.first.data() as Map<String, dynamic>;
          flightWasArchived = docData['archived'] == true;
        }
      } else {
        AppLogger.error(
            'El vuelo no tiene flight_ref, no se puede guardar correctamente');
        return false;
      }

      // If flight exists and was archived, restore it
      if (flightAlreadyExists && flightWasArchived && existingDocId != null) {
        await userFlightsRef.doc(existingDocId).update({
          'archived': false,
          'was_archived': true, // Flag to indicate it was previously archived
          'restored_at': DateTime.now().toIso8601String(),
          'saved_at':
              DateTime.now().toIso8601String(), // Update saved_at to now
        });

        // Update the reference data with was_archived flag for UI to use
        flightData['was_archived'] = true;

        return true; // Return true because flight was restored (equivalent to adding it)
      }

      // If flight exists but was not archived, just return false
      if (flightAlreadyExists && !flightWasArchived) {
        return false;
      }

      // Add flight to Firestore if it doesn't exist
      await userFlightsRef.add({
        ...flightData,
        'archived': false, // Explicitly set archived to false for new flights
        'saved_at_server': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      AppLogger.error('Error saving flight to Firestore', e);
      rethrow;
    }
  }

  /// Obtener referencias de vuelos desde Firestore
  static Future<List<Map<String, dynamic>>> getFlightRefs(String userId) async {
    try {
      // Reference to user's flights collection
      final userFlightsRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('saved_flights');

      try {
        // Intentar con una consulta más simple que no requiera índices compuestos
        // Primero, intentar obtener documentos no archivados
        final flightsSnapshot =
            await userFlightsRef.where('archived', isNotEqualTo: true).get();

        // Si el filtro falla, usar query simple y ordenar en memoria
        if (flightsSnapshot.docs.isNotEmpty) {
          // Convertir a List<Map<String, dynamic>> y ordenar en memoria
          List<Map<String, dynamic>> results = flightsSnapshot.docs.map((doc) {
            final data = doc.data();
            return {
              ...data,
              'doc_id': doc.id,
            };
          }).toList();

          // Ordenar por fecha de guardado (de más reciente a más antiguo)
          results.sort((a, b) {
            String dateA = a['saved_at'] ?? '';
            String dateB = b['saved_at'] ?? '';
            // Orden descendente (más reciente primero)
            return dateB.compareTo(dateA);
          });

          return results;
        } else {
          // Intentar obtener todos los documentos
          final allFlightsSnapshot = await userFlightsRef.get();

          // Procesar y filtrar manualmente los documentos
          final List<Map<String, dynamic>> result = [];

          for (final doc in allFlightsSnapshot.docs) {
            final data = doc.data();

            // Solo incluir documentos no archivados
            if (data['archived'] != true) {
              // Añadir doc_id al mapa
              result.add({
                ...data,
                'doc_id': doc.id,
              });
            }
          }

          // Ordenar por fecha de guardado (de más reciente a más antiguo)
          result.sort((a, b) {
            String dateA = a['saved_at'] ?? '';
            String dateB = b['saved_at'] ?? '';
            // Orden descendente (más reciente primero)
            return dateB.compareTo(dateA);
          });

          return result;
        }
      } catch (e) {
        // Si falla (probablemente por falta de índices compuestos), usar una consulta más simple
        AppLogger.warning('Query filter failed, using simple approach', e);

        // Redefinir userFlightsRef dentro del catch
        final userFlightsRef = FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('saved_flights');

        // Obtener todos los documentos sin filtro
        final allFlightsSnapshot = await userFlightsRef.get();

        // Procesar y filtrar manualmente los documentos
        final List<Map<String, dynamic>> result = [];

        for (final doc in allFlightsSnapshot.docs) {
          final data = doc.data();

          // Solo incluir documentos no archivados
          if (data['archived'] != true) {
            // Añadir doc_id al mapa
            result.add({
              ...data,
              'doc_id': doc.id,
            });
          }
        }

        // Ordenar por fecha de guardado (de más reciente a más antiguo)
        result.sort((a, b) {
          String dateA = a['saved_at'] ?? '';
          String dateB = b['saved_at'] ?? '';
          // Orden descendente (más reciente primero)
          return dateB.compareTo(dateA);
        });

        return result;
      }
    } catch (e) {
      AppLogger.error('Error getting flight refs from Firestore', e);
      // No propagar el error, simplemente devolver una lista vacía
      return [];
    }
  }

  /// Eliminar un vuelo de Firestore
  static Future<bool> removeFlight(String userId, String docId) async {
    try {
      // Reference to user's flights collection
      final userFlightsRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('saved_flights');

      // Intentar obtener y eliminar el documento directamente por su ID
      try {
        // Verificar si el documento existe
        final docSnapshot = await userFlightsRef.doc(docId).get();

        if (docSnapshot.exists) {
          // Si existe, eliminarlo
          await docSnapshot.reference.delete();
          AppLogger.info(
              'Documento con ID $docId eliminado correctamente de Firestore');
          return true;
        } else {
          AppLogger.warning(
              'No se encontró el documento con ID $docId en Firestore');
          return false;
        }
      } catch (e) {
        AppLogger.error(
            'Error al acceder al documento con ID $docId en Firestore', e);
        return false;
      }
    } catch (e) {
      AppLogger.error('Error removing flight from Firestore', e);
      rethrow;
    }
  }

  /// Archivar un vuelo en Firestore
  static Future<bool> archiveFlight(String userId, String docId) async {
    try {
      // Referencias a las colecciones
      final userFlightsRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('saved_flights');

      final archivedFlightsRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('archived_flights');

      try {
        // Obtener el documento original
        final docSnapshot = await userFlightsRef.doc(docId).get();

        if (docSnapshot.exists) {
          // Si el documento existe, copiarlo a la colección de vuelos archivados
          // Obtener los datos del documento original
          final flightData = docSnapshot.data() as Map<String, dynamic>;

          // Agregar metadatos de archivo
          final archivedData = {
            ...flightData,
            'archived': true,
            'archived_at': DateTime.now().toIso8601String(),
            'archived_date': DateTime.now().toIso8601String().split('T')[0],
            'original_doc_id': docId, // Mantener referencia al ID original
          };

          // Crear el documento en la colección de vuelos archivados
          final archivedDocRef = await archivedFlightsRef.add(archivedData);

          // Actualizar la colección archived_dates para este vuelo
          final archivedDate = archivedData['archived_date'] as String;
          await updateArchivedDateSummary(userId, archivedDate);

          // Opcionalmente: eliminar o marcar el vuelo original
          // Aquí puedes elegir entre eliminarlo completamente o marcarlo como archivado
          await userFlightsRef.doc(docId).update({
            'archived': true,
            'archived_at': DateTime.now().toIso8601String(),
            'archived_doc_id': archivedDocRef.id, // Referencia cruzada
          });

          return true;
        } else {
          AppLogger.warning(
              'No se encontró el documento con ID $docId para archivar');
          return false;
        }
      } catch (e) {
        AppLogger.error('Error al acceder al documento con ID $docId', e);
        return false;
      }
    } catch (e) {
      AppLogger.error('Error archiving flight in Firestore', e);
      return false;
    }
  }

  /// Actualizar o crear el documento de resumen de la fecha de archivo
  static Future<void> updateArchivedDateSummary(
      String userId, String date) async {
    try {
      final archiveDateRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('archived_dates')
          .doc(date);

      // Obtener el documento actual o crear uno nuevo
      final docSnapshot = await archiveDateRef.get();

      if (docSnapshot.exists) {
        // Incrementar el contador
        await archiveDateRef.update({
          'count': FieldValue.increment(1),
          'last_updated': FieldValue.serverTimestamp(),
        });
      } else {
        // Crear nuevo documento
        await archiveDateRef.set({
          'date': date,
          'count': 1,
          'created_at': FieldValue.serverTimestamp(),
          'last_updated': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      AppLogger.error('Error al actualizar resumen de fecha de archivo', e);
    }
  }

  /// Decrementar el contador de vuelos archivados para una fecha
  static Future<void> decrementArchivedDateCounter(
      String userId, String date) async {
    try {
      final archiveDateRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('archived_dates')
          .doc(date);

      // Obtener el documento actual
      final docSnapshot = await archiveDateRef.get();

      if (docSnapshot.exists) {
        final data = docSnapshot.data() as Map<String, dynamic>;
        final currentCount = data['count'] as int? ?? 1;

        if (currentCount <= 1) {
          // Si es el último vuelo para esta fecha, eliminar el documento
          await archiveDateRef.delete();
        } else {
          // Decrementar el contador
          await archiveDateRef.update({
            'count': FieldValue.increment(-1),
            'last_updated': FieldValue.serverTimestamp(),
          });
        }
      }
    } catch (e) {
      AppLogger.error('Error al actualizar contador de fecha archivada', e);
    }
  }

  /// Restaurar un vuelo archivado
  static Future<bool> restoreFlight(String userId, String docId) async {
    try {
      // Get reference to user's collections
      final savedFlightsRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('saved_flights');

      final archivedFlightsRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('archived_flights');

      // IMPORTANTE: Primero buscar en archived_flights, no en saved_flights
      final archivedDocSnapshot = await archivedFlightsRef.doc(docId).get();

      if (!archivedDocSnapshot.exists) {
        AppLogger.warning(
            'No se encontró el documento con ID $docId en archived_flights');
        return false;
      }

      // Obtener los datos del documento archivado
      final archivedData = archivedDocSnapshot.data() as Map<String, dynamic>;

      // Preparar datos para guardar en saved_flights
      final dataToRestore = Map<String, dynamic>.from(archivedData);

      // Actualizar campos
      dataToRestore['archived'] = false;
      dataToRestore['was_archived'] = true;
      dataToRestore['restored_at'] = DateTime.now().toIso8601String();

      // Añadir a saved_flights
      await savedFlightsRef.add(dataToRestore);

      // Eliminar de archived_flights
      await archivedFlightsRef.doc(docId).delete();

      // Actualizar el contador en la colección de fechas si es necesario
      final archivedDate = archivedData['archived_date'] as String?;
      if (archivedDate != null) {
        await decrementArchivedDateCounter(userId, archivedDate);
      }

      return true;
    } catch (e) {
      AppLogger.error('Error restoring flight in Firestore', e);
      return false;
    }
  }

  /// Eliminar permanentemente un vuelo archivado
  static Future<bool> permanentlyDeleteFlight(
      String userId, String docId) async {
    try {
      // Si usuario está autenticado, eliminar de Firestore
      final archivedFlightsRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('archived_flights');

      // Obtener el documento para verificar su fecha de archivo antes de eliminarlo
      final docSnapshot = await archivedFlightsRef.doc(docId).get();

      if (!docSnapshot.exists) {
        AppLogger.warning(
            'No se encontró el documento con ID $docId para eliminar');
        return false;
      }

      // Obtener la fecha de archivo para actualizar el contador
      final data = docSnapshot.data() as Map<String, dynamic>;
      final archivedDate = data['archived_date'] as String?;

      // Eliminar el documento
      await archivedFlightsRef.doc(docId).delete();

      // Actualizar el contador en la colección de fechas si el vuelo estaba archivado
      if (archivedDate != null) {
        await decrementArchivedDateCounter(userId, archivedDate);
      }

      return true;
    } catch (e) {
      AppLogger.error('Error permanently deleting flight from Firestore', e);
      return false;
    }
  }

  /// Actualizar información del usuario en Firestore
  /// Esto ayuda a mejorar la legibilidad en la consola de Firebase
  static Future<void> updateUserInfo() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Update user document with latest information
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'email': user.email,
          'displayName': user.displayName ?? 'Usuario sin nombre',
          'photoURL': user.photoURL,
          'last_login': FieldValue.serverTimestamp(),
          'user_readable_id': user.email?.split('@')[0] ??
              'unknown', // Create a readable ID from email
        }, SetOptions(merge: true));
      }
    } catch (e) {
      AppLogger.error('Error updating user info', e);
      // Non-critical error, don't throw
    }
  }
}
