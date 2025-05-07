import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../services/location/location_service.dart';
import '../../../utils/flight_sort_util.dart';
import '../flight_details/flight_details_screen.dart';
import '../flight_details/oz_flight_details_screen.dart';

/// Clase utilitaria para la pantalla de todas las salidas (All Departures)
class AllDeparturesUtils {
  /// Formatea la fecha y hora de la última actualización
  static String formatLastUpdated(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inSeconds < 60) {
      return 'hace unos segundos';
    } else if (difference.inMinutes < 60) {
      final minutes = difference.inMinutes;
      return 'hace $minutes ${minutes == 1 ? 'minuto' : 'minutos'}';
    } else if (difference.inHours < 24) {
      final hours = difference.inHours;
      return 'hace $hours ${hours == 1 ? 'hora' : 'horas'}';
    } else {
      final formatter = DateFormat('dd/MM HH:mm');
      return formatter.format(timestamp);
    }
  }

  /// Ordena vuelos por hora de salida
  static List<Map<String, dynamic>> sortFlightsByDepartureTime(
      List<Map<String, dynamic>> flights) {
    return FlightSortUtil.sortFlightsByTime(flights);
  }

  /// Navega a la pantalla de detalles del vuelo seleccionado
  static Future<void> navigateToFlightDetails(
      BuildContext context,
      Map<String, dynamic> flight,
      List<Map<String, dynamic>> flightsList) async {
    // Añadir logs para depuración
    print('LOG: Navegando a detalles de vuelo desde All Departures');
    print(
        'LOG: Vuelo seleccionado: ${flight['flight_id']} (ID: ${flight['id']})');
    print('LOG: Pasando lista de ${flightsList.length} vuelos');

    // Verificar la ubicación actual
    final bool isOversize = await LocationService.isOversizeLocation();
    print('LOG: Ubicación actual: ${isOversize ? "Oversize" : "Bins"}');

    if (isOversize) {
      // Si la ubicación es Oversize, mostrar la pantalla de detalles de Oversize
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OzFlightDetailsScreen(
            flightId: flight['flight_id'],
            documentId: flight['id'],
            flightsList: flightsList, // Pasar toda la lista de vuelos
            flightsSource: 'all', // Indicar que viene de "todos los vuelos"
          ),
        ),
      );
    } else {
      // Si la ubicación es Bins, mostrar la pantalla de detalles normal
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FlightDetailsScreen(
            flightId: flight['flight_id'],
            documentId: flight['id'],
            flightsList: flightsList, // Pasar toda la lista de vuelos
            flightsSource: 'all', // Indicar que viene de "todos los vuelos"
          ),
        ),
      );
    }
  }

  /// Encuentra el primer vuelo activo (no departed y no cancelado) para desplazarse
  static int findFirstActiveFlightIndex(List<Map<String, dynamic>> flights) {
    for (int i = 0; i < flights.length; i++) {
      // No desplazarse a vuelos departed (D) ni cancelados (C)
      final statusCode = flights[i]['status_code'];
      if (statusCode != 'D' && statusCode != 'C') {
        return i;
      }
    }
    return -1; // No se encontró ningún vuelo activo
  }
}
