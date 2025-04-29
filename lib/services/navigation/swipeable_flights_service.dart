import 'package:flutter/material.dart';
import '../../screens/home/flight_details/flight_details_screen.dart';

/// Servicio que permite la navegación entre vuelos mediante gestos de swipe
class SwipeableFlightsService {
  /// Navega al siguiente o anterior vuelo basado en la lista proporcionada
  ///
  /// [context] - Contexto actual
  /// [currentFlightDocId] - ID del documento del vuelo actual
  /// [flightsList] - Lista completa de vuelos disponibles
  /// [isNext] - true para ir al siguiente vuelo (abajo en la lista), false para ir al anterior (arriba en la lista)
  /// [flightsSource] - Origen de los datos de los vuelos
  static void navigateToAdjacentFlight({
    required BuildContext context,
    required String currentFlightDocId,
    required List<Map<String, dynamic>> flightsList,
    required bool isNext,
    String flightsSource = 'all',
  }) {
    // Validar que la lista no esté vacía
    if (flightsList.isEmpty) {
      print('LOG: No se puede navegar - lista de vuelos vacía');
      return;
    }

    // Encontrar el índice del vuelo actual en la lista
    final currentIndex =
        flightsList.indexWhere((flight) => flight['id'] == currentFlightDocId);

    // Si no se encuentra el vuelo, intentar buscar por flight_ref (usado en MyDepartures)
    int index = currentIndex;
    if (index == -1) {
      index = flightsList.indexWhere((flight) =>
          (flight['flight_ref'] != null &&
              flight['flight_ref'] == currentFlightDocId) ||
          (flight['doc_id'] != null && flight['doc_id'] == currentFlightDocId));
    }

    // Si aún no se encuentra el vuelo, no hacer nada
    if (index == -1) {
      print(
          'LOG: No se puede navegar - vuelo actual no encontrado en la lista');
      return;
    }

    print('LOG: Índice actual en la lista: $index de ${flightsList.length}');

    // Calcular el índice del vuelo al que se desea navegar
    int targetIndex;
    if (isNext) {
      // Moverse hacia el siguiente vuelo (abajo en la lista)
      targetIndex = (index + 1) %
          flightsList.length; // Vuelve al inicio si llega al final
      print('LOG: Navegando al siguiente vuelo (índice $targetIndex)');
    } else {
      // Moverse hacia el vuelo anterior (arriba en la lista)
      targetIndex = (index - 1 + flightsList.length) %
          flightsList.length; // Vuelve al final si llega al inicio
      print('LOG: Navegando al vuelo anterior (índice $targetIndex)');
    }

    // Obtener el vuelo objetivo
    final targetFlight = flightsList[targetIndex];

    // Identificar el ID del documento según el origen de los datos
    final String docId = flightsSource == 'my'
        ? (targetFlight['flight_ref'] ?? targetFlight['id'] ?? '')
        : targetFlight['id'];

    print('LOG: Navegando al vuelo ${targetFlight['flight_id']} (ID: $docId)');

    // Navegar a la pantalla de detalles del vuelo objetivo
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => FlightDetailsScreen(
          flightId: targetFlight['flight_id'],
          documentId: docId,
          flightsList: flightsList, // Mantener la lista de vuelos
          flightsSource: flightsSource, // Preservar el origen
        ),
      ),
    );
  }
}
