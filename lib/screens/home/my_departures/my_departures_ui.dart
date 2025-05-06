import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../archived_flights/archived_flights_screen.dart';
import '../flight_details/flight_details_screen.dart';
import '../flight_details/oz_flight_details_screen.dart';
import '../../../utils/airline_helper.dart';
import '../../../utils/flight_search_helper.dart';
import '../../../utils/flight_filter_util.dart';
import '../../../common/widgets/flight_card.dart';
import '../../../common/widgets/flight_search_bar.dart';
import '../../../common/widgets/flights_counter_display.dart';
import '../../../common/widgets/flight_selection_controls.dart';
import '../../../common/widgets/time_ago_widget.dart';
import '../../../services/cache/cache_service.dart';
import '../../../utils/progress_dialog.dart';
import '../../../services/user/user_flights_service.dart';
import '../archived_flights/archived_flights_screen.dart';
import '../../../services/location/location_service.dart';
import 'dart:async';

/// Widget que muestra la interfaz de usuario para la lista de vuelos del usuario
class MyDeparturesUI extends StatefulWidget {
  final List<Map<String, dynamic>> flights;
  final Future<void> Function(String flightId)? onRemoveFlight;
  final Future<void> Function()? onRefresh;
  final DateTime? lastUpdated;
  final bool usingCachedData;

  const MyDeparturesUI({
    required this.flights,
    this.onRemoveFlight,
    this.onRefresh,
    this.lastUpdated,
    this.usingCachedData = false,
    super.key,
  });

  @override
  State<MyDeparturesUI> createState() => _MyDeparturesUIState();
}

class _MyDeparturesUIState extends State<MyDeparturesUI> {
  // Variables para búsqueda y filtrado
  List<Map<String, dynamic>> _filteredFlights = [];
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  bool _norwegianEquivalenceEnabled = true; // Habilitado por defecto

  // Variables para el modo de selección
  bool _isSelectionMode = false;
  Set<int> _selectedFlightIndices = {};

  @override
  void initState() {
    super.initState();
    _updateFilteredFlights();
    _loadNorwegianPreference();
  }

  @override
  void didUpdateWidget(MyDeparturesUI oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.flights != oldWidget.flights) {
      _updateFilteredFlights();
    }
  }

  // Actualizar la lista filtrada cuando cambian los datos
  void _updateFilteredFlights() {
    // Primero filtrar los vuelos según el criterio de búsqueda
    final filteredList = FlightFilterUtil.filterFlights(
      flights: widget.flights,
      searchQuery: _searchQuery,
      norwegianEquivalenceEnabled: _norwegianEquivalenceEnabled,
    );

    // Ordenar los vuelos por tiempo (primero los más tempranos)
    filteredList.sort((a, b) {
      try {
        // Primero intentamos comparar por status_time (el tiempo actual del vuelo)
        final aStatusTime = a['status_time']?.toString() ?? '';
        final bStatusTime = b['status_time']?.toString() ?? '';

        // Si ambos tienen status_time, comparamos esos valores
        if (aStatusTime.isNotEmpty && bStatusTime.isNotEmpty) {
          final aTime = FlightFilterUtil.extractTimeFromSchedule(aStatusTime);
          final bTime = FlightFilterUtil.extractTimeFromSchedule(bStatusTime);
          return aTime.compareTo(bTime);
        }

        // Si no tienen status_time, comparamos schedule_time
        final aScheduleTime = a['schedule_time'].toString();
        final bScheduleTime = b['schedule_time'].toString();

        final aTime = FlightFilterUtil.extractTimeFromSchedule(aScheduleTime);
        final bTime = FlightFilterUtil.extractTimeFromSchedule(bScheduleTime);

        return aTime.compareTo(bTime);
      } catch (e) {
        print('LOG: Error ordenando vuelos: $e');
        return 0; // En caso de error, no cambiamos el orden
      }
    });

    setState(() {
      _filteredFlights = filteredList;
    });
  }

  // Filtrar vuelos por texto de búsqueda
  void _filterFlights(String query) {
    setState(() {
      _searchQuery = query;
      _updateFilteredFlights();
    });
  }

  // Cargar preferencia de equivalencia Norwegian usando el util compartido
  Future<void> _loadNorwegianPreference() async {
    final isEnabled = await FlightFilterUtil.loadNorwegianPreference();
    setState(() {
      _norwegianEquivalenceEnabled = isEnabled;
    });
    print(
        'LOG: Norwegian equivalence preference loaded: $_norwegianEquivalenceEnabled');
  }

  /// Activar o desactivar el modo de selección múltiple
  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      // Si desactivamos el modo selección, limpiar las selecciones
      if (!_isSelectionMode) {
        _selectedFlightIndices.clear();
      }
    });
  }

  /// Seleccionar o deseleccionar un vuelo por su índice
  void _toggleFlightSelection(int index) {
    setState(() {
      if (_selectedFlightIndices.contains(index)) {
        _selectedFlightIndices.remove(index);
      } else {
        _selectedFlightIndices.add(index);
      }

      // Si no quedan vuelos seleccionados, desactivar el modo selección
      if (_selectedFlightIndices.isEmpty && _isSelectionMode) {
        _isSelectionMode = false;
      }
    });
  }

  /// Seleccionar todos los vuelos filtrados
  void _selectAllFlights() {
    setState(() {
      _selectedFlightIndices = Set<int>.from(
          List<int>.generate(_filteredFlights.length, (index) => index));
    });
  }

  /// Deseleccionar todos los vuelos
  void _deselectAllFlights() {
    setState(() {
      _selectedFlightIndices.clear();
    });
  }

  /// Método para archivar los vuelos seleccionados
  Future<void> _archiveSelectedFlights() async {
    if (_selectedFlightIndices.isEmpty) {
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
      for (final index in _selectedFlightIndices) {
        if (index < _filteredFlights.length) {
          final flight = _filteredFlights[index];
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
        _isSelectionMode = false;
        _selectedFlightIndices.clear();
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
            child: const Text('Eliminar'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: null,
      floatingActionButton: _isSelectionMode
          ? FlightSelectionControls(
              selectedCount: _selectedFlightIndices.length,
              totalFlights: _filteredFlights.length,
              onSelectAll: _selectAllFlights,
              onDeselectAll: _deselectAllFlights,
              onExit: _toggleSelectionMode,
              onAction: _archiveSelectedFlights,
              actionLabel: 'Archive Departures',
              actionColor: Colors.white, // Fondo blanco
              actionTextColor: Colors.black87, // Texto negro
              actionIcon: Icons.archive,
            )
          : null,
      body: SafeArea(
        child: Column(
          children: [
            // Pequeño espacio en la parte superior (como en all_departures_ui.dart)
            const SizedBox(height: 8),

            // Barra de búsqueda reutilizable
            FlightSearchBar(
              controller: _searchController,
              onSearch: _filterFlights,
              onClear: () {
                _filterFlights('');
              },
            ),

            // Indicador de actualizado hace X tiempo (ahora como widget separado)
            TimeAgoWidget(lastUpdated: widget.lastUpdated),

            // Contador de vuelos reutilizable con botón de archivo
            FlightsCounterDisplay(
              flightCount: _filteredFlights.length,
              searchQuery: _searchQuery,
              norwegianEquivalenceEnabled: _norwegianEquivalenceEnabled,
              onSelectMode:
                  null, // Ya no necesitamos este botón, usamos pulsación larga
              showResetButton: _searchQuery.isNotEmpty,
              onResetFilters: _searchQuery.isNotEmpty
                  ? () {
                      _searchController.clear();
                      _filterFlights('');
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

            // Lista de vuelos con Flexible para que ocupe el espacio restante
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.only(top: 8),
                itemCount: _filteredFlights.length,
                itemBuilder: (context, index) {
                  final flight = _filteredFlights[index];

                  // Widget del vuelo individual
                  return FlightCard(
                    flight: flight,
                    isSelectionMode: _isSelectionMode,
                    isSelected: _selectedFlightIndices.contains(index),
                    isDismissible:
                        !_isSelectionMode, // Solo permitir deslizar para eliminar fuera del modo selección
                    onSelectionToggle: (isSelected) {
                      _toggleFlightSelection(index);
                    },
                    onTap: () {
                      if (_isSelectionMode) {
                        _toggleFlightSelection(index);
                      } else {
                        // Navegar a detalles del vuelo
                        _navigateToFlightDetails(context, flight);
                      }
                    },
                    onLongPress: _isSelectionMode
                        ? null
                        : () async {
                            // Si no estamos en modo selección, activarlo y seleccionar este vuelo
                            if (!_isSelectionMode) {
                              setState(() {
                                _isSelectionMode = true;
                                _selectedFlightIndices.add(index);
                              });
                            }
                          },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Navega a la pantalla de detalles del vuelo seleccionado
  void _navigateToFlightDetails(
      BuildContext context, Map<String, dynamic> flight) async {
    // Verificar la ubicación actual
    final bool isOversize = await LocationService.isOversizeLocation();
    print('LOG: Ubicación actual: ${isOversize ? "Oversize" : "Bins"}');

    // Variable para almacenar el resultado (si se debe actualizar)
    bool? shouldRefresh;

    if (isOversize) {
      // Si la ubicación es Oversize, mostrar la pantalla de detalles de Oversize
      shouldRefresh = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) => OzFlightDetailsScreen(
            flightId: flight['flight_id'],
            documentId: flight['flight_ref'] ?? flight['id'] ?? '',
            flightsList: widget.flights, // Pasar toda la lista de vuelos
            flightsSource: 'my', // Indicar que viene de "mis vuelos"
            forceRefreshOnReturn:
                true, // Siempre forzar actualización al volver
          ),
        ),
      );
    } else {
      // Si la ubicación es Bins, mostrar la pantalla de detalles normal
      shouldRefresh = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) => FlightDetailsScreen(
            flightId: flight['flight_id'],
            documentId: flight['flight_ref'] ?? flight['id'] ?? '',
            flightsList: widget.flights, // Pasar toda la lista de vuelos
            flightsSource: 'my', // Indicar que viene de "mis vuelos"
            forceRefreshOnReturn:
                true, // Siempre forzar actualización al volver
          ),
        ),
      );
    }

    // Si se recibió true como resultado, actualizar la lista de vuelos
    if (shouldRefresh == true && widget.onRefresh != null) {
      print('LOG: Forzando actualización tras regresar de detalles de vuelo');
      await widget.onRefresh!();
    }
  }

  /// Compara dos tiempos en formato HH:MM para determinar si el primero es posterior al segundo
  bool _isLaterTime(String time1, String time2) {
    return FlightFilterUtil.isLaterTime(time1, time2);
  }
}
