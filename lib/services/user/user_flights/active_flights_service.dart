import 'package:firebase_auth/firebase_auth.dart';
import '../../../utils/logger.dart';

import '../storage/flights_firestore_service.dart';
import '../storage/flights_local_storage.dart';
import '../storage/flights_cache_service.dart';
import 'user_flights_helpers.dart';

/// Servicio con la lógica relacionada a los vuelos «activos» (guardados y no archivados).
class ActiveFlightsService {
  /// Guarda un vuelo en la lista del usuario.
  /// Devuelve `true` si se añadió, `false` si ya existía.
  static Future<bool> saveFlight(Map<String, dynamic> flight) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final Map<String, dynamic> savedFlightData = {
        'flight_ref': flight['id'],
        'flight_id': flight['flight_id'],
        'saved_at': DateTime.now().toIso8601String(),
      };

      if (user != null) {
        savedFlightData['saved_by_user'] = {
          'uid': user.uid,
          'email': user.email,
          'displayName': user.displayName,
        };
        final result =
            await FlightsFirestoreService.saveFlight(user.uid, savedFlightData);
        if (result && savedFlightData['was_archived'] == true) {
          flight['was_archived'] = true;
        }
        await FlightsCacheService.invalidateFlightsCache();
        return result;
      } else {
        final processed = UserFlightsHelpers.processFlightForStorage(flight)
          ..['flight_ref'] = flight['id'];
        await FlightsCacheService.invalidateFlightsCache();
        return await FlightsLocalStorage.saveFlight(processed);
      }
    } catch (e) {
      AppLogger.error('ActiveFlights: error saving flight', e);
      return false;
    }
  }

  /// Obtiene los vuelos guardados del usuario (no archivados).
  static Future<List<Map<String, dynamic>>> getUserFlights(
      {bool forceRefresh = false}) async {
    try {
      if (!forceRefresh) {
        final cached = await FlightsCacheService.loadFlightsFromCache();
        if (cached.isNotEmpty) {
          AppLogger.info('ActiveFlights: cache hit (${cached.length})');
          return cached;
        }
      }
      AppLogger.info('ActiveFlights: cargando vuelos desde origen');
      final user = FirebaseAuth.instance.currentUser;
      List<Map<String, dynamic>> refs;
      if (user != null) {
        refs = await FlightsFirestoreService.getFlightRefs(user.uid);
      } else {
        refs = await FlightsLocalStorage.getFlights();
      }
      refs = refs.where((f) => f['archived'] != true).toList();
      final complete =
          await UserFlightsHelpers.getCompleteFlightDataBatch(refs);
      final processed =
          complete.map(UserFlightsHelpers.processFlightForUI).toList();
      await FlightsCacheService.saveFlightsToCache(processed);
      return processed;
    } catch (e) {
      AppLogger.error('ActiveFlights: error getUserFlights', e);
      return [];
    }
  }

  /// Elimina un vuelo guardado.
  static Future<bool> removeFlight(String docId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      bool result;
      if (user != null) {
        result = await FlightsFirestoreService.removeFlight(user.uid, docId);
      } else {
        result = await FlightsLocalStorage.removeFlight(docId);
      }
      if (result) {
        await FlightsCacheService.invalidateFlightsCache();
      }
      return result;
    } catch (e) {
      AppLogger.error('ActiveFlights: error removeFlight', e);
      return false;
    }
  }

  /// Comprueba si un vuelo ya está guardado.
  static Future<bool> isFlightSaved(String flightId) async {
    try {
      final flights = await getUserFlights();
      return flights.any((f) =>
          (f['id'] != null && f['id'] == flightId) ||
          (f['flight_ref'] != null && f['flight_ref'] == flightId));
    } catch (e) {
      AppLogger.error('ActiveFlights: error isFlightSaved', e);
      return false;
    }
  }

  /// Borra un vuelo (proxy para compatibilidad histórica).
  static Future<bool> deleteUserFlight(String docId) => removeFlight(docId);
}
