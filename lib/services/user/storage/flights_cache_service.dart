import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import '../../../utils/logger.dart';
import '../models/archived_flight_date.dart';

/// Servicio para manejar el sistema de caché de vuelos
class FlightsCacheService {
  // Claves para el sistema de caché
  static const String _cachedUserFlightsKey = 'cached_user_flights';
  static const String _userFlightsLastUpdatedKey = 'user_flights_last_updated';
  static const String _cachedUserArchivedDatesKey =
      'cached_user_archived_dates';
  static const String _userArchivedDatesLastUpdatedKey =
      'user_archived_dates_last_updated';
  static const String _cachedUserArchivedFlightsKey =
      'cached_user_archived_flights';
  static const String _userArchivedFlightsLastUpdatedKey =
      'user_archived_flights_last_updated';

  /// Guardar vuelos del usuario en caché
  static Future<bool> saveFlightsToCache(
      List<Map<String, dynamic>> flights) async {
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

      return true;
    } catch (e) {
      AppLogger.error('Error al guardar vuelos del usuario en caché', e);
      return false;
    }
  }

  /// Cargar vuelos del usuario desde la caché
  static Future<List<Map<String, dynamic>>> loadFlightsFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Verificar si tenemos datos en caché
      final jsonData = prefs.getString(_cachedUserFlightsKey);
      if (jsonData == null) {
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

      return filteredFlights.cast<Map<String, dynamic>>();
    } catch (e) {
      AppLogger.error('Error al cargar vuelos del usuario desde caché', e);
      return [];
    }
  }

  /// Invalidar la caché de vuelos (llamado cuando los datos cambian)
  static Future<void> invalidateFlightsCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cachedUserFlightsKey);
      await prefs.remove(_userFlightsLastUpdatedKey);
    } catch (e) {
      AppLogger.error('Error al invalidar caché de vuelos del usuario', e);
    }
  }

  /// Guardar fechas de vuelos archivados en caché
  static Future<bool> saveArchivedDatesToCache(
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

      return true;
    } catch (e) {
      AppLogger.error(
          'Error al guardar fechas de vuelos archivados en caché', e);
      return false;
    }
  }

  /// Cargar fechas de vuelos archivados desde la caché
  static Future<List<ArchivedFlightDate>> loadArchivedDatesFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Verificar si tenemos datos en caché
      final jsonData = prefs.getString(_cachedUserArchivedDatesKey);
      if (jsonData == null) {
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

      return dates.cast<ArchivedFlightDate>();
    } catch (e) {
      AppLogger.error(
          'Error al cargar fechas de vuelos archivados desde caché', e);
      return [];
    }
  }

  /// Guardar vuelos archivados por fecha en caché
  static Future<bool> saveArchivedFlightsByDateToCache(
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

      return true;
    } catch (e) {
      AppLogger.error(
          'Error al guardar vuelos archivados por fecha en caché', e);
      return false;
    }
  }

  /// Cargar vuelos archivados por fecha desde la caché
  static Future<List<Map<String, dynamic>>> loadArchivedFlightsByDateFromCache(
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

      return flights.cast<Map<String, dynamic>>();
    } catch (e) {
      AppLogger.error('Error al cargar vuelos archivados desde caché', e);
      return [];
    }
  }

  /// Invalidar la caché de vuelos archivados
  static Future<void> invalidateArchivedCache() async {
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
    } catch (e) {
      AppLogger.error('Error al invalidar caché de vuelos archivados', e);
    }
  }
}
