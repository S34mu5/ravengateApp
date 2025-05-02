import 'package:flutter/material.dart';
import 'airline_helper.dart';

/// Clase de utilidad para buscar y filtrar vuelos en la aplicación
class FlightSearchHelper {
  /// Filtra una lista de vuelos según un texto de búsqueda
  /// Permite buscar por ID de vuelo, aerolínea, aeropuerto y puerta
  /// Incluye soporte para equivalencia Norwegian (DY/D8)
  static List<Map<String, dynamic>> filterFlights({
    required List<Map<String, dynamic>> flights,
    required String searchQuery,
    required bool norwegianEquivalenceEnabled,
  }) {
    if (searchQuery.isEmpty) {
      // Si no hay búsqueda, devolver todos los vuelos
      return List.from(flights);
    }

    // Convertir a minúsculas para búsqueda no sensible a mayúsculas
    final String lowerQuery = searchQuery.toLowerCase();

    // Filtrar los vuelos según el criterio de búsqueda
    return flights.where((flight) {
      final String flightId =
          (flight['flight_id'] ?? '').toString().toLowerCase();
      final String airport = (flight['airport'] ?? '').toString().toLowerCase();
      final String airline = (flight['airline'] ?? '').toString().toLowerCase();
      final String gate = (flight['gate'] ?? '').toString().toLowerCase();

      // Verificar si la búsqueda es para DY o D8 (equivalentes) y si la preferencia está activada
      bool isMatchingNorwegianAirline = false;
      if (norwegianEquivalenceEnabled &&
          (lowerQuery == 'dy' || lowerQuery == 'd8')) {
        isMatchingNorwegianAirline = flightId.contains('dy') ||
            flightId.contains('d8') ||
            airline == 'dy' ||
            airline == 'd8';
      }

      // Devolver true si algún campo contiene la búsqueda o es un vuelo de Norwegian equivalente
      return flightId.contains(lowerQuery) ||
          airport.contains(lowerQuery) ||
          airline.contains(lowerQuery) ||
          gate.contains(lowerQuery) ||
          isMatchingNorwegianAirline;
    }).toList();
  }

  /// Filtrar vuelos por rango de fechas
  static List<Map<String, dynamic>> filterFlightsByDateRange({
    required List<Map<String, dynamic>> flights,
    required DateTime startDateTime,
    required DateTime endDateTime,
  }) {
    return flights.where((flight) {
      // Intentar analizar la fecha del vuelo
      try {
        final scheduleTimeStr = flight['schedule_time'].toString();
        DateTime flightDateTime;

        // Manejar formato ISO
        if (scheduleTimeStr.contains('T')) {
          flightDateTime = DateTime.parse(scheduleTimeStr);

          // Si es UTC (termina con Z), convertir a hora local
          if (scheduleTimeStr.endsWith('Z')) {
            flightDateTime = flightDateTime.toLocal();
          }
        } else {
          // Formato simple HH:MM, asumir fecha actual
          final parts = scheduleTimeStr.split(':');
          if (parts.length == 2) {
            final hour = int.parse(parts[0]);
            final minute = int.parse(parts[1]);
            flightDateTime = DateTime(
              startDateTime.year,
              startDateTime.month,
              startDateTime.day,
              hour,
              minute,
            );
          } else {
            // Formato no reconocido
            return false;
          }
        }

        // Devolver true si está dentro del rango
        return flightDateTime.isAfter(startDateTime) &&
            flightDateTime.isBefore(endDateTime);
      } catch (e) {
        print('LOG: Error analizando fecha para filtrado: $e');
        return false;
      }
    }).toList();
  }

  /// Construye un widget para mostrar equivalencia de Norwegian si es aplicable
  static Widget? buildNorwegianEquivalenceIndicator({
    required String searchQuery,
    required bool norwegianEquivalenceEnabled,
  }) {
    if (!norwegianEquivalenceEnabled) return null;

    final String query = searchQuery.toLowerCase();

    if (query.contains('dy')) {
      return _buildEquivalenceContainer('Showing also D8');
    } else if (query.contains('d8')) {
      return _buildEquivalenceContainer('Showing also DY');
    }

    return null;
  }

  /// Construye el contenedor para el indicador de equivalencia
  static Widget _buildEquivalenceContainer(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        color: AirlineHelper.getAirlineColor(
            'DY'), // Usar el color de Norwegian de AirlineHelper
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
