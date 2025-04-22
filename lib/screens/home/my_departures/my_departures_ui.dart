import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../utils/airline_helper.dart';
import '../../../utils/flight_search_helper.dart';
import '../flight_details/flight_details_screen.dart';
import '../../../services/cache/cache_service.dart';
import '../../../utils/progress_dialog.dart';
import '../../../services/user/user_flights_service.dart';
import '../archived_flights/archived_flights_screen.dart';

/// Widget que muestra la interfaz de usuario para la lista de vuelos del usuario
class MyDeparturesUI extends StatefulWidget {
  final List<Map<String, dynamic>> flights;
  final Future<void> Function(String flightId)? onRemoveFlight;
  final Future<void> Function()? onRefresh;

  const MyDeparturesUI({
    required this.flights,
    this.onRemoveFlight,
    this.onRefresh,
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

  // Formatters for date and time
  final DateFormat _dateFormatter = DateFormat('yyyy-MM-dd');
  final DateFormat _timeFormatter = DateFormat('HH:mm');
  final DateFormat _displayFormatter = DateFormat('dd MMM HH:mm');

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
      _filteredFlights = FlightSearchHelper.filterFlights(
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
      _filteredFlights = FlightSearchHelper.filterFlights(
        flights: widget.flights,
        searchQuery: query,
        norwegianEquivalenceEnabled: _norwegianEquivalenceEnabled,
      );
    });
  }

  // Cargar preferencia de equivalencia Norwegian
  Future<void> _loadNorwegianPreference() async {
    final isEnabled = await CacheService.getNorwegianEquivalencePreference();
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
          ? Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Botón para archivar los vuelos seleccionados
                FloatingActionButton.extended(
                  heroTag: 'archiveSelectedFlights',
                  onPressed: _selectedFlightIndices.isNotEmpty
                      ? _archiveSelectedFlights
                      : null,
                  backgroundColor: _selectedFlightIndices.isNotEmpty
                      ? Colors.blue.shade300
                      : Colors.grey,
                  elevation: 4,
                  label: Row(
                    children: [
                      const Icon(Icons.archive),
                      const SizedBox(width: 8),
                      Text(
                        'Archivar vuelos (${_selectedFlightIndices.length})',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Botón para seleccionar todos los vuelos
                FloatingActionButton(
                  heroTag: 'selectAll',
                  onPressed: _filteredFlights.isNotEmpty
                      ? () {
                          if (_selectedFlightIndices.length ==
                              _filteredFlights.length) {
                            _deselectAllFlights();
                          } else {
                            _selectAllFlights();
                          }
                        }
                      : null,
                  backgroundColor: _filteredFlights.isNotEmpty
                      ? Colors.white
                      : Colors.grey.shade200,
                  foregroundColor: Colors.black87,
                  elevation: 3,
                  mini: true,
                  child: Icon(
                    _selectedFlightIndices.length == _filteredFlights.length &&
                            _filteredFlights.isNotEmpty
                        ? Icons.deselect
                        : Icons.select_all,
                  ),
                ),
                const SizedBox(height: 12),
                // Botón para salir del modo selección
                FloatingActionButton(
                  heroTag: 'exitSelection',
                  onPressed: () {
                    _toggleSelectionMode();
                  },
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black87,
                  elevation: 3,
                  mini: true,
                  child: const Icon(Icons.close),
                ),
              ],
            )
          : null,
      body: Column(
        children: [
          // SizedBox pequeño para margen superior
          const SizedBox(height: 8),
          // Barra de búsqueda con padding reducido
          Padding(
            padding: const EdgeInsets.only(
                left: 16.0, right: 16.0, top: 4.0, bottom: 8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by flight number or destination',
                prefixIcon: const Icon(Icons.search, color: Colors.blue),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                // Añadir botón para limpiar si hay texto
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, color: Colors.grey.shade600),
                        onPressed: () {
                          // Limpiar la búsqueda
                          _searchController.clear();
                          _filterFlights('');
                        },
                      )
                    : null,
              ),
              onChanged: _filterFlights,
            ),
          ),
          // Contador de resultados
          Padding(
            padding:
                const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_filteredFlights.length} flights',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
                Row(
                  children: [
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

                    // Botón para activar modo selección
                    if (!_isSelectionMode)
                      TextButton.icon(
                        onPressed: _toggleSelectionMode,
                        icon: const Icon(Icons.checklist, size: 16),
                        label: const Text('Select'),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),

                    // Información de Norwegian si es relevante
                    if (_norwegianEquivalenceEnabled &&
                        (_searchQuery.toLowerCase().contains('dy') ||
                            _searchQuery.toLowerCase().contains('d8')))
                      FlightSearchHelper.buildNorwegianEquivalenceIndicator(
                        searchQuery: _searchQuery,
                        norwegianEquivalenceEnabled:
                            _norwegianEquivalenceEnabled,
                      )!,

                    // Mostrar botón para limpiar filtros si hay búsqueda
                    if (_searchQuery.isNotEmpty)
                      TextButton.icon(
                        onPressed: () {
                          // Limpiar la búsqueda
                          _searchController.clear();
                          _filterFlights('');
                        },
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('Clear Search'),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: _filteredFlights.isEmpty
                ? _buildEmptyState(context)
                : RefreshIndicator(
                    onRefresh: widget.onRefresh ?? () async {},
                    child: ListView.builder(
                      itemCount: _filteredFlights.length,
                      itemBuilder: (context, index) {
                        final flight = _filteredFlights[index];

                        // Extract only the time from schedule_time
                        final formattedTime =
                            _extractTimeFromSchedule(flight['schedule_time']);

                        // Extract date from schedule_time
                        final formattedDate =
                            _extractDateFromSchedule(flight['schedule_time']);

                        // Extract status time if available
                        final String? statusTime = flight['status_time'] !=
                                    null &&
                                flight['status_time'].toString().isNotEmpty
                            ? _extractTimeFromSchedule(flight['status_time'])
                            : null;

                        // Check if flight is delayed (status_time is different and later than schedule_time)
                        final bool isDelayed = statusTime != null &&
                            statusTime != formattedTime &&
                            _isLaterTime(statusTime, formattedTime);

                        // Check if flight is departed
                        final bool isDeparted = flight['status_code'] == 'D';

                        // Check if flight is cancelled
                        final bool isCancelled = flight['status_code'] == 'C';

                        return Dismissible(
                          key: Key(flight['id'] ??
                              flight['flight_id'] ??
                              'flight-$index'),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            color: Colors.red,
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20.0),
                            child:
                                const Icon(Icons.delete, color: Colors.white),
                          ),
                          confirmDismiss: (direction) async {
                            // No permitir deslizar para eliminar en modo selección
                            if (_isSelectionMode) return false;

                            // Show confirmation dialog before deleting
                            return await showDialog<bool>(
                              context: context,
                              builder: (BuildContext context) {
                                return AlertDialog(
                                  title: const Text("Confirm"),
                                  content: Text(
                                      "Are you sure you want to remove ${flight['flight_id']} from your list?"),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(false),
                                      child: const Text("Cancel"),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(true),
                                      child: const Text("Delete"),
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                          onDismissed: (direction) {
                            // Call the remove function passed from parent
                            if (widget.onRemoveFlight != null) {
                              widget.onRemoveFlight!(
                                  flight['id'] ?? flight['flight_id']);
                            }
                          },
                          child: Card(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 4),
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Stack(
                              children: [
                                ListTile(
                                  leading: _isSelectionMode
                                      ? Checkbox(
                                          value: _selectedFlightIndices
                                              .contains(index),
                                          onChanged: (bool? value) {
                                            _toggleFlightSelection(index);
                                          },
                                          activeColor: Colors.blue.shade300,
                                        )
                                      : CircleAvatar(
                                          backgroundColor: flight['color'] ??
                                              AirlineHelper.getAirlineColor(
                                                  flight['airline']),
                                          child: Text(
                                            flight['airline'],
                                            style: TextStyle(
                                              color: AirlineHelper
                                                  .getTextColorForAirline(
                                                      flight['airline']),
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                  title: Text(
                                    '${flight['flight_id']} - $formattedTime ${flight['airport']} - $formattedDate',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isDeparted || isCancelled
                                          ? Colors.grey
                                          : Colors.black,
                                      decoration: isDeparted || isCancelled
                                          ? TextDecoration.lineThrough
                                          : null,
                                    ),
                                  ),
                                  subtitle: Row(
                                    children: [
                                      Text('Gate: ${flight['gate']}'),
                                      if (isDelayed && !isCancelled) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.amber.shade700,
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Text(
                                                'DELAYED',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                statusTime!,
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  trailing: _isSelectionMode
                                      ? null
                                      : const Icon(Icons.arrow_forward_ios,
                                          size: 16),
                                  onTap: () {
                                    if (_isSelectionMode) {
                                      // En modo selección, seleccionar/deseleccionar
                                      _toggleFlightSelection(index);
                                    } else {
                                      print(
                                          'LOG: Usuario seleccionó su vuelo ${flight['flight_id']} para ${flight['airport']}');

                                      // Navegar a la pantalla de detalles
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              FlightDetailsScreen(
                                            flightId: flight['flight_id'],
                                            documentId: flight['id'] ?? '',
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                  onLongPress: _isSelectionMode
                                      ? null
                                      : () {
                                          // Si no estamos en modo selección, activarlo y seleccionar este vuelo
                                          if (!_isSelectionMode) {
                                            setState(() {
                                              _isSelectionMode = true;
                                              _selectedFlightIndices.add(index);
                                            });
                                          }
                                        },
                                ),
                                if (isDeparted)
                                  Positioned(
                                    right: 0,
                                    left: 0,
                                    top: 0,
                                    bottom: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      child: Banner(
                                        message: 'DEPARTED',
                                        location: BannerLocation.topEnd,
                                        color: Colors.red.shade700,
                                        textStyle: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                if (isCancelled)
                                  Positioned(
                                    right: 0,
                                    left: 0,
                                    top: 0,
                                    bottom: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      child: Banner(
                                        message: 'CANCELLED',
                                        location: BannerLocation.topEnd,
                                        color: Colors.grey.shade800,
                                        textStyle: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    // Si hay búsqueda pero no resultados, mostrar mensaje específico
    if (_searchQuery.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.search_off,
              size: 72,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              'No flights found for "$_searchQuery"',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                _searchController.clear();
                _filterFlights('');
              },
              child: const Text('Clear search'),
            ),
          ],
        ),
      );
    }

    // Estado vacío normal si no hay vuelos guardados
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.flight_takeoff,
            size: 72,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No saved flights yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Long press on a flight in All Departures\nto add it to your list',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}
