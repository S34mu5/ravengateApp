import '../utils/flight_filter_util.dart';
import '../utils/logger.dart';

/// Utilitario para ordenar los vuelos de manera consistente en toda la aplicación
class FlightSortUtil {
  /// Ordena los vuelos por tiempo de estado (status_time) si está disponible,
  /// o por tiempo programado (schedule_time) como respaldo.
  ///
  /// Ordena de manera ascendente, con los vuelos más próximos primero.
  static List<Map<String, dynamic>> sortFlightsByTime(
    List<Map<String, dynamic>> flights,
  ) {
    // Crear una copia para no modificar la lista original
    final List<Map<String, dynamic>> sortedFlights = List.from(flights);

    try {
      sortedFlights.sort((a, b) {
        try {
          // Primero intentar ordenar por status_time si está disponible
          final aStatusTime = a['status_time']?.toString() ?? '';
          final bStatusTime = b['status_time']?.toString() ?? '';

          // Si ambos vuelos tienen status_time, usar eso para comparar
          if (aStatusTime.isNotEmpty && bStatusTime.isNotEmpty) {
            final DateTime aTime = DateTime.parse(aStatusTime);
            final DateTime bTime = DateTime.parse(bStatusTime);
            return aTime.compareTo(bTime);
          }

          // Si alguno no tiene status_time, usar schedule_time
          final aScheduleTime = a['schedule_time'].toString();
          final bScheduleTime = b['schedule_time'].toString();

          final DateTime aTime = DateTime.parse(aScheduleTime);
          final DateTime bTime = DateTime.parse(bScheduleTime);

          return aTime.compareTo(bTime);
        } catch (e) {
          AppLogger.error('Error sorting individual flights', e);
          return 0; // En caso de error, mantener el orden original
        }
      });

      return sortedFlights;
    } catch (e) {
      AppLogger.error('Error sorting flights', e);
      return flights; // Return original list if sorting fails
    }
  }

  /// Extrae un DateTime completo de un timestamp de vuelo, considerando fecha y hora
  static DateTime _extractFullDateTimeFromSchedule(
      String timeString, Map<String, dynamic> flight) {
    try {
      // Verificar si el formato es ISO completo (2023-01-01T12:30:00Z)
      if (timeString.contains('T')) {
        final dateTime = DateTime.parse(timeString);
        // Si es fecha UTC, convertir a local
        if (timeString.endsWith('Z')) {
          return dateTime.toLocal();
        }
        return dateTime;
      }

      // Verificar si hay un campo de fecha separado (flight_date, date, etc.)
      String? dateString = flight['flight_date']?.toString() ??
          flight['date']?.toString() ??
          flight['departure_date']?.toString();

      // Si tenemos solo la hora (formato HH:MM) y una fecha separada
      if (timeString.contains(':') &&
          dateString != null &&
          dateString.isNotEmpty) {
        // Extraer hora y minuto
        final timeParts = timeString.split(':');
        final hour = int.parse(timeParts[0]);
        final minute = int.parse(timeParts[1]);

        // Parseamos la fecha
        DateTime flightDate;
        if (dateString.contains('-') || dateString.contains('/')) {
          // Formato YYYY-MM-DD o YYYY/MM/DD
          flightDate = DateTime.parse(dateString.replaceAll('/', '-'));
        } else {
          // Si no hay formato reconocible, usamos la fecha actual
          flightDate = DateTime.now();
        }

        return DateTime(
          flightDate.year,
          flightDate.month,
          flightDate.day,
          hour,
          minute,
        );
      }

      // Si solo tenemos hora (HH:MM) sin fecha
      if (timeString.contains(':')) {
        final parts = timeString.split(':');
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);

        final now = DateTime.now();
        DateTime flightDateTime = DateTime(
          now.year,
          now.month,
          now.day,
          hour,
          minute,
        );

        // Ajuste para vuelos de días futuros o pasados
        // Si el vuelo ya pasó hoy, podría ser de mañana
        if (hour < 12 && now.hour > 12 && flightDateTime.isBefore(now)) {
          flightDateTime = flightDateTime.add(const Duration(days: 1));
        }

        return flightDateTime;
      }

      // Fallback: si no podemos extraer correctamente, convertimos el resultado de FlightFilterUtil a DateTime
      final now = DateTime.now();
      // Usar el método existente para extraer la hora:minutos
      final timeStringOnly =
          FlightFilterUtil.extractTimeFromSchedule(timeString);
      // Convertir el string de tiempo en componentes de hora y minuto
      final timeComponents = timeStringOnly.split(':');
      int hour = 0, minute = 0;
      if (timeComponents.length >= 2) {
        hour = int.tryParse(timeComponents[0]) ?? 0;
        minute = int.tryParse(timeComponents[1]) ?? 0;
      }
      // Crear un DateTime con la fecha actual y la hora extraída
      return DateTime(now.year, now.month, now.day, hour, minute);
    } catch (e) {
      AppLogger.error('Error extracting full datetime', e);
      return DateTime.now(); // Return current time if parsing fails
    }
  }

  /// Encuentra el índice del vuelo actual en la lista ordenada
  static int _findCurrentFlightIndex(
    List<Map<String, dynamic>> flights,
    String currentDocId,
    String flightsSource,
  ) {
    for (int i = 0; i < flights.length; i++) {
      final flight = flights[i];
      final String id = flightsSource == 'my'
          ? (flight['flight_ref'] ?? flight['id'] ?? '')
          : flight['id'];

      if (id == currentDocId) {
        return i;
      }
    }
    return -1; // No se encontró el vuelo
  }

  /// Encuentra el índice del vuelo siguiente cronológicamente
  /// basándose en status_time como prioridad
  static int findNextFlightIndex(
    List<Map<String, dynamic>> flights,
    String currentDocId,
    String flightsSource,
  ) {
    final currentIndex =
        _findCurrentFlightIndex(flights, currentDocId, flightsSource);

    if (currentIndex == -1 || currentIndex >= flights.length - 1) {
      return -1; // No hay siguiente vuelo
    }

    return currentIndex + 1; // El siguiente vuelo siempre es el índice + 1
  }

  /// Encuentra el índice del vuelo anterior cronológicamente
  /// basándose en status_time como prioridad
  static int findPreviousFlightIndex(
    List<Map<String, dynamic>> flights,
    String currentDocId,
    String flightsSource,
  ) {
    final currentIndex =
        _findCurrentFlightIndex(flights, currentDocId, flightsSource);

    if (currentIndex <= 0) {
      return -1; // No hay vuelo anterior
    }

    return currentIndex - 1; // El vuelo anterior siempre es el índice - 1
  }
}
