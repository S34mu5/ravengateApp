import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../archived_flights/archived_flights_screen.dart';
import '../flight_details/flight_details_screen.dart';
import '../../../utils/airline_helper.dart';
import '../../../utils/flight_search_helper.dart';
import '../../../utils/flight_filter_util.dart';
import '../../../common/widgets/flight_card.dart';
import '../../../common/widgets/flight_search_bar.dart';
import '../../../common/widgets/flights_counter_display.dart';
import '../../../common/widgets/flight_selection_controls.dart';
import '../../../services/cache/cache_service.dart';
import '../../../utils/progress_dialog.dart';
import '../../../services/user/user_flights_service.dart';
import '../archived_flights/archived_flights_screen.dart';

/// Widget que muestra la interfaz de usuario para la lista de vuelos del usuario
class MyDeparturesUI extends StatefulWidget {
  final List<Map<String, dynamic>> flights;
  final Future<void> Function(String flightId)? onRemoveFlight;
  final Future<void> Function()? onRefresh;
  final DateTime? lastUpdated;

  const MyDeparturesUI({
    required this.flights,
    this.onRemoveFlight,
    this.onRefresh,
    this.lastUpdated,
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
    setState(() {
      _filteredFlights = FlightFilterUtil.filterFlights(
        flights: widget.flights,
        searchQuery: _searchQuery,
        norwegianEquivalenceEnabled: _norwegianEquivalenceEnabled,
      );
    });
  }

  // Filtrar vuelos por texto de búsqueda
  void _filterFlights(String query) {
    setState(() {
      _searchQuery = query;
      _filteredFlights = FlightFilterUtil.filterFlights(
        flights: widget.flights,
        searchQuery: query,
        norwegianEquivalenceEnabled: _norwegianEquivalenceEnabled,
      );
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

  /// Extract time from ISO 8601 format or traditional "HH:MM" format
  String _extractTimeFromSchedule(String scheduleTime) {
    try {
      // Check if in ISO 8601 format (contains a 'T')
      if (scheduleTime.contains('T')) {
        // Try to parse as ISO 8601
        final dateTime = DateTime.parse(scheduleTime);

        // Create formatter to show only time
        final formatter = DateFormat('HH:mm');

        // Convert to local time and format
        // Ensure the UTC timezone is properly handled when converting to local
        // The Z at the end of the ISO string means it's UTC
        if (scheduleTime.endsWith('Z')) {
          // Explicit UTC to local conversion
          final localDateTime = dateTime.toLocal();
          print(
              'LOG: Converting UTC time $dateTime to local time $localDateTime for flight');
          return formatter.format(localDateTime);
        } else {
          // If no Z, it might already be local or have explicit offset
          return formatter.format(dateTime);
        }
      } else if (scheduleTime.contains(':')) {
        // If it's just a time format "HH:MM", return it directly
        return scheduleTime;
      } else {
        print('LOG: Unknown time format: $scheduleTime');
        return scheduleTime;
      }
    } catch (e) {
      print('LOG: Error formatting time: $e');
      return scheduleTime; // Return original string if there's an error
    }
  }

  /// Extract date from ISO 8601 format and format it as dd/MM
  String _extractDateFromSchedule(String scheduleTime) {
    try {
      // Check if in ISO 8601 format (contains a 'T')
      if (scheduleTime.contains('T')) {
        // Try to parse as ISO 8601
        final dateTime = DateTime.parse(scheduleTime);

        // Create formatter to show only date in format dd/MM
        final formatter = DateFormat('dd/MM');

        // Convert to local time and format
        // Ensure the UTC timezone is properly handled when converting to local
        if (scheduleTime.endsWith('Z')) {
          // Explicit UTC to local conversion
          final localDateTime = dateTime.toLocal();
          return formatter.format(localDateTime);
        } else {
          // If no Z, it might already be local or have explicit offset
          return formatter.format(dateTime);
        }
      } else {
        // If it's just a time format, use current date
        final now = DateTime.now();
        return DateFormat('dd/MM').format(now);
      }
    } catch (e) {
      print('LOG: Error extracting date: $e');
      return ''; // Return empty string on error
    }
  }

  /// Compara dos tiempos en formato HH:MM para determinar si el primero es posterior al segundo
  bool _isLaterTime(String time1, String time2) {
    try {
      // Convertir al formato actual de tiempo
      final parts1 = time1.split(':');
      final parts2 = time2.split(':');

      if (parts1.length >= 2 && parts2.length >= 2) {
        final hour1 = int.parse(parts1[0]);
        final minute1 = int.parse(parts1[1]);
        final hour2 = int.parse(parts2[0]);
        final minute2 = int.parse(parts2[1]);

        // Comparar horas y minutos
        if (hour1 > hour2) {
          return true;
        } else if (hour1 == hour2) {
          return minute1 > minute2;
        }
      }
      return false;
    } catch (e) {
      print('LOG: Error comparando tiempos: $e');
      return false;
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
    print(
        'LOG: Construyendo UI para mis vuelos (${widget.flights.length} vuelos, ${_filteredFlights.length} filtrados)');
    return Scaffold(
      floatingActionButton: _isSelectionMode
          ? FlightSelectionControls(
              selectedCount: _selectedFlightIndices.length,
              totalFlights: _filteredFlights.length,
              onSelectAll: _selectAllFlights,
              onDeselectAll: _deselectAllFlights,
              onExit: _toggleSelectionMode,
              onAction: _archiveSelectedFlights,
              actionLabel: 'Archivar vuelos',
              actionColor: Colors.blue.shade300,
              actionIcon: Icons.archive,
            )
          : null,
      body: Column(
        children: [
          // SizedBox pequeño para margen superior
          const SizedBox(height: 8),
          // Barra de búsqueda reutilizable
          FlightSearchBar(
            controller: _searchController,
            onSearch: _filterFlights,
            onClear: () {
              _filterFlights('');
            },
          ),

          // Mostrar información de última actualización si está disponible
          if (widget.lastUpdated != null)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
              color: Colors.blue.shade50,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.access_time, color: Colors.blue, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    'Actualizado: ${_formatLastUpdated(widget.lastUpdated!)}',
                    style: TextStyle(color: Colors.blue.shade900, fontSize: 12),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 14),
                    onPressed: widget.onRefresh,
                    tooltip: 'Actualizar ahora',
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

          // Contador de vuelos reutilizable con botón de archivo
          FlightsCounterDisplay(
            flightCount: _filteredFlights.length,
            searchQuery: _searchQuery,
            norwegianEquivalenceEnabled: _norwegianEquivalenceEnabled,
            onSelectMode: !_isSelectionMode ? _toggleSelectionMode : null,
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
                return Stack(
                  children: [
                    FlightCard(
                      flight: flight,
                      isSelectionMode: _isSelectionMode,
                      isSelected: _selectedFlightIndices.contains(index),
                      onSelectionToggle: (isSelected) {
                        _toggleFlightSelection(index);
                      },
                      onTap: () {
                        if (_isSelectionMode) {
                          _toggleFlightSelection(index);
                        } else {
                          // Navegar a detalles del vuelo
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => FlightDetailsScreen(
                                flightId: flight['flight_id'],
                                documentId: flight['id'] ?? '',
                              ),
                            ),
                          );
                        }
                      },
                    ),

                    // Botón de eliminar (sólo si no está en modo selección)
                    if (!_isSelectionMode && widget.onRemoveFlight != null)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.redAccent),
                          onPressed: () =>
                              _confirmRemoveFlight(flight['doc_id']),
                          tooltip: 'Eliminar',
                          visualDensity: VisualDensity.compact,
                          iconSize: 24,
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Formatear la fecha de última actualización en formato legible
  String _formatLastUpdated(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'justo ahora';
    } else if (difference.inMinutes < 60) {
      return 'hace ${difference.inMinutes} min';
    } else if (difference.inHours < 24) {
      return 'hace ${difference.inHours} h';
    } else {
      return '${DateFormat('dd/MM HH:mm').format(dateTime)}';
    }
  }
}
