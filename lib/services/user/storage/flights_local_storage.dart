import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../../utils/logger.dart';

/// Servicio para manejar el almacenamiento local de vuelos usando SharedPreferences
class FlightsLocalStorage {
  static const String _userFlightsKey = 'user_flights';

  /// Guardar un vuelo en el almacenamiento local
  static Future<bool> saveFlight(Map<String, dynamic> flight) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Get current flights list
      List<Map<String, dynamic>> flights = await getFlights();

      // Verificar solo por 'id' (flight_ref) para evitar confusiones con vuelos diferentes pero mismo código
      if (flights.any((f) =>
          (f['id'] != null &&
              flight['id'] != null &&
              f['id'] == flight['id']) ||
          (f['flight_ref'] != null &&
              flight['flight_ref'] != null &&
              f['flight_ref'] == flight['flight_ref']))) {
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
      AppLogger.error('Error saving flight to local storage', e);
      rethrow;
    }
  }

  /// Obtener todos los vuelos del almacenamiento local (excluyendo archivados)
  static Future<List<Map<String, dynamic>>> getFlights() async {
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
      AppLogger.error('Error getting flights from local storage', e);
      rethrow;
    }
  }

  /// Eliminar un vuelo del almacenamiento local por docId
  static Future<bool> removeFlight(String docId) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Get current flights list
      List<Map<String, dynamic>> flights = await getFlights();

      // Remove flight from list by checking doc_id field
      final originalLength = flights.length;
      flights.removeWhere((flight) => flight['doc_id'] == docId);

      if (flights.length == originalLength) {
        // No flight was removed
        AppLogger.warning(
            'No se encontró el documento con ID $docId en almacenamiento local');
        return false;
      }

      // Save updated list
      final flightsJson = flights.map((f) => jsonEncode(f)).toList();
      await prefs.setStringList(_userFlightsKey, flightsJson);

      return true;
    } catch (e) {
      AppLogger.error('Error removing flight from local storage', e);
      rethrow;
    }
  }

  /// Archivar un vuelo en almacenamiento local
  static Future<bool> archiveFlight(String docId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedFlightsJson = prefs.getString(_userFlightsKey);

      if (savedFlightsJson != null) {
        List<dynamic> flights = jsonDecode(savedFlightsJson);

        // Find and archive the flight by doc_id
        bool flightArchived = false;
        for (int i = 0; i < flights.length; i++) {
          if (flights[i]['doc_id'] == docId) {
            flights[i]['archived'] = true;
            flights[i]['archived_at'] = DateTime.now().toIso8601String();
            flights[i]['archived_date'] =
                DateTime.now().toIso8601String().split('T')[0];
            flightArchived = true;
            break;
          }
        }

        if (flightArchived) {
          // Save the updated list back to shared preferences
          await prefs.setString(_userFlightsKey, jsonEncode(flights));
          return true;
        }
      }

      return false;
    } catch (e) {
      AppLogger.error('Error archiving flight in local storage', e);
      return false;
    }
  }

  /// Restaurar un vuelo archivado en almacenamiento local
  static Future<bool> restoreFlight(String docId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
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
        return true;
      }

      return false;
    } catch (e) {
      AppLogger.error('Error restoring flight in local storage', e);
      return false;
    }
  }

  /// Eliminar permanentemente un vuelo archivado
  static Future<bool> permanentlyDeleteFlight(String docId) async {
    try {
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

      for (int i = 0; i < flights.length; i++) {
        if (flights[i]['doc_id'] == docId && flights[i]['archived'] == true) {
          indexToRemove = i;
          break;
        }
      }

      if (indexToRemove != -1) {
        // Eliminar el vuelo
        flights.removeAt(indexToRemove);

        // Guardar la lista actualizada
        await prefs.setString(_userFlightsKey, jsonEncode(flights));
        return true;
      }

      return false;
    } catch (e) {
      AppLogger.error(
          'Error permanently deleting flight from local storage', e);
      return false;
    }
  }
}
