import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import '../../utils/airline_helper.dart';

/// Service to manage user's saved flights
class UserFlightsService {
  static const String _userFlightsKey = 'user_flights';

  /// Save a flight to user's saved flights list
  /// Returns true if the flight was added, false if it was already in the list
  static Future<bool> saveFlight(Map<String, dynamic> flight) async {
    try {
      // Get current user
      final user = FirebaseAuth.instance.currentUser;

      // Prepare basic saved flight data (only reference)
      final Map<String, dynamic> savedFlightData = {
        'flight_ref': flight['id'], // Reference to original flight document
        'flight_id': flight['flight_id'], // Keep flight ID for easier queries
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

        return result;
      } else {
        // For local storage, we still need all flight details
        // but we'll ensure we have the reference for future compatibility
        final processedFlight = _processFlightForStorage(flight);
        processedFlight['flight_ref'] = flight['id']; // Add reference
        return await _saveFlightToLocalStorage(processedFlight);
      }
    } catch (e) {
      print('LOG: Error saving flight: $e');
      return false;
    }
  }

  /// Get user's saved flights
  static Future<List<Map<String, dynamic>>> getUserFlights() async {
    try {
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

      // Get full flight data from references
      final List<Map<String, dynamic>> completeFlights =
          await _getCompleteFlightData(userFlightRefs);

      // Process flights for use in UI (convert integers back to Color objects, etc.)
      return completeFlights.map(_processFlightForUI).toList();
    } catch (e) {
      print('LOG: Error getting user flights: $e');
      return [];
    }
  }

  /// Get complete and updated flight data from references
  static Future<List<Map<String, dynamic>>> _getCompleteFlightData(
      List<Map<String, dynamic>> flightRefs) async {
    final List<Map<String, dynamic>> completeFlights = [];

    // Process each flight reference
    for (final ref in flightRefs) {
      try {
        // Get the flight document from main collection using the reference
        final flightId = ref['flight_ref'];

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
            'id': flightDoc.id,
            'saved_at': ref['saved_at'],
            'doc_id': ref['doc_id'], // Keep reference to user's saved document
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
          print(
              'LOG: Flight ${ref['flight_id']} no longer exists, using reference data');
          final basicData = {
            ...ref,
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
        completeFlights.add({
          ...ref,
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
        return await _removeFlightFromFirestore(user.uid, docId);
      } else {
        // If user is not logged in, remove from SharedPreferences
        return await _removeFlightFromLocalStorage(docId);
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
      // Check both 'id' and 'flight_id' fields to ensure proper matching
      return flights.any((flight) =>
          (flight['id'] != null && flight['id'] == flightId) ||
          (flight['flight_id'] != null && flight['flight_id'] == flightId));
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

  /// Archive a flight (no eliminar, sólo marcar como archivado)
  /// Returns true if the flight was archived successfully, false otherwise
  static Future<bool> archiveFlight(String docId) async {
    try {
      // Get current user
      final user = FirebaseAuth.instance.currentUser;
      print('LOG: Iniciando proceso de archivar vuelo con docId: $docId');
      print('LOG: Usuario actual: ${user?.uid ?? "No hay usuario logueado"}');

      if (user != null) {
        // If user is logged in, update document in Firestore
        final userFlightsRef = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('saved_flights');

        print('LOG: Ruta de Firestore: users/${user.uid}/saved_flights/$docId');

        // IMPORTANTE: Buscar DIRECTAMENTE por ID del documento
        try {
          // Intentar obtener el documento directamente por su ID
          print('LOG: Intentando obtener el documento con ID: $docId');
          final docSnapshot = await userFlightsRef.doc(docId).get();

          if (docSnapshot.exists) {
            // Si el documento existe, actualizarlo para archivarlo
            print(
                'LOG: Documento encontrado. Datos actuales: ${docSnapshot.data()}');
            print('LOG: Actualizando documento para archivarlo...');

            await docSnapshot.reference.update({
              'archived': true,
              'archived_at': DateTime.now().toIso8601String(),
            });

            // Verificar que el documento se actualizó correctamente
            final updatedDoc = await userFlightsRef.doc(docId).get();
            print('LOG: Documento después de actualizar: ${updatedDoc.data()}');

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
        // Si el usuario no está logueado, usar SharedPreferences
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
        for (int i = 0; i < flights.length; i++) {
          if (flights[i]['doc_id'] == docId) {
            flights[i]['archived'] = true;
            flights[i]['archived_at'] = DateTime.now().toIso8601String();
            found = true;
            break;
          }
        }

        if (found) {
          // Guardar la lista actualizada
          final String updatedJsonFlights = jsonEncode(flights);
          await prefs.setString(_userFlightsKey, updatedJsonFlights);
          print('LOG: Vuelo archivado localmente');
          return true;
        }

        print('LOG: No se encontró el documento con ID $docId en modo offline');
        return false;
      }
    } catch (e) {
      print('LOG: Error archivando vuelo: $e');
      return false;
    }
  }

  /// Get user's archived flights
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
              final data = doc.data() as Map<String, dynamic>;
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
            final data = doc.data() as Map<String, dynamic>;

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
            // Orden descendente
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

  /// Restore an archived flight
  static Future<bool> restoreUserFlight(String docId) async {
    try {
      // Get current user
      final user = FirebaseAuth.instance.currentUser;
      print('LOG: Iniciando proceso de restaurar vuelo con docId: $docId');
      print('LOG: Usuario actual: ${user?.uid ?? "No hay usuario logueado"}');

      if (user != null) {
        // Get reference to user flights collection
        final userFlightsRef = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('saved_flights');

        print('LOG: Ruta de Firestore: users/${user.uid}/saved_flights/$docId');

        // IMPORTANTE: Buscar DIRECTAMENTE por ID del documento
        try {
          // Intentar obtener el documento directamente por su ID
          print('LOG: Intentando obtener el documento con ID: $docId');
          final docSnapshot = await userFlightsRef.doc(docId).get();

          if (docSnapshot.exists) {
            print(
                'LOG: Documento encontrado. Datos actuales: ${docSnapshot.data()}');

            // Verificar si el documento está realmente archivado
            final data = docSnapshot.data() as Map<String, dynamic>;
            if (data['archived'] != true) {
              print(
                  'LOG: El documento no estaba archivado, no es necesario restaurarlo');
              return true; // Consideramos éxito si ya estaba restaurado
            }

            // Si el documento existe, actualizarlo para restaurarlo
            print('LOG: Actualizando documento para restaurarlo...');
            await docSnapshot.reference.update({
              'archived': false,
              'was_archived':
                  true, // Flag to indicate it was previously archived
              'restored_at': DateTime.now().toIso8601String(),
            });

            // Verificar que el documento se actualizó correctamente
            final updatedDoc = await userFlightsRef.doc(docId).get();
            print('LOG: Documento después de restaurar: ${updatedDoc.data()}');

            print(
                'LOG: Vuelo con ID de documento $docId restaurado correctamente');
            return true;
          } else {
            print(
                'LOG: No se encontró el documento con ID $docId para restaurar');
            return false;
          }
        } catch (e) {
          print('LOG: Error al acceder al documento con ID $docId: $e');
          return false;
        }
      } else {
        // Handle local storage restoration for offline mode
        final prefs = await SharedPreferences.getInstance();

        // Get saved flights from local storage
        final savedFlightsJson = prefs.getString(_userFlightsKey);
        if (savedFlightsJson != null) {
          List<dynamic> flights = jsonDecode(savedFlightsJson);

          // Find and restore the flight by doc_id
          bool flightRestored = false;
          for (int i = 0; i < flights.length; i++) {
            if (flights[i]['doc_id'] == docId &&
                flights[i]['archived'] == true) {
              flights[i]['archived'] = false;
              flights[i]['was_archived'] =
                  true; // Flag to indicate it was previously archived
              flights[i]['restored_at'] = DateTime.now().toIso8601String();
              flightRestored = true;
              break;
            }
          }

          if (flightRestored) {
            // Save the updated list back to shared preferences
            await prefs.setString(_userFlightsKey, jsonEncode(flights));
            print('LOG: Vuelo restaurado localmente');
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
      print('LOG: Error restaurando vuelo: $e');
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

      // First try to check by 'flight_ref' if available
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
              'LOG: Vuelo ya existe por flight_ref, archived: $flightWasArchived');
        }
      }

      // Then check by 'flight_id' as backup (only if not found by ref)
      if (!flightAlreadyExists && flightData['flight_id'] != null) {
        print(
            'LOG: Verificando si el vuelo ya existe por flight_id: ${flightData['flight_id']}');
        existingFlights = await userFlightsRef
            .where('flight_id', isEqualTo: flightData['flight_id'])
            .get();

        if (existingFlights.docs.isNotEmpty) {
          // Flight already exists by flight_id
          flightAlreadyExists = true;
          existingDocId = existingFlights.docs.first.id;

          // Check if it was archived
          final docData =
              existingFlights.docs.first.data() as Map<String, dynamic>;
          flightWasArchived = docData['archived'] == true;

          print(
              'LOG: Vuelo ya existe por flight_id, archived: $flightWasArchived');
        }
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
      throw e;
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
            final data = doc.data() as Map<String, dynamic>;
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
            final data = doc.data() as Map<String, dynamic>;

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
          final data = doc.data() as Map<String, dynamic>;

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
      throw e;
    }
  }

  // Private methods for SharedPreferences operations
  static Future<bool> _saveFlightToLocalStorage(
      Map<String, dynamic> flight) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Get current flights list
      List<Map<String, dynamic>> flights = await _getFlightsFromLocalStorage();

      // Check if flight already exists by 'id' or 'flight_id'
      if (flights.any((f) =>
          (f['id'] != null &&
              flight['id'] != null &&
              f['id'] == flight['id']) ||
          (f['flight_id'] != null &&
              flight['flight_id'] != null &&
              f['flight_id'] == flight['flight_id']))) {
        // Flight already saved
        return false;
      }

      // Add flight to list
      flights.add({
        ...flight,
      });

      // Save updated list
      final flightsJson = flights.map((f) => jsonEncode(f)).toList();
      await prefs.setStringList(_userFlightsKey, flightsJson);

      return true;
    } catch (e) {
      print('LOG: Error saving flight to local storage: $e');
      throw e;
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
      throw e;
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
      throw e;
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
}
