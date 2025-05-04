import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

/// Servicio para gestionar la persistencia de datos entre sesiones de la aplicación
class CacheService {
  static const String _flightsKey = 'cached_flights';
  static const String _filtersKey = 'cached_filters';
  static const String _lastUpdatedKey = 'last_updated';
  static const String _norwegianEquivalenceKey =
      'norwegian_equivalence_enabled';
  static const String _delayNotificationsKey = 'delay_notifications_enabled';
  static const String _departureNotificationsKey =
      'departure_notifications_enabled';
  static const String _gateChangeNotificationsKey =
      'gate_change_notifications_enabled';

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

      print('LOG: Flights saved in cache (${flights.length} flights)');
      return true;
    } catch (e) {
      print('ERROR: Could not save flights in cache: $e');
      return false;
    }
  }

  /// Recupera los vuelos almacenados en la caché
  static Future<List<Map<String, dynamic>>?> getFlights() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonData = prefs.getString(_flightsKey);

      if (jsonData == null) {
        print('LOG: No flights in cache');
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

      print('LOG: Retrieved ${flights.length} flights from cache');
      return flights.cast<Map<String, dynamic>>();
    } catch (e) {
      print('ERROR: Could not retrieve flights from cache: $e');
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
      print('LOG: Filters saved in cache');
      return true;
    } catch (e) {
      print('ERROR: Could not save filters in cache: $e');
      return false;
    }
  }

  /// Recupera los filtros almacenados
  static Future<Map<String, dynamic>?> getFilters() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonData = prefs.getString(_filtersKey);

      if (jsonData == null) {
        print('LOG: No filters in cache');
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
      print('ERROR: Could not retrieve filters from cache: $e');
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
      print('ERROR: Could not get last updated date: $e');
      return null;
    }
  }

  /// Guarda la preferencia para la equivalencia de códigos DY/D8 de Norwegian
  static Future<bool> saveNorwegianEquivalencePreference(bool isEnabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_norwegianEquivalenceKey, isEnabled);
      print('LOG: Norwegian equivalence preference saved: $isEnabled');
      return true;
    } catch (e) {
      print('ERROR: Could not save Norwegian preference: $e');
      return false;
    }
  }

  /// Recupera la preferencia para la equivalencia de códigos DY/D8 de Norwegian
  static Future<bool> getNorwegianEquivalencePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Por defecto esta característica está activada (true)
      final isEnabled = prefs.getBool(_norwegianEquivalenceKey) ?? true;
      return isEnabled;
    } catch (e) {
      print('ERROR: Could not retrieve Norwegian preference: $e');
      return true; // Por defecto activado
    }
  }

  /// Guarda la preferencia para las notificaciones de retrasos de vuelos
  static Future<bool> saveDelayNotificationsPreference(bool isEnabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_delayNotificationsKey, isEnabled);
      print('LOG: Delay notifications preference saved: $isEnabled');
      return true;
    } catch (e) {
      print('ERROR: Could not save delay notifications preference: $e');
      return false;
    }
  }

  /// Recupera la preferencia para las notificaciones de retrasos de vuelos
  static Future<bool> getDelayNotificationsPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Por defecto esta característica está activada (true)
      final isEnabled = prefs.getBool(_delayNotificationsKey) ?? true;
      return isEnabled;
    } catch (e) {
      print('ERROR: Could not retrieve delay notifications preference: $e');
      return true; // Por defecto activado
    }
  }

  /// Guarda la preferencia para las notificaciones de despegue de vuelos
  static Future<bool> saveDepartureNotificationsPreference(
      bool isEnabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_departureNotificationsKey, isEnabled);
      print('LOG: Departure notifications preference saved: $isEnabled');
      return true;
    } catch (e) {
      print('ERROR: Could not save departure notifications preference: $e');
      return false;
    }
  }

  /// Recupera la preferencia para las notificaciones de despegue de vuelos
  static Future<bool> getDepartureNotificationsPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Por defecto esta característica está activada (true)
      final isEnabled = prefs.getBool(_departureNotificationsKey) ?? true;
      return isEnabled;
    } catch (e) {
      print('ERROR: Could not retrieve departure notifications preference: $e');
      return true; // Por defecto activado
    }
  }

  /// Guarda la preferencia para las notificaciones de cambio de puerta
  static Future<bool> saveGateChangeNotificationsPreference(
      bool isEnabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_gateChangeNotificationsKey, isEnabled);
      print('LOG: Gate change notifications preference saved: $isEnabled');
      return true;
    } catch (e) {
      print('ERROR: Could not save gate change notifications preference: $e');
      return false;
    }
  }

  /// Recupera la preferencia para las notificaciones de cambio de puerta
  static Future<bool> getGateChangeNotificationsPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Por defecto esta característica está activada (true)
      final isEnabled = prefs.getBool(_gateChangeNotificationsKey) ?? true;
      return isEnabled;
    } catch (e) {
      print(
          'ERROR: Could not retrieve gate change notifications preference: $e');
      return true; // Por defecto activado
    }
  }

  /// Limpia toda la caché (usar al cerrar sesión)
  static Future<bool> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_flightsKey);
      await prefs.remove(_filtersKey);
      await prefs.remove(_lastUpdatedKey);
      // No eliminamos _norwegianEquivalenceKey ni _delayNotificationsKey ni _departureNotificationsKey ni _gateChangeNotificationsKey ya que son preferencias de usuario
      print('LOG: Cache cleared successfully');
      return true;
    } catch (e) {
      print('ERROR: Could not clear cache: $e');
      return false;
    }
  }
}
