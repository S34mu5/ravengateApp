import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../services/navigation/nested_navigation_service.dart';
import '../../../utils/flight_sort_util.dart';
import '../../../utils/logger.dart';

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

  /// Navega a la pantalla de detalles del vuelo seleccionado usando navegación anidada
  static void navigateToFlightDetails(BuildContext context,
      Map<String, dynamic> flight, List<Map<String, dynamic>> flightsList) {
    // Añadir logs para depuración usando el sistema centralizado
    AppLogger.debug(
        'AllDeparturesUtils - Navegando a detalles de vuelo usando navegación anidada');
    AppLogger.debug(
        'AllDeparturesUtils - Vuelo seleccionado: ${flight['flight_id']} (ID: ${flight['id']})');
    AppLogger.debug(
        'AllDeparturesUtils - Pasando lista de ${flightsList.length} vuelos');

    // Usar el servicio de navegación anidada
    final navigationService = NestedNavigationService();
    navigationService.navigateToFlightDetails(
      flight: flight,
      flightsList: flightsList,
      flightsSource: 'all',
      currentTabIndex: 0, // All Departures es el tab 0
    );
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
