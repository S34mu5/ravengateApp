import 'package:flutter/material.dart';
import '../../utils/logger.dart';

/// Mixin para añadir la funcionalidad de swipe entre vuelos en la pantalla de detalles
mixin SwipeableFlightDetails<T extends StatefulWidget> on State<T> {
  /// Lista de vuelos para navegar entre ellos
  List<Map<String, dynamic>> get flightsList;

  /// ID del documento del vuelo actual
  String get currentFlightDocId;

  /// Origen de la lista de vuelos (para saber a qué pantalla volver)
  String get flightsSource;

  /// Método de ayuda para depurar información sobre el swipe
  void _debugSwipeInfo() {
    AppLogger.info('Lista de vuelos: ${flightsList.length} elementos');
    AppLogger.info('ID de documento actual: $currentFlightDocId');
    AppLogger.info('Origen de los datos: $flightsSource');
  }
}
