import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../archived_flights/archived_flights_screen.dart';
import '../flight_details/flight_details_screen.dart';
import '../flight_details/oz_flight_details_screen.dart';
import '../../../utils/flight_filter_util.dart';
import '../../../common/widgets/flight_card.dart';
import '../../../common/widgets/flight_search_bar.dart';
import '../../../common/widgets/flights_counter_display.dart';
import '../../../common/widgets/flight_selection_controls.dart';
import '../../../common/widgets/time_ago_widget.dart';
import '../../../utils/progress_dialog.dart';
import '../../../services/user/user_flights_service.dart';
import '../../../services/location/location_service.dart';
import 'dart:async';
import '../../../utils/flight_sort_util.dart';
import '../base_departures_ui.dart';
import '../../../services/navigation/nested_navigation_service.dart';

/// Widget que muestra la interfaz de usuario para la lista de vuelos del usuario
class MyDeparturesUI extends BaseDeparturesUI {
  final Future<void> Function(String flightId)? onRemoveFlight;

  const MyDeparturesUI({
    required super.flights,
    this.onRemoveFlight,
    super.onRefresh,
    super.lastUpdated,
    super.usingCachedData,
    super.key,
  });

  @override
  State<MyDeparturesUI> createState() => _MyDeparturesUIState();
}

class _MyDeparturesUIState extends BaseDeparturesUIState<MyDeparturesUI> {
  @override
  Widget buildFlightsList() {
    if (widget.flights.isEmpty) {
      return _buildEmptyState();
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: null,
      floatingActionButton: buildSelectionControls(
        actionLabel: 'Archive Departures',
        actionIcon: Icons.archive,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Pequeño espacio en la parte superior
            const SizedBox(height: 8),

            // Barra de búsqueda
            FlightSearchBar(
              controller: searchController,
              onSearch: filterFlights,
              onClear: () {
                filterFlights('');
              },
            ),

            // Indicador de actualizado
            TimeAgoWidget(lastUpdated: widget.lastUpdated),

            // Contador de vuelos con botón de archivo
            FlightsCounterDisplay(
              flightCount: filteredFlights.length,
              searchQuery: searchQuery,
              norwegianEquivalenceEnabled: norwegianEquivalenceEnabled,
              onSelectMode: null,
              showResetButton: searchQuery.isNotEmpty,
              onResetFilters: searchQuery.isNotEmpty
                  ? () {
                      searchController.clear();
                      filterFlights('');
                    }
                  : null,
              leadingActions: [
                // Botón para ver vuelos archivados
                TextButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const ArchivedFlightsScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.archive_outlined, size: 16),
                  label: const Text('Archived'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),

            // Lista de vuelos
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.only(top: 8),
                itemCount: filteredFlights.length,
                itemBuilder: (context, index) {
                  return buildFlightItem(filteredFlights[index], index,
                      isDismissible: true);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Construye el estado vacío cuando no hay vuelos
  Widget _buildEmptyState() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),

            // Barra de búsqueda
            FlightSearchBar(
              controller: searchController,
              onSearch: filterFlights,
              onClear: () {
                filterFlights('');
              },
            ),

            // Indicador de actualizado
            TimeAgoWidget(lastUpdated: widget.lastUpdated),

            // Contador con botón de archivo
            FlightsCounterDisplay(
              flightCount: 0,
              searchQuery: searchQuery,
              norwegianEquivalenceEnabled: norwegianEquivalenceEnabled,
              onSelectMode: null,
              showResetButton: false,
              onResetFilters: null,
              leadingActions: [
                // Botón para ver vuelos archivados
                TextButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const ArchivedFlightsScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.archive_outlined, size: 16),
                  label: const Text('Archived'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),

            // Mensaje centrado
            const Expanded(
              child: Center(
                child: Text(
                  'No tienes vuelos guardados',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void onFlightTap(BuildContext context, Map<String, dynamic> flight) {
    _navigateToFlightDetails(context, flight);
  }

  @override
  Future<void> performActionOnSelectedFlights() async {
    if (selectedFlightIndices.isEmpty) {
      return;
    }

    // Mostrar diálogo de progreso
    final progressDialog = ProgressDialog(
      context,
      type: ProgressDialogType.normal,
      isDismissible: false,
    );

    progressDialog.style(
      message: 'Archivando vuelos...',
      borderRadius: 10.0,
      backgroundColor: Colors.white,
      progressWidget: const CircularProgressIndicator(),
      elevation: 10.0,
      insetAnimCurve: Curves.easeInOut,
    );

    await progressDialog.show();

    try {
      // Archivar cada vuelo seleccionado
      int archivedCount = 0;
      for (final index in selectedFlightIndices) {
        if (index < filteredFlights.length) {
          final flight = filteredFlights[index];
          // IMPORTANTE: Obtener el doc_id que es el ID real del documento en Firestore
          final docId = flight['doc_id'];

          if (docId != null) {
            // Llamar al servicio para archivar usando el ID de documento
            final success = await UserFlightsService.archiveFlight(docId);
            if (success) {
              archivedCount++;
              print(
                  'LOG: Vuelo con ID de documento $docId archivado correctamente');
            } else {
              print(
                  'LOG: No se pudo archivar el vuelo con ID de documento $docId');
            }
          } else {
            print(
                'LOG: Error - el vuelo no tiene doc_id: ${flight['flight_id']}');
          }
        }
      }

      // Cerrar el diálogo de progreso
      if (progressDialog.isShowing) {
        await progressDialog.hide();
      }

      if (!mounted) return;

      // Mostrar mensaje de éxito
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Archivados $archivedCount vuelos',
          ),
          backgroundColor: Colors.blue.shade700,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Desactivar el modo selección y limpiar selecciones
      setState(() {
        isSelectionMode = false;
        selectedFlightIndices.clear();
      });

      // Actualizar la lista de vuelos
      if (widget.onRefresh != null) {
        await widget.onRefresh!();
      }
    } catch (e) {
      // Cerrar el diálogo de progreso
      if (progressDialog.isShowing) {
        await progressDialog.hide();
      }

      if (!mounted) return;

      // Mostrar mensaje de error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al archivar vuelos: $e'),
          backgroundColor: Colors.red.shade700,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Muestra un diálogo de confirmación antes de eliminar un vuelo
  void _confirmRemoveFlight(String docId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Eliminar vuelo?'),
        content: const Text('Este vuelo se eliminará de tu lista. ¿Continuar?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Eliminar el vuelo si el usuario confirma
              if (widget.onRemoveFlight != null) {
                widget.onRemoveFlight!(docId);
              }
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  /// Navega a la pantalla de detalles del vuelo seleccionado usando navegación anidada
  void _navigateToFlightDetails(
      BuildContext context, Map<String, dynamic> flight) {
    print(
        'LOG: MyDeparturesUI - Navegando a detalles de vuelo usando navegación anidada');
    print('LOG: MyDeparturesUI - Vuelo seleccionado: ${flight['flight_id']}');
    print(
        'LOG: MyDeparturesUI - Pasando lista de ${widget.flights.length} vuelos');

    // Usar el servicio de navegación anidada
    final navigationService = NestedNavigationService();
    navigationService.navigateToFlightDetails(
      flight: flight,
      flightsList: widget.flights,
      flightsSource: 'my',
      currentTabIndex: 1, // My Departures es el tab 1
    );
  }
}
