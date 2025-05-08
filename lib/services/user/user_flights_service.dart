import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import '../../utils/airline_helper.dart';

/// Estructura para organizar vuelos por fecha
class ArchivedFlightDate {
  final String date; // Formato "yyyy-MM-dd"
  final int count; // Número de vuelos en esa fecha

  ArchivedFlightDate({required this.date, required this.count});

  Map<String, dynamic> toMap() {
    return {
      'date': date,
      'count': count,
    };
  }

  factory ArchivedFlightDate.fromMap(Map<String, dynamic> map) {
    return ArchivedFlightDate(
      date: map['date'] ?? '',
      count: map['count'] ?? 0,
    );
  }
}

/// Service to manage user's saved flights
class UserFlightsService {
  static const String _userFlightsKey = 'user_flights';
  // Nuevas claves para el sistema de caché
  static const String _cachedUserFlightsKey = 'cached_user_flights';
  static const String _userFlightsLastUpdatedKey = 'user_flights_last_updated';
  static const String _userArchivedFlightsKey = 'user_archived_flights';
  // Nuevas claves para caché de vuelos archivados
  static const String _cachedUserArchivedFlightsKey =
      'cached_user_archived_flights';
  static const String _userArchivedFlightsLastUpdatedKey =
      'user_archived_flights_last_updated';
  static const String _cachedUserArchivedDatesKey =
      'cached_user_archived_dates';
  static const String _userArchivedDatesLastUpdatedKey =
      'user_archived_dates_last_updated';

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
        final result = await _saveFlightToFirestore(user.uid, savedFlightData);

        // If successful and was a restoration, mark the original flight as restored
        if (result && savedFlightData['was_archived'] == true) {
          flight['was_archived'] = true;
        }

        // Invalidar la caché cuando se añade un nuevo vuelo
        await _invalidateCache();

        return result;
      } else {
        // For local storage, we still need all flight details
        // but we'll ensure we have the reference for future compatibility
        final processedFlight = _processFlightForStorage(flight);
        processedFlight['flight_ref'] = flight['id']; // Add reference

        // Invalidar la caché cuando se añade un nuevo vuelo
        await _invalidateCache();

        return await _saveFlightToLocalStorage(processedFlight);
      }
    } catch (e) {
      print('LOG: Error saving flight: $e');
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
        final cachedFlights = await _loadFromCache();
        if (cachedFlights.isNotEmpty) {
          print(
              'LOG: Vuelos cargados desde caché (${cachedFlights.length} vuelos)');
          return cachedFlights;
        }
      } else {
        print('LOG: Forzando actualización, ignorando caché');
      }

      print(
          'LOG: ${forceRefresh ? "Actualización forzada" : "No hay datos en caché o están obsoletos"}, cargando desde Firestore');

      // Get current user
      final user = FirebaseAuth.instance.currentUser;

      List<Map<String, dynamic>> userFlightRefs;
      if (user != null) {
        // If user is logged in, get refs from Firestore
        userFlightRefs = await _getFlightRefsFromFirestore(user.uid);
      } else {
        // If user is not logged in, get from SharedPreferences
        userFlightRefs = await _getFlightsFromLocalStorage();
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
      await _saveToCache(processedFlights);

      return processedFlights;
    } catch (e) {
      print('LOG: Error getting user flights: $e');
      return [];
    }
  }

  /// Nuevo método para obtener datos completos de vuelos en una sola consulta por lotes
  static Future<List<Map<String, dynamic>>> _getCompleteFlightDataBatch(
      List<Map<String, dynamic>> flightRefs) async {
    final List<Map<String, dynamic>> completeFlights = [];

    try {
      print(
          'LOG: Obteniendo datos completos para ${flightRefs.length} vuelos en lote');

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
          print('LOG: Flight with ID $flightId not found in batch results');

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

      print('LOG: Procesados ${completeFlights.length} vuelos en lote');
    } catch (e) {
      print('LOG: Error getting complete flight data in batch: $e');
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

        print(
            'LOG: Obteniendo datos completos para vuelo con flight_ref: $flightId');

        // Get the flight document from main collection
        final flightDoc = await FirebaseFirestore.instance
            .collection('flights')
            .doc(flightId)
            .get();

        if (flightDoc.exists) {
          // Create combined data with user metadata and updated flight info
          final flightData = flightDoc.data() as Map<String, dynamic>;

          // IMPORTANTE: Mantener el ID original del vuelo guardado
          // en lugar de usar un ID potencialmente actualizado
          final completeData = {
            ...flightData,
            'id':
                flightId, // Asegurar que siempre usamos el flight_ref original
            'original_id': flightId, // Mantener una referencia al ID original
            'saved_at': ref['saved_at'],
            'doc_id': ref['doc_id'], // Keep reference to user's saved document
          };

          print('LOG: Usando flight_ref original: $flightId como ID del vuelo');

          // Add airline color if not present
          if (!completeData.containsKey('color')) {
            final airline = completeData['airline'] ?? '';
            completeData['color'] =
                AirlineHelper.getAirlineColor(airline).value;
          }

          completeFlights.add(completeData);
        } else {
          // Flight no longer exists, add a flag and use basic reference data
          print(
              'LOG: Flight ${ref['flight_id']} no longer exists, using reference data for flight_ref: $flightId');
          final basicData = {
            ...ref,
            'id': flightId, // Mantener el flight_ref original como ID
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
        print(
            'LOG: Error getting complete flight data for ${ref['flight_id']}: $e');
        // Add a minimal reference as fallback with error flag
        final flightId = ref['flight_ref'];
        completeFlights.add({
          ...ref,
          'id': flightId, // Mantener el flight_ref original como ID
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

  /// Remove a flight from user's saved flights
  static Future<bool> removeFlight(String docId) async {
    try {
      // Get current user
      final user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        // If user is logged in, remove from Firestore directamente por el ID del documento
        final result = await _removeFlightFromFirestore(user.uid, docId);

        // Invalidar la caché cuando se elimina un vuelo
        if (result) {
          await _invalidateCache();
        }

        return result;
      } else {
        // If user is not logged in, remove from SharedPreferences
        final result = await _removeFlightFromLocalStorage(docId);

        // Invalidar la caché cuando se elimina un vuelo
        if (result) {
          await _invalidateCache();
        }

        return result;
      }
    } catch (e) {
      print('LOG: Error removing flight: $e');
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
      print('LOG: Error checking if flight is saved: $e');
      return false;
    }
  }

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
        print('LOG: Converted Color to int: ${value.value} for field $key');
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
      print('LOG: Converted int to Color for flight ${flight['flight_id']}');
    }

    return processedFlight;
  }

  /// Archive a flight (mover a la colección archived_flights)
  /// Returns true if the flight was archived successfully, false otherwise
  static Future<bool> archiveFlight(String docId) async {
    try {
      // Get current user
      final user = FirebaseAuth.instance.currentUser;
      print('LOG: Iniciando proceso de archivar vuelo con docId: $docId');
      print('LOG: Usuario actual: ${user?.uid ?? "No hay usuario logueado"}');

      if (user != null) {
        // Referencias a las colecciones
        final userFlightsRef = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('saved_flights');

        final archivedFlightsRef = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('archived_flights');

        print('LOG: Ruta de Firestore: users/${user.uid}/saved_flights/$docId');

        try {
          // Obtener el documento original
          print('LOG: Intentando obtener el documento con ID: $docId');
          final docSnapshot = await userFlightsRef.doc(docId).get();

          if (docSnapshot.exists) {
            // Si el documento existe, copiarlo a la colección de vuelos archivados
            print(
                'LOG: Documento encontrado. Datos actuales: ${docSnapshot.data()}');
            print('LOG: Moviendo documento a la colección archived_flights...');

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

            print('LOG: Vuelo archivado con nuevo ID: ${archivedDocRef.id}');

            // Actualizar la colección archived_dates para este vuelo
            final archivedDate = archivedData['archived_date'] as String;
            await _updateArchivedDateSummary(user.uid, archivedDate);
            print('LOG: Actualizado resumen de fecha archivada: $archivedDate');

            // Opcionalmente: eliminar o marcar el vuelo original
            // Aquí puedes elegir entre eliminarlo completamente o marcarlo como archivado
            await userFlightsRef.doc(docId).update({
              'archived': true,
              'archived_at': DateTime.now().toIso8601String(),
              'archived_doc_id': archivedDocRef.id, // Referencia cruzada
            });

            // IMPORTANTE: Invalidar ambas cachés para que se actualicen los datos
            await _invalidateCache();
            await _invalidateArchivedCache();

            print('LOG: Vuelo con ID $docId archivado correctamente');
            return true;
          } else {
            print(
                'LOG: No se encontró el documento con ID $docId para archivar');
            return false;
          }
        } catch (e) {
          print('LOG: Error al acceder al documento con ID $docId: $e');
          return false;
        }
      } else {
        // Si el usuario no está logueado, usar SharedPreferences
        // Esta implementación es simplificada y podría necesitar adaptarse
        final SharedPreferences prefs = await SharedPreferences.getInstance();
        final String? jsonFlights = prefs.getString(_userFlightsKey);
        final String? jsonArchivedFlights =
            prefs.getString(_userArchivedFlightsKey);

        if (jsonFlights == null) {
          return false;
        }

        // Convertir string JSON a lista de vuelos activos
        List<Map<String, dynamic>> flights = (jsonDecode(jsonFlights) as List)
            .map((item) => Map<String, dynamic>.from(item))
            .toList();

        // Convertir string JSON a lista de vuelos archivados (o crear nueva)
        List<Map<String, dynamic>> archivedFlights = [];
        if (jsonArchivedFlights != null) {
          archivedFlights = (jsonDecode(jsonArchivedFlights) as List)
              .map((item) => Map<String, dynamic>.from(item))
              .toList();
        }

        // Buscar el vuelo a archivar
        bool found = false;
        Map<String, dynamic>? flightToArchive;
        int indexToUpdate = -1;

        for (int i = 0; i < flights.length; i++) {
          if (flights[i]['doc_id'] == docId) {
            flightToArchive = Map<String, dynamic>.from(flights[i]);
            found = true;
            indexToUpdate = i;
            break;
          }
        }

        if (found && flightToArchive != null) {
          // Agregar metadatos de archivo
          final archivedDate = DateTime.now().toIso8601String();
          flightToArchive['archived'] = true;
          flightToArchive['archived_at'] = archivedDate;
          flightToArchive['archived_date'] = archivedDate.split('T')[0];

          // Agregar a la lista de vuelos archivados
          archivedFlights.add(flightToArchive);

          // Actualizar o marcar el vuelo original
          flights[indexToUpdate]['archived'] = true;
          flights[indexToUpdate]['archived_at'] = archivedDate;

          // Guardar ambas listas
          await prefs.setString(_userFlightsKey, jsonEncode(flights));
          await prefs.setString(
              _userArchivedFlightsKey, jsonEncode(archivedFlights));

          // Invalidar ambas cachés
          await _invalidateCache();
          await _invalidateArchivedCache();

          print('LOG: Vuelo archivado localmente');
          return true;
        }

        print('LOG: No se encontró el documento con ID $docId en modo offline');
        return false;
      }
    } catch (e) {
      print('LOG: Error archiving flight: $e');
      return false;
    }
  }

  /// Actualiza o crea el documento de resumen de la fecha de archivo
  static Future<void> _updateArchivedDateSummary(
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

      print('LOG: Actualizado resumen de fecha de archivo para $date');
    } catch (e) {
      print('LOG: Error al actualizar resumen de fecha de archivo: $e');
    }
  }

  /// Get user's archived flights dates (for grouping)
  static Future<List<ArchivedFlightDate>> getUserArchivedFlightDates(
      {bool forceRefresh = false}) async {
    try {
      // Get current user
      final user = FirebaseAuth.instance.currentUser;
      print(
          'LOG: Obteniendo fechas de vuelos archivados${forceRefresh ? " (forzando actualización)" : ""}');

      // Intentar cargar desde la caché primero si no se fuerza la actualización
      if (!forceRefresh) {
        final cachedDates = await _loadArchivedDatesFromCache();
        if (cachedDates.isNotEmpty) {
          print(
              'LOG: Fechas de vuelos archivados cargadas desde caché (${cachedDates.length} fechas)');
          return cachedDates;
        }
      } else {
        print('LOG: Forzando actualización, ignorando caché');
      }

      if (user == null) {
        print('LOG: Usuario no logueado, usando almacenamiento local');
        final localDates = await _getArchivedDatesFromLocalStorage();

        // Guardar en caché para uso futuro
        if (localDates.isNotEmpty) {
          await _saveArchivedDatesToCache(localDates);
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
        print('LOG: No se encontraron vuelos archivados');
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

      print('LOG: Se encontraron ${dates.length} fechas con vuelos archivados');

      // Guardar en caché para uso futuro
      if (dates.isNotEmpty) {
        await _saveArchivedDatesToCache(dates);
      }

      return dates;
    } catch (e) {
      print('LOG: Error obteniendo fechas de vuelos archivados: $e');
      return [];
    }
  }

  /// Obtener fechas de vuelos archivados desde almacenamiento local
  static Future<List<ArchivedFlightDate>>
      _getArchivedDatesFromLocalStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonFlights = prefs.getString(_userFlightsKey);

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
      print(
          'LOG: Error obteniendo fechas archivadas del almacenamiento local: $e');
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
      print(
          'LOG: Obteniendo vuelos archivados para la fecha: $date${forceRefresh ? " (forzando actualización)" : ""}');

      // Intentar cargar desde la caché primero si no se fuerza la actualización
      if (!forceRefresh) {
        final cachedFlights = await _loadArchivedFlightsByDateFromCache(date);
        if (cachedFlights.isNotEmpty) {
          print(
              'LOG: Vuelos archivados para fecha $date cargados desde caché (${cachedFlights.length} vuelos)');
          return cachedFlights;
        }
      } else {
        print('LOG: Forzando actualización, ignorando caché');
      }

      if (user == null) {
        print('LOG: Usuario no logueado, usando almacenamiento local');
        final localFlights =
            await _getArchivedFlightsByDateFromLocalStorage(date);

        // Guardar en caché para uso futuro
        if (localFlights.isNotEmpty) {
          await _saveArchivedFlightsByDateToCache(date, localFlights);
        }

        return localFlights;
      }

      // Buscar directamente en la colección archived_flights
      final archivedFlightsRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('archived_flights');

      final flightsSnapshot = await archivedFlightsRef.get();

      print(
          'LOG: Se encontraron ${flightsSnapshot.docs.length} vuelos archivados en total');

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
        await _saveArchivedFlightsByDateToCache(date, processedFlights);
      }

      return processedFlights;
    } catch (e) {
      print('LOG: Error obteniendo vuelos archivados por fecha: $e');
      return [];
    }
  }

  /// Obtener vuelos archivados para una fecha específica desde almacenamiento local
  static Future<List<Map<String, dynamic>>>
      _getArchivedFlightsByDateFromLocalStorage(String date) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonFlights = prefs.getString(_userFlightsKey);

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
      print(
          'LOG: Error obteniendo vuelos archivados por fecha del almacenamiento local: $e');
      return [];
    }
  }

  /// Elimina permanentemente un vuelo archivado
  /// Returns true if the flight was permanently deleted, false otherwise
  static Future<bool> permanentlyDeleteFlight(String docId) async {
    try {
      // Get current user
      final user = FirebaseAuth.instance.currentUser;
      print(
          'LOG: Iniciando proceso de eliminación permanente para vuelo con docId: $docId');

      if (user != null) {
        // Si usuario está autenticado, eliminar de Firestore
        final archivedFlightsRef = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('archived_flights');

        print(
            'LOG: Ruta de Firestore para eliminación: users/${user.uid}/archived_flights/$docId');

        // Obtener el documento para verificar su fecha de archivo antes de eliminarlo
        final docSnapshot = await archivedFlightsRef.doc(docId).get();

        if (!docSnapshot.exists) {
          print('LOG: No se encontró el documento con ID $docId para eliminar');
          return false;
        }

        // Obtener la fecha de archivo para actualizar el contador
        final data = docSnapshot.data() as Map<String, dynamic>;
        final archivedDate = data['archived_date'] as String?;

        // Eliminar el documento
        await archivedFlightsRef.doc(docId).delete();
        print('LOG: Vuelo eliminado permanentemente: $docId');

        // Actualizar el contador en la colección de fechas si el vuelo estaba archivado
        if (archivedDate != null) {
          await _decrementArchivedDateCounter(user.uid, archivedDate);
        }

        // IMPORTANTE: Invalidar caché de vuelos archivados
        await _invalidateArchivedCache();

        return true;
      } else {
        // Si usuario no está autenticado, eliminar del almacenamiento local
        final prefs = await SharedPreferences.getInstance();
        final String? jsonFlights = prefs.getString(_userFlightsKey);

        if (jsonFlights == null) {
          return false;
        }

        // Convertir string JSON a lista de vuelos
        List<Map<String, dynamic>> flights = (jsonDecode(jsonFlights) as List)
            .map((item) => Map<String, dynamic>.from(item))
            .toList();

        // Buscar el vuelo a eliminar
        int indexToRemove = -1;
        String? archivedDate;

        for (int i = 0; i < flights.length; i++) {
          if (flights[i]['doc_id'] == docId && flights[i]['archived'] == true) {
            indexToRemove = i;
            archivedDate = flights[i]['archived_date'] as String?;
            break;
          }
        }

        if (indexToRemove != -1) {
          // Eliminar el vuelo
          flights.removeAt(indexToRemove);

          // Guardar la lista actualizada
          await prefs.setString(_userFlightsKey, jsonEncode(flights));

          // Invalidar caché
          await _invalidateArchivedCache();

          print('LOG: Vuelo eliminado permanentemente en modo offline');
          return true;
        }

        print(
            'LOG: No se encontró el vuelo archivado con ID $docId en almacenamiento local');
        return false;
      }
    } catch (e) {
      print('LOG: Error al eliminar permanentemente el vuelo: $e');
      return false;
    }
  }

  /// Decrementar el contador de vuelos archivados para una fecha
  static Future<void> _decrementArchivedDateCounter(
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
          print('LOG: Documento de fecha $date eliminado (no quedan vuelos)');
        } else {
          // Decrementar el contador
          await archiveDateRef.update({
            'count': FieldValue.increment(-1),
            'last_updated': FieldValue.serverTimestamp(),
          });
          print(
              'LOG: Contador de fecha $date decrementado a ${currentCount - 1}');
        }
      }
    } catch (e) {
      print('LOG: Error al actualizar contador de fecha archivada: $e');
    }
  }

  /// Get user's archived flights - DEPRECATED: Use getUserArchivedFlightDates and getUserArchivedFlightsByDate instead
  static Future<List<Map<String, dynamic>>> getUserArchivedFlights() async {
    try {
      // Get current user
      final user = FirebaseAuth.instance.currentUser;
      print('LOG: Obteniendo vuelos archivados');
      print('LOG: Usuario actual: ${user?.uid ?? "No hay usuario logueado"}');

      List<Map<String, dynamic>> userFlightRefs;
      if (user != null) {
        // If user is logged in, get refs from Firestore
        final userFlightsRef = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('saved_flights');

        print(
            'LOG: Ruta de Firestore para obtener vuelos archivados: users/${user.uid}/saved_flights');

        try {
          // Usar una consulta simple sin ordenamiento
          print(
              'LOG: Intentando ejecutar consulta para vuelos archivados (archived=true)');
          final flightsSnapshot =
              await userFlightsRef.where('archived', isEqualTo: true).get();

          print(
              'LOG: Resultado de la consulta: ${flightsSnapshot.docs.length} documentos encontrados');

          // Imprimir los IDs de todos los documentos obtenidos
          if (flightsSnapshot.docs.isNotEmpty) {
            print('LOG: IDs de documentos archivados encontrados:');
            for (var doc in flightsSnapshot.docs) {
              print(
                  'LOG: - Doc ID: ${doc.id}, flight_id: ${doc.data()['flight_id']}');
            }
          }

          if (flightsSnapshot.docs.isNotEmpty) {
            // Convert to List<Map<String, dynamic>>
            userFlightRefs = flightsSnapshot.docs.map((doc) {
              final data = doc.data();
              // Add doc id as a field
              return {
                ...data,
                'doc_id': doc.id,
              };
            }).toList();

            // Ordenar manualmente por archived_at (más recientes primero)
            userFlightRefs.sort((a, b) {
              String dateA = a['archived_at'] ?? '';
              String dateB = b['archived_at'] ?? '';
              // Orden descendente
              return dateB.compareTo(dateA);
            });
          } else {
            userFlightRefs = [];
          }
        } catch (e) {
          // Si falla, usar consulta simple y filtrar manualmente
          print('LOG: Archived query failed, using simple query: $e');

          // Obtener todos los documentos sin filtro
          print(
              'LOG: Obteniendo todos los documentos para filtrar manualmente');
          final allFlightsSnapshot = await userFlightsRef.get();
          print(
              'LOG: Total de documentos obtenidos: ${allFlightsSnapshot.docs.length}');

          // Procesar y filtrar manualmente los documentos
          userFlightRefs = [];

          for (final doc in allFlightsSnapshot.docs) {
            final data = doc.data();

            // Solo incluir documentos archivados
            if (data['archived'] == true) {
              print(
                  'LOG: Documento archivado encontrado: ${doc.id}, flight_id: ${data['flight_id']}');
              // Añadir doc_id al mapa
              userFlightRefs.add({
                ...data,
                'doc_id': doc.id,
              });
            }
          }

          // Ordenar manualmente por archived_at (más recientes primero)
          userFlightRefs.sort((a, b) {
            String dateA = a['archived_at'] ?? '';
            String dateB = b['archived_at'] ?? '';
            // Orden descendente (más reciente primero)
            return dateB.compareTo(dateA);
          });

          print(
              'LOG: Found ${userFlightRefs.length} archived flights with manual filtering');
        }
      } else {
        // If user is not logged in, get from SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        final flightsJson = prefs.getString(_userFlightsKey);

        if (flightsJson != null && flightsJson.isNotEmpty) {
          // Convert to List<Map<String, dynamic>> and filter only archived ones
          final List<dynamic> allFlights = jsonDecode(flightsJson);
          userFlightRefs = [];

          for (final flight in allFlights) {
            final Map<String, dynamic> flightMap =
                Map<String, dynamic>.from(flight);
            if (flightMap['archived'] == true) {
              userFlightRefs.add(flightMap);
            }
          }

          // Ordenar manualmente por archived_at (más recientes primero)
          userFlightRefs.sort((a, b) {
            String dateA = a['archived_at'] ?? '';
            String dateB = b['archived_at'] ?? '';
            // Orden descendente
            return dateB.compareTo(dateA);
          });

          print(
              'LOG: Found ${userFlightRefs.length} archived flights in local storage');
        } else {
          userFlightRefs = [];
          print('LOG: No archived flights found in local storage');
        }
      }

      // Get full flight data from references
      final List<Map<String, dynamic>> completeFlights =
          await _getCompleteFlightData(userFlightRefs);

      // Process flights for use in UI (convert integers back to Color objects, etc.)
      return completeFlights.map(_processFlightForUI).toList();
    } catch (e) {
      print('LOG: Error getting user archived flights: $e');
      return [];
    }
  }

  /// Restore an archived flight
  static Future<bool> restoreUserFlight(String docId) async {
    try {
      // Get current user
      final user = FirebaseAuth.instance.currentUser;
      print('LOG: Iniciando proceso de restaurar vuelo con docId: $docId');
      print('LOG: Usuario actual: ${user?.uid ?? "No hay usuario logueado"}');

      if (user != null) {
        // Get reference to user's collections
        final savedFlightsRef = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('saved_flights');

        final archivedFlightsRef = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('archived_flights');

        print('LOG: Ruta correcta: users/${user.uid}/archived_flights/$docId');

        // IMPORTANTE: Primero buscar en archived_flights, no en saved_flights
        final archivedDocSnapshot = await archivedFlightsRef.doc(docId).get();

        if (!archivedDocSnapshot.exists) {
          print(
              'LOG: No se encontró el documento con ID $docId en archived_flights');
          return false;
        }

        // Obtener los datos del documento archivado
        final archivedData = archivedDocSnapshot.data() as Map<String, dynamic>;
        print('LOG: Datos del vuelo archivado: ${archivedData['flight_id']}');

        // Preparar datos para guardar en saved_flights
        final dataToRestore = Map<String, dynamic>.from(archivedData);

        // Actualizar campos
        dataToRestore['archived'] = false;
        dataToRestore['was_archived'] = true;
        dataToRestore['restored_at'] = DateTime.now().toIso8601String();

        // Añadir a saved_flights
        final newDocRef = await savedFlightsRef.add(dataToRestore);
        print('LOG: Vuelo restaurado con nuevo ID: ${newDocRef.id}');

        // Eliminar de archived_flights
        await archivedFlightsRef.doc(docId).delete();
        print('LOG: Documento original eliminado de archived_flights');

        // Actualizar el contador en la colección de fechas si es necesario
        final archivedDate = archivedData['archived_date'] as String?;
        if (archivedDate != null) {
          await _decrementArchivedDateCounter(user.uid, archivedDate);
        }

        // IMPORTANTE: Invalidar ambas cachés para que se actualicen los datos
        await _invalidateCache();
        await _invalidateArchivedCache();

        print('LOG: Vuelo con ID de documento $docId restaurado correctamente');
        return true;
      } else {
        // Si usuario no está autenticado, usar almacenamiento local
        // Esta parte queda igual...
        final SharedPreferences prefs = await SharedPreferences.getInstance();
        final String? jsonFlights = prefs.getString(_userFlightsKey);

        if (jsonFlights == null) {
          return false;
        }

        // Convertir string JSON a lista de vuelos
        List<Map<String, dynamic>> flights = (jsonDecode(jsonFlights) as List)
            .map((item) => Map<String, dynamic>.from(item))
            .toList();

        // Buscar y actualizar el vuelo usando doc_id
        bool found = false;
        String? archivedDate;

        for (int i = 0; i < flights.length; i++) {
          if (flights[i]['doc_id'] == docId) {
            // Guardar fecha de archivo antes de actualizar
            archivedDate = flights[i]['archived_date'] as String?;

            // Restaurar vuelo
            flights[i]['archived'] = false;
            flights[i]['was_archived'] = true;
            flights[i]['restored_at'] = DateTime.now().toIso8601String();
            found = true;
            break;
          }
        }

        if (found) {
          // Guardar lista actualizada
          await prefs.setString(_userFlightsKey, jsonEncode(flights));

          // Invalidar ambas cachés
          await _invalidateCache();
          await _invalidateArchivedCache();

          print('LOG: Vuelo restaurado correctamente en modo offline');
          return true;
        }

        print('LOG: No se encontró el vuelo con ID $docId en modo offline');
        return false;
      }
    } catch (e) {
      print('LOG: Error al restaurar vuelo: $e');
      return false;
    }
  }

  /// Delete a user flight
  static Future<bool> deleteUserFlight(String docId) async {
    try {
      // Get current user
      final user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        // Get reference to user flights collection
        final userFlightsRef = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('saved_flights');

        // IMPORTANTE: Eliminar DIRECTAMENTE por ID del documento
        try {
          // Comprobar primero si el documento existe
          final docSnapshot = await userFlightsRef.doc(docId).get();

          if (docSnapshot.exists) {
            // Si el documento existe, eliminarlo
            await docSnapshot.reference.delete();
            print(
                'LOG: Vuelo con ID de documento $docId eliminado correctamente');
            return true;
          } else {
            print(
                'LOG: No se encontró el documento con ID $docId para eliminar');
            return false;
          }
        } catch (e) {
          print('LOG: Error al eliminar el documento con ID $docId: $e');
          return false;
        }
      } else {
        // Handle local storage deletion for offline mode
        final prefs = await SharedPreferences.getInstance();

        // Get saved flights from local storage
        final savedFlightsJson = prefs.getString(_userFlightsKey);
        if (savedFlightsJson != null) {
          List<dynamic> flights = jsonDecode(savedFlightsJson);

          // Find and remove the flight by doc_id
          int indexToRemove = -1;
          for (int i = 0; i < flights.length; i++) {
            if (flights[i]['doc_id'] == docId) {
              indexToRemove = i;
              break;
            }
          }

          if (indexToRemove != -1) {
            flights.removeAt(indexToRemove);
            // Save the updated list back to shared preferences
            await prefs.setString(_userFlightsKey, jsonEncode(flights));
            print('LOG: Vuelo eliminado localmente');
            return true;
          } else {
            print(
                'LOG: No se encontró el documento con ID $docId en modo offline');
            return false;
          }
        }

        return false;
      }
    } catch (e) {
      print('LOG: Error eliminando vuelo: $e');
      return false;
    }
  }

  /// Método proxy para mantener compatibilidad con llamadas existentes
  /// Simplemente redirecciona a restoreUserFlight
  static Future<bool> restoreArchivedFlight(String docId) async {
    return restoreUserFlight(docId);
  }

  /// Método de diagnóstico para verificar y crear la estructura de carpetas en Firestore
  static Future<void> ensureFirestoreStructure() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('LOG: DIAGNÓSTICO - No hay usuario autenticado');
        return;
      }

      print('LOG: DIAGNÓSTICO - Usuario actual: ${user.uid}');
      print('LOG: DIAGNÓSTICO - Email: ${user.email}');

      // Verificar si existe el documento del usuario
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) {
        print(
            'LOG: DIAGNÓSTICO - El documento del usuario NO existe, creándolo...');
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'email': user.email,
          'displayName': user.displayName ?? 'Usuario',
          'last_active': FieldValue.serverTimestamp(),
          'created_at': FieldValue.serverTimestamp(),
          'diagnostic_check': true,
        });
        print('LOG: DIAGNÓSTICO - Documento de usuario creado');
      } else {
        print(
            'LOG: DIAGNÓSTICO - El documento del usuario SÍ existe: ${userDoc.data()}');
      }

      // Verificar si existe la colección saved_flights
      final savedFlightsCollection = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('saved_flights');

      // Obtener TODOS los documentos sin límite
      final allDocsSnapshot = await savedFlightsCollection.get();

      print(
          'LOG: DIAGNÓSTICO - TOTAL de documentos en saved_flights: ${allDocsSnapshot.docs.length}');

      // Listar todos los documentos
      if (allDocsSnapshot.docs.isNotEmpty) {
        print('LOG: DIAGNÓSTICO - Lista completa de documentos:');
        for (var doc in allDocsSnapshot.docs) {
          final data = doc.data();
          print(
              'LOG: DIAGNÓSTICO - ID: ${doc.id}, flight_id: ${data['flight_id']}, archived: ${data['archived']}');
        }
      }

      // Ahora obtener solo documentos archivados
      final archivedDocsSnapshot =
          await savedFlightsCollection.where('archived', isEqualTo: true).get();

      print(
          'LOG: DIAGNÓSTICO - Documentos ARCHIVADOS encontrados: ${archivedDocsSnapshot.docs.length}');

      // Listar los documentos archivados
      if (archivedDocsSnapshot.docs.isNotEmpty) {
        print('LOG: DIAGNÓSTICO - Lista de documentos archivados:');
        for (var doc in archivedDocsSnapshot.docs) {
          final data = doc.data();
          print(
              'LOG: DIAGNÓSTICO - ID: ${doc.id}, flight_id: ${data['flight_id']}, archived_at: ${data['archived_at']}');
        }
      }

      // Documentos NO archivados
      final notArchivedDocsSnapshot = await savedFlightsCollection
          .where('archived', isEqualTo: false)
          .get();

      print(
          'LOG: DIAGNÓSTICO - Documentos NO ARCHIVADOS encontrados: ${notArchivedDocsSnapshot.docs.length}');

      if (notArchivedDocsSnapshot.docs.isNotEmpty) {
        print('LOG: DIAGNÓSTICO - Lista de documentos NO archivados:');
        for (var doc in notArchivedDocsSnapshot.docs) {
          final data = doc.data();
          print(
              'LOG: DIAGNÓSTICO - ID: ${doc.id}, flight_id: ${data['flight_id']}');
        }
      }

      // Documentos sin campo 'archived'
      final noArchivedFieldDocsSnapshot =
          await savedFlightsCollection.where('archived', isNull: true).get();

      print(
          'LOG: DIAGNÓSTICO - Documentos SIN CAMPO archived: ${noArchivedFieldDocsSnapshot.docs.length}');

      if (noArchivedFieldDocsSnapshot.docs.isNotEmpty) {
        print('LOG: DIAGNÓSTICO - Lista de documentos sin campo archived:');
        for (var doc in noArchivedFieldDocsSnapshot.docs) {
          final data = doc.data();
          print(
              'LOG: DIAGNÓSTICO - ID: ${doc.id}, flight_id: ${data['flight_id']}');
        }
      }

      // Si no hay documentos, crear uno de prueba como antes
      if (allDocsSnapshot.docs.isEmpty) {
        print(
            'LOG: DIAGNÓSTICO - La colección saved_flights NO contiene documentos');

        // Crear un documento de prueba
        final testDoc = await savedFlightsCollection.add({
          'flight_id': 'TEST_FLIGHT',
          'airline': 'TEST',
          'airport': 'Diagnostic Test',
          'gate': 'TEST',
          'schedule_time': DateTime.now().toIso8601String(),
          'saved_at': DateTime.now().toIso8601String(),
          'saved_at_server': FieldValue.serverTimestamp(),
          'diagnostic_test': true,
        });

        print(
            'LOG: DIAGNÓSTICO - Documento de prueba creado con ID: ${testDoc.id}');

        // Actualizar el documento para marcarlo como archivado
        await testDoc.update({
          'archived': true,
          'archived_at': DateTime.now().toIso8601String(),
        });

        print('LOG: DIAGNÓSTICO - Documento de prueba archivado');
      }

      print('LOG: DIAGNÓSTICO - Verificación de estructura completada');
    } catch (e) {
      print('LOG: DIAGNÓSTICO - Error al verificar estructura: $e');
    }
  }

  // Private methods for Firestore operations
  static Future<bool> _saveFlightToFirestore(
      String userId, Map<String, dynamic> flightData) async {
    try {
      print('LOG: Iniciando guardado en Firestore para usuario $userId');
      print('LOG: Datos del vuelo a guardar: $flightData');

      // Reference to user's flights collection
      final userFlightsRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('saved_flights');

      print('LOG: Ruta de Firestore: users/$userId/saved_flights');

      // First, ensure the user document exists with readable information
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        print('LOG: Actualizando información del usuario en Firestore');
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
        print(
            'LOG: Verificando si el vuelo ya existe por flight_ref: ${flightData['flight_ref']}');
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

          print(
              'LOG: Vuelo ya existe por flight_ref, archived: $flightWasArchived, ID: $existingDocId');
        }
      } else {
        print(
            'LOG: ERROR - El vuelo no tiene flight_ref, no se puede guardar correctamente');
        // No se puede guardar correctamente sin flight_ref
        return false;
      }

      // If flight exists and was archived, restore it
      if (flightAlreadyExists && flightWasArchived && existingDocId != null) {
        print('LOG: El vuelo existe pero estaba archivado. Restaurándolo...');

        await userFlightsRef.doc(existingDocId).update({
          'archived': false,
          'was_archived': true, // Flag to indicate it was previously archived
          'restored_at': DateTime.now().toIso8601String(),
          'saved_at':
              DateTime.now().toIso8601String(), // Update saved_at to now
        });

        // Update the reference data with was_archived flag for UI to use
        flightData['was_archived'] = true;

        print('LOG: Vuelo restaurado correctamente con ID: $existingDocId');
        return true; // Return true because flight was restored (equivalent to adding it)
      }

      // If flight exists but was not archived, just return false
      if (flightAlreadyExists && !flightWasArchived) {
        print('LOG: Vuelo ya existe y no está archivado');
        return false;
      }

      // Add flight to Firestore if it doesn't exist
      print('LOG: Añadiendo vuelo nuevo a Firestore');
      final docRef = await userFlightsRef.add({
        ...flightData,
        'archived': false, // Explicitly set archived to false for new flights
        'saved_at_server': FieldValue.serverTimestamp(),
      });

      print('LOG: Vuelo guardado correctamente con ID: ${docRef.id}');

      return true;
    } catch (e) {
      print('LOG: Error saving flight to Firestore: $e');
      rethrow;
    }
  }

  static Future<List<Map<String, dynamic>>> _getFlightRefsFromFirestore(
      String userId) async {
    try {
      // Reference to user's flights collection
      final userFlightsRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('saved_flights');

      // Get all saved flights, excluding archived ones, ordered by saved_at timestamp
      try {
        // Intentar con una consulta más simple que no requiera índices compuestos
        // Primero, intentar obtener documentos no archivados
        final flightsSnapshot =
            await userFlightsRef.where('archived', isNotEqualTo: true).get();

        // Si el filtro falla, usar query simple y ordenar en memoria
        if (flightsSnapshot.docs.isNotEmpty) {
          print(
              'LOG: Found ${flightsSnapshot.docs.length} flights with simple query');

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
          print(
              'LOG: No se encontraron vuelos no archivados, probando consulta simple');
          // Intentar obtener todos los documentos
          final allFlightsSnapshot = await userFlightsRef.get();

          print('LOG: Fetched ${allFlightsSnapshot.docs.length} total flights');

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

          print('LOG: Found ${result.length} flights with manual filtering');
          return result;
        }
      } catch (e) {
        // Si falla (probablemente por falta de índices compuestos), usar una consulta más simple
        print('LOG: Las consultas fallaron, usando enfoque alternativo: $e');

        // Obtener todos los documentos sin filtro
        final allFlightsSnapshot = await userFlightsRef.get();

        print('LOG: Fetched ${allFlightsSnapshot.docs.length} total flights');

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

        print('LOG: Found ${result.length} flights with manual filtering');
        return result;
      }
    } catch (e) {
      print('LOG: Error getting flight refs from Firestore: $e');
      // No propagar el error, simplemente devolver una lista vacía
      return [];
    }
  }

  static Future<bool> _removeFlightFromFirestore(
      String userId, String docId) async {
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
          print(
              'LOG: Documento con ID $docId eliminado correctamente de Firestore');
          return true;
        } else {
          print('LOG: No se encontró el documento con ID $docId en Firestore');
          return false;
        }
      } catch (e) {
        print(
            'LOG: Error al acceder al documento con ID $docId en Firestore: $e');
        return false;
      }
    } catch (e) {
      print('LOG: Error removing flight from Firestore: $e');
      rethrow;
    }
  }

  // Private methods for SharedPreferences operations
  static Future<bool> _saveFlightToLocalStorage(
      Map<String, dynamic> flight) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Get current flights list
      List<Map<String, dynamic>> flights = await _getFlightsFromLocalStorage();

      // Verificar solo por 'id' (flight_ref) para evitar confusiones con vuelos diferentes pero mismo código
      if (flights.any((f) =>
          (f['id'] != null &&
              flight['id'] != null &&
              f['id'] == flight['id']) ||
          (f['flight_ref'] != null &&
              flight['flight_ref'] != null &&
              f['flight_ref'] == flight['flight_ref']))) {
        // Flight already saved
        print(
            'LOG: Vuelo ya guardado en almacenamiento local: ${flight['id'] ?? flight['flight_ref']}');
        return false;
      }

      // Add flight to list
      flights.add({
        ...flight,
      });

      // Save updated list
      final flightsJson = flights.map((f) => jsonEncode(f)).toList();
      await prefs.setStringList(_userFlightsKey, flightsJson);

      print(
          'LOG: Vuelo guardado en almacenamiento local: ${flight['id'] ?? flight['flight_ref']}');
      return true;
    } catch (e) {
      print('LOG: Error saving flight to local storage: $e');
      rethrow;
    }
  }

  static Future<List<Map<String, dynamic>>>
      _getFlightsFromLocalStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Get saved flights list
      final flightsJson = prefs.getStringList(_userFlightsKey) ?? [];

      // Convert to List<Map<String, dynamic>>
      List<Map<String, dynamic>> flights = flightsJson.map((flightJson) {
        return Map<String, dynamic>.from(jsonDecode(flightJson));
      }).toList();

      // Filtrar para excluir los vuelos archivados
      return flights.where((flight) => flight['archived'] != true).toList();
    } catch (e) {
      print('LOG: Error getting flights from local storage: $e');
      rethrow;
    }
  }

  static Future<bool> _removeFlightFromLocalStorage(String docId) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Get current flights list
      List<Map<String, dynamic>> flights = await _getFlightsFromLocalStorage();

      // Remove flight from list by checking doc_id field
      final originalLength = flights.length;
      flights.removeWhere((flight) => flight['doc_id'] == docId);

      if (flights.length == originalLength) {
        // No flight was removed
        print(
            'LOG: No se encontró el documento con ID $docId en almacenamiento local');
        return false;
      }

      // Save updated list
      final flightsJson = flights.map((f) => jsonEncode(f)).toList();
      await prefs.setStringList(_userFlightsKey, flightsJson);
      print('LOG: Documento con ID $docId eliminado del almacenamiento local');

      return true;
    } catch (e) {
      print('LOG: Error removing flight from local storage: $e');
      rethrow;
    }
  }

  /// Update user information in Firestore
  /// This helps improve readability in the Firebase console
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

        print(
            'LOG: User info updated in Firestore for better console readability');
      }
    } catch (e) {
      print('LOG: Error updating user info: $e');
      // Non-critical error, don't throw
    }
  }

  /// Método para guardar los vuelos del usuario en caché
  static Future<bool> _saveToCache(List<Map<String, dynamic>> flights) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Convertir los vuelos a un formato serializable
      final List<Map<String, dynamic>> serializableFlights =
          flights.map((flight) {
        final Map<String, dynamic> copy = Map.from(flight);
        if (copy['color'] is Color) {
          copy['color'] = (copy['color'] as Color).value;
        }
        return copy;
      }).toList();

      // Guardar en SharedPreferences
      final String jsonData = jsonEncode(serializableFlights);
      await prefs.setString(_cachedUserFlightsKey, jsonData);

      // Guardar también la fecha de última actualización
      await prefs.setString(
          _userFlightsLastUpdatedKey, DateTime.now().toIso8601String());

      print('LOG: ${flights.length} vuelos del usuario guardados en caché');
      return true;
    } catch (e) {
      print('LOG: Error al guardar vuelos del usuario en caché: $e');
      return false;
    }
  }

  /// Método para cargar los vuelos del usuario desde la caché
  static Future<List<Map<String, dynamic>>> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Verificar si tenemos datos en caché
      final jsonData = prefs.getString(_cachedUserFlightsKey);
      if (jsonData == null) {
        print('LOG: No hay vuelos del usuario en caché');
        return [];
      }

      // Verificar si los datos de caché son recientes (menos de 5 minutos)
      final lastUpdatedStr = prefs.getString(_userFlightsLastUpdatedKey);
      if (lastUpdatedStr != null) {
        final lastUpdated = DateTime.parse(lastUpdatedStr);
        final now = DateTime.now();
        final difference = now.difference(lastUpdated);

        // Si los datos tienen más de 5 minutos, considerarlos obsoletos
        if (difference.inMinutes > 5) {
          print(
              'LOG: Datos de caché obsoletos (${difference.inMinutes} minutos)');
          return [];
        }
      } else {
        // Si no hay timestamp, los datos se consideran obsoletos
        return [];
      }

      // Deserializar los datos
      final List<dynamic> decoded = jsonDecode(jsonData);
      final flights = decoded.map((item) {
        final Map<String, dynamic> flight = Map<String, dynamic>.from(item);
        if (flight['color'] is int) {
          flight['color'] = Color(flight['color']);
        }
        return flight;
      }).toList();

      // Filtrar los vuelos según su estado
      final List<Map<String, dynamic>> filteredFlights = [];
      for (var flight in flights) {
        final String statusCode = flight['status_code']?.toString() ?? '';

        if (statusCode == 'D' || statusCode == 'C') {
          // Los vuelos con status 'D' (departed) o 'C' (cancelled) se mantienen en caché
          filteredFlights.add(flight);
        } else if (statusCode == 'E') {
          // Para vuelos con status 'E' (new time), verificar si la caché es reciente
          final lastUpdated = DateTime.parse(lastUpdatedStr);
          final now = DateTime.now();
          final difference = now.difference(lastUpdated);
          if (difference.inMinutes <= 5) {
            filteredFlights.add(flight);
          }
        } else if (statusCode == 'N/A') {
          // Para vuelos con status 'N/A' (pronto para saber el estado), verificar si la caché es reciente
          final lastUpdated = DateTime.parse(lastUpdatedStr);
          final now = DateTime.now();
          final difference = now.difference(lastUpdated);
          if (difference.inMinutes <= 5) {
            filteredFlights.add(flight);
          }
        } else {
          // Para otros vuelos, verificar si la caché es reciente
          final lastUpdated = DateTime.parse(lastUpdatedStr);
          final now = DateTime.now();
          final difference = now.difference(lastUpdated);
          if (difference.inMinutes <= 5) {
            filteredFlights.add(flight);
          }
        }
      }

      print(
          'LOG: ${filteredFlights.length} vuelos del usuario cargados desde caché');
      return filteredFlights.cast<Map<String, dynamic>>();
    } catch (e) {
      print('LOG: Error al cargar vuelos del usuario desde caché: $e');
      return [];
    }
  }

  /// Método para invalidar la caché (llamado cuando los datos cambian)
  static Future<void> _invalidateCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cachedUserFlightsKey);
      await prefs.remove(_userFlightsLastUpdatedKey);
      print('LOG: Caché de vuelos del usuario invalidada');
    } catch (e) {
      print('LOG: Error al invalidar caché de vuelos del usuario: $e');
    }
  }

  /// Método para guardar las fechas de vuelos archivados en caché
  static Future<bool> _saveArchivedDatesToCache(
      List<ArchivedFlightDate> dates) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Convertir las fechas a un formato serializable
      final List<Map<String, dynamic>> serializableDates =
          dates.map((date) => date.toMap()).toList();

      // Guardar en SharedPreferences
      final String jsonData = jsonEncode(serializableDates);
      await prefs.setString(_cachedUserArchivedDatesKey, jsonData);

      // Guardar también la fecha de última actualización
      await prefs.setString(
          _userArchivedDatesLastUpdatedKey, DateTime.now().toIso8601String());

      print(
          'LOG: ${dates.length} fechas de vuelos archivados guardadas en caché');
      return true;
    } catch (e) {
      print('LOG: Error al guardar fechas de vuelos archivados en caché: $e');
      return false;
    }
  }

  /// Método para cargar las fechas de vuelos archivados desde la caché
  static Future<List<ArchivedFlightDate>> _loadArchivedDatesFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Verificar si tenemos datos en caché
      final jsonData = prefs.getString(_cachedUserArchivedDatesKey);
      if (jsonData == null) {
        print('LOG: No hay fechas de vuelos archivados en caché');
        return [];
      }

      // Verificar si los datos de caché son recientes (menos de 10 minutos)
      final lastUpdatedStr = prefs.getString(_userArchivedDatesLastUpdatedKey);
      if (lastUpdatedStr != null) {
        final lastUpdated = DateTime.parse(lastUpdatedStr);
        final now = DateTime.now();
        final difference = now.difference(lastUpdated);

        // Si los datos tienen más de 10 minutos, considerarlos obsoletos
        if (difference.inMinutes > 10) {
          print(
              'LOG: Datos de caché de fechas archivadas obsoletos (${difference.inMinutes} minutos)');
          return [];
        }
      } else {
        // Si no hay timestamp, los datos se consideran obsoletos
        return [];
      }

      // Deserializar los datos
      final List<dynamic> decoded = jsonDecode(jsonData);
      final dates = decoded.map((item) {
        return ArchivedFlightDate.fromMap(Map<String, dynamic>.from(item));
      }).toList();

      print(
          'LOG: ${dates.length} fechas de vuelos archivados cargadas desde caché');
      return dates.cast<ArchivedFlightDate>();
    } catch (e) {
      print('LOG: Error al cargar fechas de vuelos archivados desde caché: $e');
      return [];
    }
  }

  /// Método para guardar los vuelos archivados por fecha en caché
  static Future<bool> _saveArchivedFlightsByDateToCache(
      String date, List<Map<String, dynamic>> flights) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Crear clave específica para esta fecha
      final String cacheKey = '${_cachedUserArchivedFlightsKey}_$date';

      // Convertir los vuelos a un formato serializable
      final List<Map<String, dynamic>> serializableFlights =
          flights.map((flight) {
        final Map<String, dynamic> copy = Map.from(flight);
        if (copy['color'] is Color) {
          copy['color'] = (copy['color'] as Color).value;
        }
        return copy;
      }).toList();

      // Guardar en SharedPreferences
      final String jsonData = jsonEncode(serializableFlights);
      await prefs.setString(cacheKey, jsonData);

      // Guardar también la fecha de última actualización
      final String updateTimeKey =
          '${_userArchivedFlightsLastUpdatedKey}_$date';
      await prefs.setString(updateTimeKey, DateTime.now().toIso8601String());

      print(
          'LOG: ${flights.length} vuelos archivados para la fecha $date guardados en caché');
      return true;
    } catch (e) {
      print('LOG: Error al guardar vuelos archivados por fecha en caché: $e');
      return false;
    }
  }

  /// Método para cargar los vuelos archivados por fecha desde la caché
  static Future<List<Map<String, dynamic>>> _loadArchivedFlightsByDateFromCache(
      String date) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Crear clave específica para esta fecha
      final String cacheKey = '${_cachedUserArchivedFlightsKey}_$date';
      final String updateTimeKey =
          '${_userArchivedFlightsLastUpdatedKey}_$date';

      // Verificar si tenemos datos en caché
      final jsonData = prefs.getString(cacheKey);
      if (jsonData == null) {
        print('LOG: No hay vuelos archivados para la fecha $date en caché');
        return [];
      }

      // Verificar si los datos de caché son recientes (menos de 10 minutos)
      final lastUpdatedStr = prefs.getString(updateTimeKey);
      if (lastUpdatedStr != null) {
        final lastUpdated = DateTime.parse(lastUpdatedStr);
        final now = DateTime.now();
        final difference = now.difference(lastUpdated);

        // Si los datos tienen más de 10 minutos, considerarlos obsoletos
        if (difference.inMinutes > 10) {
          print(
              'LOG: Datos de caché de vuelos archivados para $date obsoletos (${difference.inMinutes} minutos)');
          return [];
        }
      } else {
        // Si no hay timestamp, los datos se consideran obsoletos
        return [];
      }

      // Deserializar los datos
      final List<dynamic> decoded = jsonDecode(jsonData);
      final flights = decoded.map((item) {
        final Map<String, dynamic> flight = Map<String, dynamic>.from(item);
        if (flight['color'] is int) {
          flight['color'] = Color(flight['color']);
        }
        return flight;
      }).toList();

      print(
          'LOG: ${flights.length} vuelos archivados para la fecha $date cargados desde caché');
      return flights.cast<Map<String, dynamic>>();
    } catch (e) {
      print('LOG: Error al cargar vuelos archivados desde caché: $e');
      return [];
    }
  }

  /// Método para invalidar la caché de vuelos archivados
  static Future<void> _invalidateArchivedCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Eliminar la caché de fechas
      await prefs.remove(_cachedUserArchivedDatesKey);
      await prefs.remove(_userArchivedDatesLastUpdatedKey);

      // Intentar eliminar todas las entradas de caché de vuelos archivados
      // Obtenemos todas las claves y filtramos las que corresponden a vuelos archivados
      final Set<String> keys = prefs.getKeys();
      final List<String> archivedKeys = keys
          .where((key) =>
              key.startsWith(_cachedUserArchivedFlightsKey) ||
              key.startsWith(_userArchivedFlightsLastUpdatedKey))
          .toList();

      // Eliminar cada clave
      for (final key in archivedKeys) {
        await prefs.remove(key);
      }

      print(
          'LOG: Caché de vuelos archivados invalidada (${archivedKeys.length} entradas)');
    } catch (e) {
      print('LOG: Error al invalidar caché de vuelos archivados: $e');
    }
  }

  /// Archive a user flight
  static Future<bool> archiveUserFlight(String docId) async {
    try {
      // Get current user
      final user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        // Get reference to user flights collection
        final userFlightsRef = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('saved_flights');

        // IMPORTANTE: Buscar DIRECTAMENTE por ID del documento
        try {
          // Intentar obtener el documento directamente por su ID
          final docSnapshot = await userFlightsRef.doc(docId).get();

          if (docSnapshot.exists) {
            // Si el documento existe, actualizarlo para archivarlo
            await docSnapshot.reference.update({
              'archived': true,
              'archived_at': DateTime.now().toIso8601String(),
            });
            print(
                'LOG: Vuelo con ID de documento $docId archivado correctamente');
            return true;
          } else {
            print(
                'LOG: No se encontró el documento con ID $docId para archivar');
            return false;
          }
        } catch (e) {
          print('LOG: Error al acceder al documento con ID $docId: $e');
          return false;
        }
      } else {
        // Handle local storage archiving for offline mode
        final prefs = await SharedPreferences.getInstance();

        // Get saved flights from local storage
        final savedFlightsJson = prefs.getString(_userFlightsKey);
        if (savedFlightsJson != null) {
          List<dynamic> flights = jsonDecode(savedFlightsJson);

          // Find and archive the flight by doc_id
          bool flightArchived = false;
          for (int i = 0; i < flights.length; i++) {
            if (flights[i]['doc_id'] == docId) {
              flights[i]['archived'] = true;
              flights[i]['archived_at'] = DateTime.now().toIso8601String();
              flightArchived = true;
              break;
            }
          }

          if (flightArchived) {
            // Save the updated list back to shared preferences
            await prefs.setString(_userFlightsKey, jsonEncode(flights));
            print('LOG: Vuelo archivado localmente');
            return true;
          } else {
            print(
                'LOG: No se encontró el documento con ID $docId en modo offline');
            return false;
          }
        }

        print('LOG: No hay datos de vuelos guardados en modo offline');
        return false;
      }
    } catch (e) {
      print('LOG: Error archivando vuelo: $e');
      return false;
    }
  }
}
