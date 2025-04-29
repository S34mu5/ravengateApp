import 'package:flutter/material.dart';
import 'swipeable_flights_service.dart';

/// Mixin para añadir la funcionalidad de swipe entre vuelos en la pantalla de detalles
mixin SwipeableFlightDetails<T extends StatefulWidget> on State<T> {
  /// Lista de vuelos para navegar entre ellos
  List<Map<String, dynamic>> get flightsList;

  /// ID del documento del vuelo actual
  String get currentFlightDocId;

  /// Origen de la lista de vuelos (para saber a qué pantalla volver)
  String get flightsSource;

  /// Detecta gestos de swipe y navega al vuelo correspondiente
  Widget buildSwipeableContent(Widget child) {
    // Ahora la detección de swipe se maneja internamente en FlightDetailsUI
    // Simplemente devolvemos el widget hijo
    return child;
  }
}
