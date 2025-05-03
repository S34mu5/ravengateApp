import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'flight_search_helper.dart';
import '../services/cache/cache_service.dart';

/// Utilidad para filtrar y buscar vuelos, eliminando duplicación de código
class FlightFilterUtil {
  /// Formatters for date and time que se usarán en múltiples pantallas
  static final DateFormat dateFormatter = DateFormat('yyyy-MM-dd');
  static final DateFormat timeFormatter = DateFormat('HH:mm');
  static final DateFormat displayFormatter = DateFormat('dd MMM HH:mm');

  /// Filtra vuelos según criterios de búsqueda
  static List<Map<String, dynamic>> filterFlights({
    required List<Map<String, dynamic>> flights,
    required String searchQuery,
    required bool norwegianEquivalenceEnabled,
  }) {
    return FlightSearchHelper.filterFlights(
      flights: flights,
      searchQuery: searchQuery,
      norwegianEquivalenceEnabled: norwegianEquivalenceEnabled,
    );
  }

  /// Configura un controlador de texto para buscar vuelos
  static void setupSearchController({
    required TextEditingController controller,
    required Function(String) onSearch,
  }) {
    controller.addListener(() {
      onSearch(controller.text);
    });
  }

  /// Ayuda a compartir el código para cargar preferencia Norwegian
  static Future<bool> loadNorwegianPreference() async {
    return await CacheService.getNorwegianEquivalencePreference();
  }

  /// Extrae la hora del formato de horario (común en ambas UIs)
  static String extractTimeFromSchedule(String scheduleTime) {
    try {
      // Si es formato ISO completo
      if (scheduleTime.contains('T')) {
        final dateTime = DateTime.parse(scheduleTime);
        return timeFormatter.format(dateTime);
      }

      // Si es formato simple HH:MM
      final parts = scheduleTime.split(':');
      if (parts.length >= 2) {
        return '${parts[0]}:${parts[1]}';
      }

      return scheduleTime;
    } catch (e) {
      print('LOG: Error extracting time: $e');
      return scheduleTime;
    }
  }

  /// Extrae la fecha del formato de horario (común en ambas UIs)
  static String extractDateFromSchedule(String scheduleTime) {
    try {
      // Solo para formato ISO completo
      if (scheduleTime.contains('T')) {
        final dateTime = DateTime.parse(scheduleTime);
        // Formato día/mes con cero a la izquierda en el mes (ej: 02/05)
        return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}';
      }

      // Para formato simple, devolver fecha actual con el mismo formato
      final now = DateTime.now();
      return '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}';
    } catch (e) {
      print('LOG: Error extracting date: $e');
      return '';
    }
  }

  /// Compara dos tiempos en formato HH:MM (común en ambas UIs)
  static bool isLaterTime(String time1, String time2) {
    try {
      // Convertir al formato actual de tiempo
      final parts1 = time1.split(':');
      final parts2 = time2.split(':');

      if (parts1.length >= 2 && parts2.length >= 2) {
        final hour1 = int.parse(parts1[0]);
        final minute1 = int.parse(parts1[1]);
        final hour2 = int.parse(parts2[0]);
        final minute2 = int.parse(parts2[1]);

        // Comparar horas y minutos
        if (hour1 > hour2) {
          return true;
        } else if (hour1 == hour2) {
          return minute1 > minute2;
        }
      }
      return false;
    } catch (e) {
      print('LOG: Error comparando tiempos: $e');
      return false;
    }
  }

  /// Filtrar vuelos por rango de fechas
  static List<Map<String, dynamic>> filterFlightsByDateRange({
    required List<Map<String, dynamic>> flights,
    required DateTime startDateTime,
    required DateTime endDateTime,
  }) {
    return FlightSearchHelper.filterFlightsByDateRange(
      flights: flights,
      startDateTime: startDateTime,
      endDateTime: endDateTime,
    );
  }

  /// Construye un widget para mostrar equivalencia de Norwegian si es aplicable
  static Widget? buildNorwegianEquivalenceIndicator({
    required String searchQuery,
    required bool norwegianEquivalenceEnabled,
  }) {
    return FlightSearchHelper.buildNorwegianEquivalenceIndicator(
      searchQuery: searchQuery,
      norwegianEquivalenceEnabled: norwegianEquivalenceEnabled,
    );
  }

  /// Versión compacta del indicador de Norwegian para usar en espacios reducidos
  static Widget buildCompactNorwegianIndicator({
    required String searchQuery,
    Color backgroundColor = const Color(0xFFE60A0A), // Color de Norwegian
  }) {
    // Determinar qué texto mostrar
    final String equivalentCode =
        searchQuery.toLowerCase().contains('dy') ? 'D8' : 'DY';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      margin: const EdgeInsets.only(right: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.sync_alt,
            color: Colors.white,
            size: 12,
          ),
          const SizedBox(width: 2),
          Text(
            equivalentCode,
            style: const TextStyle(
              fontSize: 10,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
