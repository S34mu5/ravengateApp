import '../utils/flight_filter_util.dart';

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

    sortedFlights.sort((a, b) {
      try {
        // Primero intentar ordenar por status_time si está disponible
        final aStatusTime = a['status_time']?.toString() ?? '';
        final bStatusTime = b['status_time']?.toString() ?? '';

        // Si ambos vuelos tienen status_time, usar eso para comparar
        if (aStatusTime.isNotEmpty && bStatusTime.isNotEmpty) {
          final aTime = FlightFilterUtil.extractTimeFromSchedule(aStatusTime);
          final bTime = FlightFilterUtil.extractTimeFromSchedule(bStatusTime);
          return aTime.compareTo(bTime);
        }

        // Si alguno no tiene status_time, usar schedule_time
        final aScheduleTime = a['schedule_time'].toString();
        final bScheduleTime = b['schedule_time'].toString();

        final aTime = FlightFilterUtil.extractTimeFromSchedule(aScheduleTime);
        final bTime = FlightFilterUtil.extractTimeFromSchedule(bScheduleTime);

        return aTime.compareTo(bTime);
      } catch (e) {
        print('LOG: Error sorting flights: $e');
        return 0; // En caso de error, mantener el orden original
      }
    });

    return sortedFlights;
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
