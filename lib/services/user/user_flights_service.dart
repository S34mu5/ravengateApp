import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import '../../utils/airline_helper.dart';
import '../../utils/logger.dart';

// Importar los nuevos servicios modulares
import 'models/archived_flight_date.dart';
import 'storage/flights_firestore_service.dart';
import 'storage/flights_local_storage.dart';
import 'storage/flights_cache_service.dart';

/// Service to manage user's saved flights (Refactored Version)
///
/// Esta versión refactorizada utiliza servicios modulares para mejor organización:
/// - FlightsFirestoreService: Operaciones de Firestore
/// - FlightsLocalStorage: Operaciones de almacenamiento local
/// - FlightsCacheService: Sistema de caché
class UserFlightsService {
  static const String _userArchivedFlightsKey = 'user_archived_flights';

  /// Save a flight to user's saved flights list
  /// Returns true if the flight was added, false if it was already in the list
  static Future<bool> saveFlight(Map<String, dynamic> flight) async {
    try {
      // Get current user
      final user = FirebaseAuth.instance.currentUser;

      // IMPORTANTE: flight_ref es la referencia única al documento original en la colección 'flights'
      // Nunca debe usarse flight_id como identificador único, ya que pueden existir múltiples vuelos
      // con el mismo código de vuelo (flight_id) pero en diferentes fechas
      final Map<String, dynamic> savedFlightData = {
        'flight_ref': flight['id'], // Reference to original flight document
        'flight_id': flight[
            'flight_id'], // Solo para mostrar el código del vuelo, no para identificación
        'saved_at': DateTime.now().toIso8601String(),
      };

      // If user is logged in, add user info
      if (user != null) {
        savedFlightData['saved_by_user'] = {
          'uid': user.uid,
          'email': user.email,
          'displayName': user.displayName,
        };

        // Save to Firestore with reference approach
        final result =
            await FlightsFirestoreService.saveFlight(user.uid, savedFlightData);

        // If successful and was a restoration, mark the original flight as restored
        if (result && savedFlightData['was_archived'] == true) {
          flight['was_archived'] = true;
        }

        // Invalidar la caché cuando se añade un nuevo vuelo
        await FlightsCacheService.invalidateFlightsCache();

        return result;
      } else {
        // For local storage, we still need all flight details
        // but we'll ensure we have the reference for future compatibility
        final processedFlight = _processFlightForStorage(flight);
        processedFlight['flight_ref'] = flight['id']; // Add reference

        // Invalidar la caché cuando se añade un nuevo vuelo
        await FlightsCacheService.invalidateFlightsCache();

        return await FlightsLocalStorage.saveFlight(processedFlight);
      }
    } catch (e) {
      AppLogger.error('Error saving flight', e);
      return false;
    }
  }

  /// Get user's saved flights
  /// [forceRefresh] - Si es true, fuerza la carga desde Firestore ignorando la caché
  static Future<List<Map<String, dynamic>>> getUserFlights(
      {bool forceRefresh = false}) async {
    try {
      // Intentar cargar desde la caché primero (solo si no se fuerza actualización)
      if (!forceRefresh) {
        final cachedFlights = await FlightsCacheService.loadFlightsFromCache();
        if (cachedFlights.isNotEmpty) {
          AppLogger.info(
              'Vuelos cargados desde caché (${cachedFlights.length} vuelos)');
          return cachedFlights;
        }
      } else {
        AppLogger.info('Forzando actualización, ignorando caché');
      }

      AppLogger.info(
          '${forceRefresh ? "Actualización forzada" : "No hay datos en caché o están obsoletos"}, cargando desde Firestore');

      // Get current user
      final user = FirebaseAuth.instance.currentUser;

      List<Map<String, dynamic>> userFlightRefs;
      if (user != null) {
        // If user is logged in, get refs from Firestore
        userFlightRefs = await FlightsFirestoreService.getFlightRefs(user.uid);
      } else {
        // If user is not logged in, get from SharedPreferences
        userFlightRefs = await FlightsLocalStorage.getFlights();
      }

      // Filter out archived flights
      userFlightRefs =
          userFlightRefs.where((flight) => flight['archived'] != true).toList();

      // Get full flight data using optimized batch loading
      final List<Map<String, dynamic>> completeFlights =
          await _getCompleteFlightDataBatch(userFlightRefs);

      // Process flights for use in UI (convert integers back to Color objects, etc.)
      final List<Map<String, dynamic>> processedFlights =
          completeFlights.map(_processFlightForUI).toList();

      // Guardar los resultados en caché
      await FlightsCacheService.saveFlightsToCache(processedFlights);

      return processedFlights;
    } catch (e) {
      AppLogger.error('Error getting user flights', e);
      return [];
    }
  }

  /// Remove a flight from user's saved flights
  static Future<bool> removeFlight(String docId) async {
    try {
      // Get current user
      final user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        // If user is logged in, remove from Firestore directamente por el ID del documento
        final result =
            await FlightsFirestoreService.removeFlight(user.uid, docId);

        // Invalidar la caché cuando se elimina un vuelo
        if (result) {
          await FlightsCacheService.invalidateFlightsCache();
        }

        return result;
      } else {
        // If user is not logged in, remove from SharedPreferences
        final result = await FlightsLocalStorage.removeFlight(docId);

        // Invalidar la caché cuando se elimina un vuelo
        if (result) {
          await FlightsCacheService.invalidateFlightsCache();
        }

        return result;
      }
    } catch (e) {
      AppLogger.error('Error removing flight', e);
      return false;
    }
  }

  /// Check if a flight is already saved by the user
  static Future<bool> isFlightSaved(String flightId) async {
    try {
      final flights = await getUserFlights();
      // Verificar únicamente por 'id' (flight_ref) y no por flight_id
      // para evitar confusiones con vuelos diferentes pero mismo código
      return flights.any((flight) =>
          (flight['id'] != null && flight['id'] == flightId) ||
          (flight['flight_ref'] != null && flight['flight_ref'] == flightId));
    } catch (e) {
      AppLogger.error('Error checking if flight is saved', e);
      return false;
    }
  }

  /// Archive a flight (mover a la colección archived_flights)
  /// Returns true if the flight was archived successfully, false otherwise
  static Future<bool> archiveFlight(String docId) async {
    try {
      // Get current user
      final user = FirebaseAuth.instance.currentUser;
      AppLogger.info('Iniciando proceso de archivar vuelo con docId: $docId');

      if (user != null) {
        final result =
            await FlightsFirestoreService.archiveFlight(user.uid, docId);

        // IMPORTANTE: Invalidar ambas cachés para que se actualicen los datos
        if (result) {
          await FlightsCacheService.invalidateFlightsCache();
          await FlightsCacheService.invalidateArchivedCache();
        }

        return result;
      } else {
        // Si el usuario no está logueado, usar SharedPreferences
        final result = await FlightsLocalStorage.archiveFlight(docId);

        // Invalidar ambas cachés
        if (result) {
          await FlightsCacheService.invalidateFlightsCache();
          await FlightsCacheService.invalidateArchivedCache();
        }

        return result;
      }
    } catch (e) {
      AppLogger.error('Error archiving flight', e);
      return false;
    }
  }

  /// Get user's archived flights dates (for grouping)
  static Future<List<ArchivedFlightDate>> getUserArchivedFlightDates(
      {bool forceRefresh = false}) async {
    try {
      // Get current user
      final user = FirebaseAuth.instance.currentUser;
      AppLogger.info(
          'Obteniendo fechas de vuelos archivados${forceRefresh ? " (forzando actualización)" : ""}');

      // Intentar cargar desde la caché primero si no se fuerza la actualización
      if (!forceRefresh) {
        final cachedDates =
            await FlightsCacheService.loadArchivedDatesFromCache();
        if (cachedDates.isNotEmpty) {
          AppLogger.info(
              'Fechas de vuelos archivados cargadas desde caché (${cachedDates.length} fechas)');
          return cachedDates;
        }
      } else {
        AppLogger.info('Forzando actualización, ignorando caché');
      }

      if (user == null) {
        AppLogger.info('Usuario no logueado, usando almacenamiento local');
        final localDates = await _getArchivedDatesFromLocalStorage();

        // Guardar en caché para uso futuro
        if (localDates.isNotEmpty) {
          await FlightsCacheService.saveArchivedDatesToCache(localDates);
        }

        return localDates;
      }

      // Obtener datos directamente de la colección archived_flights
      final archivedFlightsRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('archived_flights');

      final snapshot = await archivedFlightsRef.get();

      if (snapshot.docs.isEmpty) {
        AppLogger.info('No se encontraron vuelos archivados');
        return [];
      }

      // Agrupar vuelos por fecha
      Map<String, int> dateCountMap = {};

      for (var doc in snapshot.docs) {
        final data = doc.data();
        // Usar la fecha de archivo o la fecha del vuelo si está disponible
        String dateString =
            data['archived_at'] ?? DateTime.now().toIso8601String();

        // Extraer solo la fecha (YYYY-MM-DD)
        String dateOnly = dateString.split('T')[0];

        // Incrementar el contador para esta fecha
        dateCountMap[dateOnly] = (dateCountMap[dateOnly] ?? 0) + 1;
      }

      // Convertir el mapa a una lista de fechas archivadas
      final List<ArchivedFlightDate> dates = dateCountMap.entries.map((entry) {
        return ArchivedFlightDate(
          date: entry.key,
          count: entry.value,
        );
      }).toList();

      // Ordenar las fechas (más recientes primero)
      dates.sort((a, b) => b.date.compareTo(a.date));

      AppLogger.info(
          'Se encontraron ${dates.length} fechas con vuelos archivados');

      // Guardar en caché para uso futuro
      if (dates.isNotEmpty) {
        await FlightsCacheService.saveArchivedDatesToCache(dates);
      }

      return dates;
    } catch (e) {
      AppLogger.error('Error obteniendo fechas de vuelos archivados', e);
      return [];
    }
  }

  /// Get user's archived flights for a specific date
  static Future<List<Map<String, dynamic>>> getUserArchivedFlightsByDate(
      String date,
      {bool forceRefresh = false}) async {
    try {
      // Get current user
      final user = FirebaseAuth.instance.currentUser;
      AppLogger.info(
          'Obteniendo vuelos archivados para la fecha: $date${forceRefresh ? " (forzando actualización)" : ""}');

      // Intentar cargar desde la caché primero si no se fuerza la actualización
      if (!forceRefresh) {
        final cachedFlights =
            await FlightsCacheService.loadArchivedFlightsByDateFromCache(date);
        if (cachedFlights.isNotEmpty) {
          AppLogger.info(
              'Vuelos archivados para fecha $date cargados desde caché (${cachedFlights.length} vuelos)');
          return cachedFlights;
        }
      } else {
        AppLogger.info('Forzando actualización, ignorando caché');
      }

      if (user == null) {
        AppLogger.info('Usuario no logueado, usando almacenamiento local');
        final localFlights =
            await _getArchivedFlightsByDateFromLocalStorage(date);

        // Guardar en caché para uso futuro
        if (localFlights.isNotEmpty) {
          await FlightsCacheService.saveArchivedFlightsByDateToCache(
              date, localFlights);
        }

        return localFlights;
      }

      // Buscar directamente en la colección archived_flights
      final archivedFlightsRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('archived_flights');

      final flightsSnapshot = await archivedFlightsRef.get();

      AppLogger.info(
          'Se encontraron ${flightsSnapshot.docs.length} vuelos archivados en total');

      if (flightsSnapshot.docs.isEmpty) {
        return [];
      }

      // Convertir a List<Map<String, dynamic>>
      final userFlightRefs = flightsSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          ...data,
          'doc_id': doc.id,
        };
      }).toList();

      // Filtrar solo vuelos de la fecha especificada
      final flightsForDate = userFlightRefs.where((flight) {
        final flightDate = flight['archived_date'] ??
            (flight['archived_at'] != null
                ? flight['archived_at'].split('T')[0]
                : '');
        return flightDate == date;
      }).toList();

      // Ordenar por hora de archivo (más recientes primero)
      flightsForDate.sort((a, b) {
        String dateA = a['archived_at'] ?? '';
        String dateB = b['archived_at'] ?? '';
        return dateB.compareTo(dateA);
      });

      // Get full flight data from references
      final completeFlights = await _getCompleteFlightData(flightsForDate);

      // Process flights for use in UI
      final processedFlights =
          completeFlights.map(_processFlightForUI).toList();

      // Guardar en caché para uso futuro
      if (processedFlights.isNotEmpty) {
        await FlightsCacheService.saveArchivedFlightsByDateToCache(
            date, processedFlights);
      }

      return processedFlights;
    } catch (e) {
      AppLogger.error('Error obteniendo vuelos archivados por fecha', e);
      return [];
    }
  }

  /// Eliminar permanentemente un vuelo archivado
  static Future<bool> permanentlyDeleteFlight(String docId) async {
    try {
      // Get current user
      final user = FirebaseAuth.instance.currentUser;
      AppLogger.info(
          'Iniciando proceso de eliminación permanente para vuelo con docId: $docId');

      if (user != null) {
        final result = await FlightsFirestoreService.permanentlyDeleteFlight(
            user.uid, docId);

        // IMPORTANTE: Invalidar caché de vuelos archivados
        if (result) {
          await FlightsCacheService.invalidateArchivedCache();
        }

        return result;
      } else {
        final result = await FlightsLocalStorage.permanentlyDeleteFlight(docId);

        // Invalidar caché
        if (result) {
          await FlightsCacheService.invalidateArchivedCache();
        }

        return result;
      }
    } catch (e) {
      AppLogger.error('Error al eliminar permanentemente el vuelo', e);
      return false;
    }
  }

  /// Restore an archived flight
  static Future<bool> restoreUserFlight(String docId) async {
    try {
      // Get current user
      final user = FirebaseAuth.instance.currentUser;
      AppLogger.info('Iniciando proceso de restaurar vuelo con docId: $docId');

      if (user != null) {
        final result =
            await FlightsFirestoreService.restoreFlight(user.uid, docId);

        // IMPORTANTE: Invalidar ambas cachés para que se actualicen los datos
        if (result) {
          await FlightsCacheService.invalidateFlightsCache();
          await FlightsCacheService.invalidateArchivedCache();
        }

        return result;
      } else {
        final result = await FlightsLocalStorage.restoreFlight(docId);

        // Invalidar ambas cachés
        if (result) {
          await FlightsCacheService.invalidateFlightsCache();
          await FlightsCacheService.invalidateArchivedCache();
        }

        return result;
      }
    } catch (e) {
      AppLogger.error('Error al restaurar vuelo', e);
      return false;
    }
  }

  /// Delete a user flight
  static Future<bool> deleteUserFlight(String docId) async {
    try {
      // Get current user
      final user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        return await FlightsFirestoreService.removeFlight(user.uid, docId);
      } else {
        return await FlightsLocalStorage.removeFlight(docId);
      }
    } catch (e) {
      AppLogger.error('Error eliminando vuelo', e);
      return false;
    }
  }

  /// Método proxy para mantener compatibilidad con llamadas existentes
  static Future<bool> restoreArchivedFlight(String docId) async {
    return restoreUserFlight(docId);
  }

  /// Update user information in Firestore
  static Future<void> updateUserInfo() async {
    await FlightsFirestoreService.updateUserInfo();
  }

  // ===== PRIVATE HELPER METHODS =====

  /// Process flight data for storage
  /// Converts incompatible types (like Color) to storable formats
  static Map<String, dynamic> _processFlightForStorage(
      Map<String, dynamic> flight) {
    final Map<String, dynamic> processedFlight = {};

    // Process each field in the flight map
    flight.forEach((key, value) {
      if (value is Color) {
        // Convert Color to integer
        processedFlight[key] = value.value;
      } else if (value == null) {
        // Skip null values or provide default values if needed
        processedFlight[key] = value;
      } else {
        // Keep other values as is
        processedFlight[key] = value;
      }
    });

    return processedFlight;
  }

  /// Process flight data for UI display
  /// Converts stored formats back to usable types (like int to Color)
  static Map<String, dynamic> _processFlightForUI(Map<String, dynamic> flight) {
    final Map<String, dynamic> processedFlight = Map.from(flight);

    // Convert color field from int to Color if it exists
    if (flight['color'] is int) {
      processedFlight['color'] = Color(flight['color']);
    }

    return processedFlight;
  }

  /// Nuevo método para obtener datos completos de vuelos en una sola consulta por lotes
  static Future<List<Map<String, dynamic>>> _getCompleteFlightDataBatch(
      List<Map<String, dynamic>> flightRefs) async {
    final List<Map<String, dynamic>> completeFlights = [];

    try {
      AppLogger.info(
          'Obteniendo datos completos para ${flightRefs.length} vuelos en lote');

      // Si no hay referencias, devolver una lista vacía
      if (flightRefs.isEmpty) {
        return [];
      }

      // Recolectar todos los IDs de vuelos que necesitamos consultar
      final List<String> flightIds =
          flightRefs.map((ref) => ref['flight_ref'] as String).toList();

      // Limitar a lotes de 30 para evitar consultas demasiado grandes (límite de Firestore)
      const int batchSize = 30;
      List<String> currentBatch = [];
      List<Future<QuerySnapshot>> queries = [];

      for (int i = 0; i < flightIds.length; i++) {
        currentBatch.add(flightIds[i]);

        if (currentBatch.length == batchSize || i == flightIds.length - 1) {
          // Crear una consulta para el lote actual
          final query = FirebaseFirestore.instance
              .collection('flights')
              .where(FieldPath.documentId, whereIn: currentBatch)
              .get();

          queries.add(query);

          // Reiniciar el lote actual
          currentBatch = [];
        }
      }

      // Ejecutar todas las consultas en paralelo
      final results = await Future.wait(queries);

      // Crear un mapa para buscar rápidamente los documentos por ID
      final Map<String, Map<String, dynamic>> flightDataMap = {};

      // Procesar todos los resultados
      for (final result in results) {
        for (final doc in result.docs) {
          flightDataMap[doc.id] = doc.data() as Map<String, dynamic>;
        }
      }

      // Construir la lista de vuelos completa usando los datos obtenidos
      for (final ref in flightRefs) {
        final String flightId = ref['flight_ref'] as String;
        final String docId = ref['doc_id'] as String;

        if (flightDataMap.containsKey(flightId)) {
          // Vuelo encontrado en el lote de resultados
          final flightData = flightDataMap[flightId]!;

          final completeData = {
            ...flightData,
            'id': flightId,
            'original_id': flightId,
            'saved_at': ref['saved_at'],
            'doc_id': docId,
          };

          // Añadir color si no está presente
          if (!completeData.containsKey('color')) {
            final airline = completeData['airline'] ?? '';
            completeData['color'] =
                AirlineHelper.getAirlineColor(airline).value;
          }

          completeFlights.add(completeData);
        } else {
          // Vuelo no encontrado, usar datos básicos
          AppLogger.warning(
              'Flight with ID $flightId not found in batch results');

          final basicData = {
            ...ref,
            'id': flightId,
            'original_id': flightId,
            'flight_removed': true,
            'airport': 'Unknown',
            'gate': 'N/A',
            'airline': ref['flight_id']?.substring(0, 2) ?? 'XX',
            'schedule_time': 'N/A',
          };

          completeFlights.add(basicData);
        }
      }

      AppLogger.info('Procesados ${completeFlights.length} vuelos en lote');
    } catch (e) {
      AppLogger.error('Error getting complete flight data in batch', e);
    }

    return completeFlights;
  }

  /// Método original para referencia - reemplazado por la versión por lotes
  static Future<List<Map<String, dynamic>>> _getCompleteFlightData(
      List<Map<String, dynamic>> flightRefs) async {
    final List<Map<String, dynamic>> completeFlights = [];

    // Process each flight reference
    for (final ref in flightRefs) {
      try {
        // Get the flight document from main collection using the reference
        final flightId = ref['flight_ref'];

        AppLogger.info(
            'Obteniendo datos completos para vuelo con flight_ref: $flightId');

        // Get the flight document from main collection
        final flightDoc = await FirebaseFirestore.instance
            .collection('flights')
            .doc(flightId)
            .get();

        if (flightDoc.exists) {
          // Create combined data with user metadata and updated flight info
          final flightData = flightDoc.data() as Map<String, dynamic>;

          final completeData = {
            ...flightData,
            'id': flightId,
            'original_id': flightId,
            'saved_at': ref['saved_at'],
            'doc_id': ref['doc_id'],
          };

          // Add airline color if not present
          if (!completeData.containsKey('color')) {
            final airline = completeData['airline'] ?? '';
            completeData['color'] =
                AirlineHelper.getAirlineColor(airline).value;
          }

          completeFlights.add(completeData);
        } else {
          // Flight no longer exists, add a flag and use basic reference data
          AppLogger.warning(
              'Flight ${ref['flight_id']} no longer exists, using reference data for flight_ref: $flightId');
          final basicData = {
            ...ref,
            'id': flightId,
            'original_id': flightId,
            'flight_removed': true,
            'airport': 'Unknown',
            'gate': 'N/A',
            'airline': ref['flight_id']?.substring(0, 2) ?? 'XX',
            'schedule_time': 'N/A',
          };

          // Add a color for display
          if (!basicData.containsKey('color')) {
            basicData['color'] = Colors.grey.value;
          }

          completeFlights.add(basicData);
        }
      } catch (e) {
        AppLogger.error(
            'Error getting complete flight data for ${ref['flight_id']}', e);
        // Add a minimal reference as fallback with error flag
        final flightId = ref['flight_ref'];
        completeFlights.add({
          ...ref,
          'id': flightId,
          'original_id': flightId,
          'data_error': true,
          'airport': 'Error',
          'gate': 'Error',
          'airline': ref['flight_id']?.substring(0, 2) ?? 'XX',
          'schedule_time': 'Error',
          'color': Colors.red.value,
        });
      }
    }

    return completeFlights;
  }

  /// Obtener fechas de vuelos archivados desde almacenamiento local
  static Future<List<ArchivedFlightDate>>
      _getArchivedDatesFromLocalStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonFlights = prefs.getString(_userArchivedFlightsKey);

      if (jsonFlights == null) return [];

      // Convertir string JSON a lista de vuelos
      List<Map<String, dynamic>> flights = (jsonDecode(jsonFlights) as List)
          .map((item) => Map<String, dynamic>.from(item))
          .toList();

      // Filtrar solo vuelos archivados
      final archivedFlights =
          flights.where((f) => f['archived'] == true).toList();

      // Agrupar por fecha de archivo
      final Map<String, int> dateCountMap = {};

      for (final flight in archivedFlights) {
        final date = flight['archived_date'] ??
            (flight['archived_at'] != null
                ? flight['archived_at'].split('T')[0]
                : DateTime.now().toIso8601String().split('T')[0]);

        dateCountMap[date] = (dateCountMap[date] ?? 0) + 1;
      }

      // Convertir mapa a lista de objetos ArchivedFlightDate
      final List<ArchivedFlightDate> result = dateCountMap.entries
          .map((entry) =>
              ArchivedFlightDate(date: entry.key, count: entry.value))
          .toList();

      // Ordenar por fecha (descendente)
      result.sort((a, b) => b.date.compareTo(a.date));

      return result;
    } catch (e) {
      AppLogger.error(
          'Error obteniendo fechas archivadas del almacenamiento local', e);
      return [];
    }
  }

  /// Obtener vuelos archivados para una fecha específica desde almacenamiento local
  static Future<List<Map<String, dynamic>>>
      _getArchivedFlightsByDateFromLocalStorage(String date) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonFlights = prefs.getString(_userArchivedFlightsKey);

      if (jsonFlights == null) return [];

      // Convertir string JSON a lista de vuelos
      List<Map<String, dynamic>> flights = (jsonDecode(jsonFlights) as List)
          .map((item) => Map<String, dynamic>.from(item))
          .toList();

      // Filtrar solo vuelos archivados de la fecha especificada
      final filteredFlights = flights.where((flight) {
        final flightDate = flight['archived_date'] ??
            (flight['archived_at'] != null
                ? flight['archived_at'].split('T')[0]
                : '');

        return flight['archived'] == true && flightDate == date;
      }).toList();

      // Ordenar por fecha de archivo (más recientes primero)
      filteredFlights.sort((a, b) {
        String dateA = a['archived_at'] ?? '';
        String dateB = b['archived_at'] ?? '';
        return dateB.compareTo(dateA);
      });

      return filteredFlights;
    } catch (e) {
      AppLogger.error(
          'Error obteniendo vuelos archivados por fecha del almacenamiento local',
          e);
      return [];
    }
  }
}
