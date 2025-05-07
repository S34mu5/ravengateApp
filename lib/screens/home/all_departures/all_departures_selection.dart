import 'package:flutter/material.dart';
import '../../../services/user/user_flights_service.dart';
import '../../../utils/progress_dialog.dart';

/// Clase para manejar todo lo relacionado con la selección de vuelos
class DeparturesSelection {
  // Estado de selección
  bool isSelectionMode = false;
  Set<int> selectedFlightIndices = {};

  // Constructor
  DeparturesSelection();

  // Activar o desactivar el modo de selección múltiple
  void toggleSelectionMode() {
    isSelectionMode = !isSelectionMode;
    // Si desactivamos el modo selección, limpiar las selecciones
    if (!isSelectionMode) {
      selectedFlightIndices.clear();
    }
  }

  // Seleccionar o deseleccionar un vuelo por su índice
  void toggleFlightSelection(int index) {
    if (selectedFlightIndices.contains(index)) {
      selectedFlightIndices.remove(index);
    } else {
      selectedFlightIndices.add(index);
    }

    // Si no quedan vuelos seleccionados, desactivar el modo selección
    if (selectedFlightIndices.isEmpty && isSelectionMode) {
      isSelectionMode = false;
    }
  }

  // Seleccionar todos los vuelos filtrados
  void selectAllFlights(int flightsCount) {
    selectedFlightIndices =
        Set<int>.from(List<int>.generate(flightsCount, (index) => index));
  }

  // Deseleccionar todos los vuelos
  void deselectAllFlights() {
    selectedFlightIndices.clear();
  }

  // Guardar vuelos seleccionados en la lista de MyFlights
  Future<Map<String, int>> saveSelectedFlights(
      BuildContext context, List<Map<String, dynamic>> flights) async {
    if (selectedFlightIndices.isEmpty) {
      return {'saved': 0, 'restored': 0, 'alreadySaved': 0};
    }

    // Counters for results
    int savedCount = 0;
    int alreadySavedCount = 0;
    int restoredCount = 0;

    // Show loading dialog
    final ProgressDialog progressDialog = ProgressDialog(
      context,
      type: ProgressDialogType.normal,
      isDismissible: false,
    );

    progressDialog.style(
      message: 'Saving flights...',
      backgroundColor: Colors.white,
      progressWidget: const CircularProgressIndicator(),
      elevation: 10.0,
      insetAnimCurve: Curves.easeInOut,
    );

    progressDialog.show();

    try {
      // Guardar cada vuelo seleccionado
      for (final index in selectedFlightIndices) {
        if (index < flights.length) {
          final flight = flights[index];
          final wasAdded = await UserFlightsService.saveFlight(flight);

          if (wasAdded) {
            // Check if the flight was previously archived
            if (flight['was_archived'] == true) {
              restoredCount++;
            } else {
              savedCount++;
            }
          } else {
            alreadySavedCount++;
          }
        }
      }

      // Cerrar el diálogo de progreso
      if (progressDialog.isShowing) {
        await progressDialog.hide();
      }

      // Desactivar el modo selección y limpiar selecciones
      isSelectionMode = false;
      selectedFlightIndices.clear();

      return {
        'saved': savedCount,
        'restored': restoredCount,
        'alreadySaved': alreadySavedCount
      };
    } catch (e) {
      // Cerrar el diálogo de progreso
      if (progressDialog.isShowing) {
        await progressDialog.hide();
      }

      throw Exception('Error saving flights: $e');
    }
  }

  // Guardar un solo vuelo
  Future<Map<String, dynamic>> saveSingleFlight(
      Map<String, dynamic> flight) async {
    try {
      // Guardar el vuelo
      final wasAdded = await UserFlightsService.saveFlight(flight);
      final wasArchived = flight['was_archived'] == true;

      return {
        'success': true,
        'wasAdded': wasAdded,
        'wasArchived': wasArchived,
        'flightId': flight['flight_id']
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'flightId': flight['flight_id']
      };
    }
  }
}
