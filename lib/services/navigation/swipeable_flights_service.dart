import 'package:flutter/material.dart';
import '../../screens/home/flight_details/flight_details_screen.dart';

/// Servicio que permite la navegación entre vuelos mediante gestos de swipe
class SwipeableFlightsService {
  /// Navega al siguiente o anterior vuelo basado en la lista proporcionada
  ///
  /// [context] - Contexto actual
  /// [currentFlightDocId] - ID del documento del vuelo actual
  /// [flightsList] - Lista completa de vuelos disponibles
  /// [isNext] - true para navegar al siguiente vuelo (swipe derecha a izquierda),
  ///            false para navegar al vuelo anterior (swipe izquierda a derecha)
  /// [flightsSource] - Origen de los datos de los vuelos ('all' o 'my')
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

    // La dirección de navegación depende de la fuente (all_departures o my_departures)
    if (flightsSource == 'my') {
      // Para my_departures invertimos la lógica
      if (isNext) {
        // isNext=true (swipe de derecha a izquierda) -> vuelo anterior
        targetIndex = index - 1;

        // Verificar si estamos en el primer elemento
        if (targetIndex < 0) {
          print(
              'LOG: Ya estás en el primer vuelo, no se puede navegar más arriba');
          return;
        }

        print(
            'LOG: Navegando al vuelo anterior (índice $targetIndex) en my_departures');
      } else {
        // isNext=false (swipe de izquierda a derecha) -> siguiente vuelo
        targetIndex = index + 1;

        // Verificar si estamos en el último elemento
        if (targetIndex >= flightsList.length) {
          print(
              'LOG: Ya estás en el último vuelo, no se puede navegar más abajo');
          return;
        }

        print(
            'LOG: Navegando al siguiente vuelo (índice $targetIndex) en my_departures');
      }
    } else {
      // Para all_departures mantenemos la lógica original
      if (isNext) {
        // isNext=true (swipe de derecha a izquierda) -> siguiente vuelo
        targetIndex = index + 1;

        // Verificar si estamos en el último elemento
        if (targetIndex >= flightsList.length) {
          print(
              'LOG: Ya estás en el último vuelo, no se puede navegar más abajo');
          return;
        }

        print(
            'LOG: Navegando al siguiente vuelo (índice $targetIndex) en all_departures');
      } else {
        // isNext=false (swipe de izquierda a derecha) -> vuelo anterior
        targetIndex = index - 1;

        // Verificar si estamos en el primer elemento
        if (targetIndex < 0) {
          print(
              'LOG: Ya estás en el primer vuelo, no se puede navegar más arriba');
          return;
        }

        print(
            'LOG: Navegando al vuelo anterior (índice $targetIndex) en all_departures');
      }
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
