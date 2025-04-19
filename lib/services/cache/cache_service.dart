import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

/// Servicio para gestionar la persistencia de datos entre sesiones de la aplicación
class CacheService {
  static const String _flightsKey = 'cached_flights';
  static const String _filtersKey = 'cached_filters';
  static const String _lastUpdatedKey = 'last_updated';

  /// Almacena los vuelos en la caché persistente
  static Future<bool> saveFlights(List<Map<String, dynamic>> flights) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Convertimos los objetos Color a valores hexadecimales para poder serializarlos
      final serializableFlights = flights.map((flight) {
        final Map<String, dynamic> copy = Map.from(flight);
        if (copy['color'] is Color) {
          copy['color'] = (copy['color'] as Color).value;
        }
        return copy;
      }).toList();

      // Guardamos la lista como JSON string
      final jsonData = jsonEncode(serializableFlights);
      await prefs.setString(_flightsKey, jsonData);

      // Guardar la fecha y hora de la última actualización
      await prefs.setString(_lastUpdatedKey, DateTime.now().toIso8601String());

      print('LOG: Vuelos guardados en caché (${flights.length} vuelos)');
      return true;
    } catch (e) {
      print('ERROR: No se pudieron guardar los vuelos en caché: $e');
      return false;
    }
  }

  /// Recupera los vuelos almacenados en la caché
  static Future<List<Map<String, dynamic>>?> getFlights() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonData = prefs.getString(_flightsKey);

      if (jsonData == null) {
        print('LOG: No hay vuelos en caché');
        return null;
      }

      // Decodificar el JSON y convertir los valores de color de vuelta a objetos Color
      final List<dynamic> decoded = jsonDecode(jsonData);
      final flights = decoded.map((item) {
        final Map<String, dynamic> flight = Map<String, dynamic>.from(item);
        if (flight['color'] is int) {
          flight['color'] = Color(flight['color']);
        }
        return flight;
      }).toList();

      print('LOG: Recuperados ${flights.length} vuelos de la caché');
      return flights.cast<Map<String, dynamic>>();
    } catch (e) {
      print('ERROR: No se pudieron recuperar los vuelos de la caché: $e');
      return null;
    }
  }

  /// Guarda los filtros aplicados
  static Future<bool> saveFilters({
    required DateTime startDate,
    required TimeOfDay startTime,
    required DateTime endDate,
    required TimeOfDay endTime,
    required String searchQuery,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final filters = {
        'startDate': startDate.toIso8601String(),
        'startTime': '${startTime.hour}:${startTime.minute}',
        'endDate': endDate.toIso8601String(),
        'endTime': '${endTime.hour}:${endTime.minute}',
        'searchQuery': searchQuery,
      };

      await prefs.setString(_filtersKey, jsonEncode(filters));
      print('LOG: Filtros guardados en caché');
      return true;
    } catch (e) {
      print('ERROR: No se pudieron guardar los filtros en caché: $e');
      return false;
    }
  }

  /// Recupera los filtros almacenados
  static Future<Map<String, dynamic>?> getFilters() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonData = prefs.getString(_filtersKey);

      if (jsonData == null) {
        print('LOG: No hay filtros en caché');
        return null;
      }

      final Map<String, dynamic> filters = jsonDecode(jsonData);

      // Convertir de nuevo a los tipos correctos
      return {
        'startDate': DateTime.parse(filters['startDate']),
        'startTime': TimeOfDay(
          hour: int.parse(filters['startTime'].split(':')[0]),
          minute: int.parse(filters['startTime'].split(':')[1]),
        ),
        'endDate': DateTime.parse(filters['endDate']),
        'endTime': TimeOfDay(
          hour: int.parse(filters['endTime'].split(':')[0]),
          minute: int.parse(filters['endTime'].split(':')[1]),
        ),
        'searchQuery': filters['searchQuery'],
      };
    } catch (e) {
      print('ERROR: No se pudieron recuperar los filtros de la caché: $e');
      return null;
    }
  }

  /// Obtiene la última fecha de actualización de los datos
  static Future<DateTime?> getLastUpdated() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getString(_lastUpdatedKey);

      if (timestamp == null) {
        return null;
      }

      return DateTime.parse(timestamp);
    } catch (e) {
      print('ERROR: No se pudo obtener la fecha de última actualización: $e');
      return null;
    }
  }

  /// Limpia toda la caché (usar al cerrar sesión)
  static Future<bool> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_flightsKey);
      await prefs.remove(_filtersKey);
      await prefs.remove(_lastUpdatedKey);
      print('LOG: Caché limpiada correctamente');
      return true;
    } catch (e) {
      print('ERROR: No se pudo limpiar la caché: $e');
      return false;
    }
  }
}
