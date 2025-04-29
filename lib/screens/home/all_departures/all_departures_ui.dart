import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../services/cache/cache_service.dart';
import '../../../services/user/user_flights_service.dart';
import '../flight_details/flight_details_screen.dart';
import '../../../utils/airline_helper.dart';
import '../../../utils/progress_dialog.dart';
import '../../../utils/flight_search_helper.dart';
import '../../../utils/flight_filter_util.dart';
import '../../../common/widgets/flight_card.dart';
import '../../../common/widgets/flight_search_bar.dart';
import '../../../common/widgets/flights_counter_display.dart';
import '../../../common/widgets/flight_selection_controls.dart';

/// Widget that displays the user interface for the list of all departure flights
class AllDeparturesUI extends StatefulWidget {
  final List<Map<String, dynamic>> flights;
  final Future<void> Function()? onRefresh;
  final Future<void> Function(DateTime startDateTime, DateTime endDateTime)?
      onCustomRangeLoad;
  final bool isRefreshing;
  final DateTime? lastUpdated;

  const AllDeparturesUI({
    required this.flights,
    this.onRefresh,
    this.onCustomRangeLoad,
    this.isRefreshing = false,
    this.lastUpdated,
    super.key,
  });

  @override
  State<AllDeparturesUI> createState() => _AllDeparturesUIState();
}

class _AllDeparturesUIState extends State<AllDeparturesUI> {
  bool _isLoading = true;
  bool _isSelectionMode = false;
  List<Map<String, dynamic>> _filteredFlights = [];
  Set<int> _selectedFlightIndices = {};
  // Variables para la búsqueda
  final TextEditingController _searchController = TextEditingController();
  String _searchAirline = '';
  String _searchAirport = '';
  String _searchGate = '';
  String _searchQuery = '';
  bool _norwegianEquivalenceEnabled = true; // Enabled by default

  // Scroll Controller para manejar el desplazamiento automático
  final ScrollController _scrollController = ScrollController();

  // Date and time filters
  DateTime _startDate = DateTime.now().subtract(const Duration(hours: 3));
  TimeOfDay _startTime = TimeOfDay(
      hour: DateTime.now().subtract(const Duration(hours: 3)).hour,
      minute: DateTime.now().subtract(const Duration(hours: 3)).minute);
  DateTime _endDate = DateTime.now().add(const Duration(days: 7));
  TimeOfDay _endTime = const TimeOfDay(hour: 23, minute: 59);

  @override
  void initState() {
    super.initState();
    _updateFilteredFlights();
    _loadFiltersFromCache();
    _loadNorwegianPreference();
  }

  @override
  void dispose() {
    // Liberar recursos del ScrollController
    _scrollController.dispose();
    super.dispose();
  }

  // Load Norwegian preference
  Future<void> _loadNorwegianPreference() async {
    final isEnabled = await FlightFilterUtil.loadNorwegianPreference();
    setState(() {
      _norwegianEquivalenceEnabled = isEnabled;
    });
    print(
        'LOG: Norwegian equivalence preference loaded: $_norwegianEquivalenceEnabled');
  }

  // Load saved filters from cache
  Future<void> _loadFiltersFromCache() async {
    try {
      final savedFilters = await CacheService.getFilters();
      if (savedFilters != null) {
        setState(() {
          _startDate = savedFilters['startDate'] as DateTime;
          _startTime = savedFilters['startTime'] as TimeOfDay;
          _endDate = savedFilters['endDate'] as DateTime;
          _endTime = savedFilters['endTime'] as TimeOfDay;
          _searchQuery = savedFilters['searchQuery'] as String;
        });
        // Apply loaded filters
        _applyFilters();
        print('LOG: Filters loaded from cache');
      }
    } catch (e) {
      print('ERROR: Could not load filters from cache: $e');
    }
  }

  // Save current filters to cache
  Future<void> _saveFiltersToCache() async {
    try {
      await CacheService.saveFilters(
        startDate: _startDate,
        startTime: _startTime,
        endDate: _endDate,
        endTime: _endTime,
        searchQuery: _searchQuery,
      );
      print('LOG: Filters saved to cache');
    } catch (e) {
      print('ERROR: Could not save filters to cache: $e');
    }
  }

  @override
  void didUpdateWidget(AllDeparturesUI oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If flights change, update the filtered list
    if (widget.flights != oldWidget.flights) {
      _updateFilteredFlights();
      _updateEndDateBasedOnLatestFlight(); // Actualizar fecha final con los nuevos datos
    }
  }

  // Find the latest flight date and update end date filter
  void _updateEndDateBasedOnLatestFlight() {
    if (widget.flights.isEmpty) return;

    DateTime latestFlightDate = DateTime.now();
    bool foundValidDate = false;

    // Buscar la fecha del vuelo más tardío
    for (final flight in widget.flights) {
      try {
        final scheduleTimeStr = flight['schedule_time'].toString();
        DateTime flightDateTime;

        // Formato ISO completo con T (ejemplo: 2023-01-01T12:30:00Z)
        if (scheduleTimeStr.contains('T')) {
          flightDateTime = DateTime.parse(scheduleTimeStr);

          // Si es fecha UTC, convertir a local
          if (scheduleTimeStr.endsWith('Z')) {
            flightDateTime = flightDateTime.toLocal();
          }
        }
        // Formato simple HH:MM (ejemplo: 15:30)
        else if (scheduleTimeStr.contains(':')) {
          final parts = scheduleTimeStr.split(':');
          if (parts.length >= 2) {
            final hour = int.parse(parts[0]);
            final minute = int.parse(parts[1]);

            // Para formato simple, asumimos la fecha actual
            // Note: Para vuelos futuros, esto podría necesitar ajustes adicionales
            flightDateTime = DateTime(
              DateTime.now().year,
              DateTime.now().month,
              DateTime.now().day,
              hour,
              minute,
            );

            // Si la hora es anterior a la actual, probablemente sea del día siguiente
            if (flightDateTime.isBefore(DateTime.now())) {
              flightDateTime = flightDateTime.add(const Duration(days: 1));
            }
          } else {
            continue; // Formato inválido, pasar al siguiente vuelo
          }
        } else {
          continue; // Formato no reconocido, pasar al siguiente vuelo
        }

        if (flightDateTime.isAfter(latestFlightDate)) {
          latestFlightDate = flightDateTime;
          foundValidDate = true;
          print(
              'LOG: Found later flight: ${flight['flight_id']} at $flightDateTime');
        }
      } catch (e) {
        print('LOG: Error parsing date for flight: $e');
      }
    }

    // Si encontramos al menos una fecha válida, actualizar la fecha final
    if (foundValidDate) {
      setState(() {
        _endDate = DateTime(
          latestFlightDate.year,
          latestFlightDate.month,
          latestFlightDate.day,
          23, // Hora 23:59 para incluir todo el día
          59,
        );
        _endTime = const TimeOfDay(hour: 23, minute: 59);
      });

      print(
          'LOG: End date filter updated to: ${FlightFilterUtil.dateFormatter.format(_endDate)} ${FlightFilterUtil.timeFormatter.format(DateTime(2022, 1, 1, _endTime.hour, _endTime.minute))}');
    } else {
      // Si no encontramos ninguna fecha válida, usar 7 días como valor predeterminado
      setState(() {
        _endDate = DateTime.now().add(const Duration(days: 7));
        _endTime = const TimeOfDay(hour: 23, minute: 59);
      });
      print(
          'LOG: No valid flight dates found, using default end date (7 days from now)');
    }
  }

  // Update the list of filtered flights when data changes
  void _updateFilteredFlights() {
    _filteredFlights = List.from(widget.flights);
    // Sort flights by departure time (ascending order)
    _sortFlightsByDepartureTime();
    // Apply existing filters
    _applyFilters();
  }

  // Sort flights in ascending order by departure time
  void _sortFlightsByDepartureTime() {
    _filteredFlights.sort((a, b) {
      try {
        final aTime = a['schedule_time'].toString();
        final bTime = b['schedule_time'].toString();

        // Parse times to DateTime objects for comparison
        DateTime aDateTime, bDateTime;

        // Handle ISO format
        if (aTime.contains('T')) {
          aDateTime = DateTime.parse(aTime);
        } else {
          // Simple HH:MM format
          final parts = aTime.split(':');
          if (parts.length == 2) {
            aDateTime = DateTime(
              DateTime.now().year,
              DateTime.now().month,
              DateTime.now().day,
              int.parse(parts[0]),
              int.parse(parts[1]),
            );
          } else {
            return 0; // Invalid format, no change in order
          }
        }

        if (bTime.contains('T')) {
          bDateTime = DateTime.parse(bTime);
        } else {
          final parts = bTime.split(':');
          if (parts.length == 2) {
            bDateTime = DateTime(
              DateTime.now().year,
              DateTime.now().month,
              DateTime.now().day,
              int.parse(parts[0]),
              int.parse(parts[1]),
            );
          } else {
            return 0; // Invalid format, no change in order
          }
        }

        // Compare times and return sort order (ascending)
        return aDateTime.compareTo(bDateTime);
      } catch (e) {
        print('LOG: Error sorting flights: $e');
        return 0; // On error, no change in order
      }
    });
  }

  // Convert TimeOfDay to DateTime
  DateTime _timeOfDayToDateTime(DateTime date, TimeOfDay time) {
    return DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
  }

  // Combine date and time for display
  String _formatDateTimeRange() {
    final startDateTime = _timeOfDayToDateTime(_startDate, _startTime);
    final endDateTime = _timeOfDayToDateTime(_endDate, _endTime);

    return '${FlightFilterUtil.displayFormatter.format(startDateTime)} to ${FlightFilterUtil.displayFormatter.format(endDateTime)}';
  }

  // Open modal to select date and time
  Future<void> _showDateTimeRangePicker(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        DateTime tempStartDate = _startDate;
        TimeOfDay tempStartTime = _startTime;
        DateTime tempEndDate = _endDate;
        TimeOfDay tempEndTime = _endTime;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Select Date & Time Range'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('From:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    // Selector de fecha inicial
                    ListTile(
                      title: Text(
                          FlightFilterUtil.dateFormatter.format(tempStartDate)),
                      leading: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: tempStartDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) {
                          setState(() {
                            tempStartDate = picked;
                          });
                        }
                      },
                    ),
                    // Selector de hora inicial
                    ListTile(
                      title: Text(
                          '${tempStartTime.hour.toString().padLeft(2, '0')}:${tempStartTime.minute.toString().padLeft(2, '0')}'),
                      leading: const Icon(Icons.access_time),
                      onTap: () async {
                        final TimeOfDay? picked = await showTimePicker(
                          context: context,
                          initialTime: tempStartTime,
                          builder: (BuildContext context, Widget? child) {
                            return MediaQuery(
                              data: MediaQuery.of(context).copyWith(
                                alwaysUse24HourFormat: true,
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (picked != null) {
                          setState(() {
                            tempStartTime = picked;
                          });
                        }
                      },
                    ),
                    const Divider(),
                    const Text('To:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    // Selector de fecha final
                    ListTile(
                      title: Text(
                          FlightFilterUtil.dateFormatter.format(tempEndDate)),
                      leading: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: tempEndDate,
                          firstDate: tempStartDate,
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) {
                          setState(() {
                            tempEndDate = picked;
                          });
                        }
                      },
                    ),
                    // Selector de hora final
                    ListTile(
                      title: Text(
                          '${tempEndTime.hour.toString().padLeft(2, '0')}:${tempEndTime.minute.toString().padLeft(2, '0')}'),
                      leading: const Icon(Icons.access_time),
                      onTap: () async {
                        final TimeOfDay? picked = await showTimePicker(
                          context: context,
                          initialTime: tempEndTime,
                          builder: (BuildContext context, Widget? child) {
                            return MediaQuery(
                              data: MediaQuery.of(context).copyWith(
                                alwaysUse24HourFormat: true,
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (picked != null) {
                          setState(() {
                            tempEndTime = picked;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () async {
                    // Validar que la fecha de inicio no sea posterior a la de fin
                    final startDateTime =
                        _timeOfDayToDateTime(tempStartDate, tempStartTime);
                    final endDateTime =
                        _timeOfDayToDateTime(tempEndDate, tempEndTime);

                    if (startDateTime.isAfter(endDateTime)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Start date cannot be after end date'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                      return;
                    }

                    // Determinar si necesitamos cargar datos históricos
                    final threePastHours =
                        DateTime.now().subtract(const Duration(hours: 3));
                    final needsHistoricalData =
                        startDateTime.isBefore(threePastHours);

                    // Aplicar cambios
                    _startDate = tempStartDate;
                    _startTime = tempStartTime;
                    _endDate = tempEndDate;
                    _endTime = tempEndTime;

                    if (needsHistoricalData &&
                        widget.onCustomRangeLoad != null) {
                      // Mostrar indicador de carga
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Cargando datos históricos...'),
                          duration: Duration(seconds: 2),
                        ),
                      );

                      // Cargar datos históricos desde la base de datos
                      await widget.onCustomRangeLoad!(
                          startDateTime, endDateTime);
                    } else {
                      // Solo filtrar los datos actuales
                      _applyDateTimeFilter();
                    }

                    _saveFiltersToCache(); // Guardar los filtros
                    Navigator.of(context).pop();
                  },
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Apply text search filter and date range
  void _applyFilters() {
    _applyTextFilter(_searchQuery);
    _applyDateTimeFilter();
    // Re-sort after filtering
    _sortFlightsByDepartureTime();
    // Desplazarse al primer vuelo no departed
    _scrollToFirstNonDepartedFlight();
  }

  /// Filter flights by search text
  void _filterFlights(String query) {
    setState(() {
      _searchQuery = query;
      _filteredFlights = FlightFilterUtil.filterFlights(
        flights: widget.flights,
        searchQuery: query,
        norwegianEquivalenceEnabled: _norwegianEquivalenceEnabled,
      );

      // Aplicar filtros de fecha después de la búsqueda de texto
      _applyFilters();
    });
  }

  // Apply only the text filter
  void _applyTextFilter(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
      _filteredFlights = FlightFilterUtil.filterFlights(
        flights: widget.flights,
        searchQuery: query,
        norwegianEquivalenceEnabled: _norwegianEquivalenceEnabled,
      );
    });

    // Apply date and time filter to results
    _applyDateTimeFilter();
  }

  // Apply date and time filter to flights
  void _applyDateTimeFilter() {
    // Create DateTime for range
    final startDateTime = _timeOfDayToDateTime(_startDate, _startTime);
    final endDateTime = _timeOfDayToDateTime(_endDate, _endTime);

    print(
        'LOG: Applying date filter: ${FlightFilterUtil.dateFormatter.format(startDateTime)} ${FlightFilterUtil.timeFormatter.format(startDateTime)} - ${FlightFilterUtil.dateFormatter.format(endDateTime)} ${FlightFilterUtil.timeFormatter.format(endDateTime)}');

    setState(() {
      // Filter flights by date range
      _filteredFlights = FlightFilterUtil.filterFlightsByDateRange(
        flights: _filteredFlights,
        startDateTime: startDateTime,
        endDateTime: endDateTime,
      );
    });

    print('LOG: Filtered ${_filteredFlights.length} flights within date range');
  }

  /// Extract time from ISO 8601 format or traditional "HH:MM" format
  String _extractTimeFromSchedule(String scheduleTime) {
    return FlightFilterUtil.extractTimeFromSchedule(scheduleTime);
  }

  /// Extract date from ISO 8601 format and format it as dd/MM
  String _extractDateFromSchedule(String scheduleTime) {
    return FlightFilterUtil.extractDateFromSchedule(scheduleTime);
  }

  /// Compara dos tiempos en formato HH:MM para determinar si el primero es posterior al segundo
  bool _isLaterTime(String time1, String time2) {
    return FlightFilterUtil.isLaterTime(time1, time2);
  }

  // Reset to default filters but using the current latest flight date
  void _resetToDefaultFilters() {
    _searchQuery = '';
    _startDate = DateTime.now().subtract(const Duration(hours: 3));
    _startTime = TimeOfDay(
        hour: DateTime.now().subtract(const Duration(hours: 3)).hour,
        minute: DateTime.now().subtract(const Duration(hours: 3)).minute);

    // Mantener la fecha final basada en el vuelo más tardío o usar 7 días si no hay datos
    _updateEndDateBasedOnLatestFlight();

    setState(() {
      _filteredFlights = List.from(widget.flights);
    });

    // Guardar los filtros
    _saveFiltersToCache();

    // Desplazarse al primer vuelo no departed
    _scrollToFirstNonDepartedFlight();
  }

  // Encontrar y desplazarse al primer vuelo no departed y no cancelado
  void _scrollToFirstNonDepartedFlight() {
    // Esperar a que la interfaz se actualice antes de desplazarse
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_filteredFlights.isEmpty) {
        return; // No hay vuelos para desplazar
      }

      // Encontrar el índice del primer vuelo no departed y no cancelado
      int index = -1;
      for (int i = 0; i < _filteredFlights.length; i++) {
        // No desplazarse a vuelos departed (D) ni cancelados (C)
        final statusCode = _filteredFlights[i]['status_code'];
        if (statusCode != 'D' && statusCode != 'C') {
          index = i;
          break;
        }
      }

      // Si encontramos un vuelo ni departed ni cancelado, desplazarse a él
      if (index != -1) {
        // Calcular la posición aproximada
        final double itemHeight =
            70.0; // Altura aproximada de un Card (ajustar según diseño)
        final double offset = index * itemHeight;

        // Desplazarse a la posición
        _scrollController.animateTo(
          offset,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
        );

        print('LOG: Scrolled to first active flight at index $index');
      } else {
        print('LOG: No active flights found to scroll to');
      }
    });
  }

  // Métodos para la selección múltiple

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

  /// Guardar vuelos seleccionados en la lista de MyFlights
  void _saveSelectedFlights() async {
    if (_selectedFlightIndices.isEmpty) return;

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

    int savedCount = 0;
    int alreadySavedCount = 0;
    int restoredCount = 0; // Counter for restored flights

    try {
      // Guardar cada vuelo seleccionado
      for (final index in _selectedFlightIndices) {
        if (index < _filteredFlights.length) {
          final flight = _filteredFlights[index];
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

      if (!mounted) return;

      // Build the message based on counters
      String message = '';
      if (savedCount > 0) {
        message = 'Added $savedCount flights';
      }

      if (restoredCount > 0) {
        if (message.isNotEmpty) message += ', ';
        message += 'Restored $restoredCount previously archived flights';
      }

      if (alreadySavedCount > 0) {
        if (message.isNotEmpty) message += ', ';
        message += '$alreadySavedCount already in your list';
      }

      // Mostrar mensaje de éxito
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green.shade700,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Desactivar el modo selección y limpiar selecciones
      setState(() {
        _isSelectionMode = false;
        _selectedFlightIndices.clear();
      });
    } catch (e) {
      // Cerrar el diálogo de progreso
      if (progressDialog.isShowing) {
        await progressDialog.hide();
      }

      if (!mounted) return;

      // Mostrar mensaje de error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving flights: $e'),
          backgroundColor: Colors.red.shade700,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Mostrar diálogo de filtros
  Future<void> _showFilterDialog() async {
    // Implementar en el futuro
    // Por ahora solo mostramos un mensaje
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Filtros próximamente'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  /// Acción al pulsar botón de guardado para un solo vuelo
  void _saveFlight(Map<String, dynamic> flight) async {
    try {
      // Guardar el vuelo
      final wasAdded = await UserFlightsService.saveFlight(flight);

      if (!mounted) return;

      if (wasAdded) {
        // Verificar si el vuelo fue restaurado de archivados
        final wasArchived = flight['was_archived'] == true;

        // Mostrar mensaje de éxito
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              wasArchived
                  ? 'Flight ${flight['flight_id']} added (previously archived)'
                  : 'Flight ${flight['flight_id']} added to your list',
            ),
            backgroundColor: Colors.green.shade700,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        // Mostrar mensaje de que ya estaba guardado
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Flight ${flight['flight_id']} already in your list'),
            backgroundColor: Colors.orange.shade700,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      // Mostrar error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error adding flight: $e'),
          backgroundColor: Colors.red.shade700,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Navega a la pantalla de detalles del vuelo seleccionado
  void _navigateToFlightDetails(
      BuildContext context, Map<String, dynamic> flight) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FlightDetailsScreen(
          flightId: flight['flight_id'],
          documentId: flight['id'],
          flightsList: widget.flights, // Pasar toda la lista de vuelos
          flightsSource: 'all', // Indicar que viene de "todos los vuelos"
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Reemplazar el FloatingActionButton con FlightSelectionControls
      floatingActionButton: _isSelectionMode
          ? FlightSelectionControls(
              selectedCount: _selectedFlightIndices.length,
              totalFlights: _filteredFlights.length,
              onSelectAll: _selectAllFlights,
              onDeselectAll: _deselectAllFlights,
              onExit: _toggleSelectionMode,
              onAction: _saveSelectedFlights,
              actionLabel: 'Add to My Flights',
              actionColor: Colors.green.shade300,
              actionIcon: Icons.save,
            )
          : null,
      body: Column(
        children: [
          // Añadir un pequeño espacio en la parte superior
          const SizedBox(height: 8),
          // Date and time range selector
          Padding(
            padding: const EdgeInsets.only(
                left: 16.0, right: 16.0, top: 4.0, bottom: 4.0),
            child: InkWell(
              onTap: () => _showDateTimeRangePicker(context),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.date_range, color: Colors.blue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Show departures from ${_formatDateTimeRange()}',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                    Icon(Icons.arrow_drop_down, color: Colors.grey.shade600),
                  ],
                ),
              ),
            ),
          ),
          // Barra de búsqueda reutilizable
          FlightSearchBar(
            controller: _searchController,
            onSearch: _filterFlights,
            onClear: () {
              _filterFlights('');
            },
          ),
          // Contador de vuelos reutilizable
          FlightsCounterDisplay(
            flightCount: _filteredFlights.length,
            searchQuery: _searchQuery,
            norwegianEquivalenceEnabled: _norwegianEquivalenceEnabled,
            onSelectMode: null,
            onResetFilters: (_searchQuery.isNotEmpty ||
                    widget.flights.length != _filteredFlights.length)
                ? _resetToDefaultFilters
                : null,
            showResetButton: _searchQuery.isNotEmpty ||
                widget.flights.length != _filteredFlights.length,
          ),
          Expanded(
            child: _filteredFlights.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.search_off,
                          size: 48,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isNotEmpty
                              ? 'No flights found for "$_searchQuery"'
                              : 'No flights in selected date range',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () {
                            // Reset all filters
                            _resetToDefaultFilters();
                          },
                          child: const Text('Show all flights'),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: widget.onRefresh ?? () async {},
                    child: ListView.builder(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: _filteredFlights.length,
                      itemBuilder: (context, index) {
                        final flight = _filteredFlights[index];

                        return FlightCard(
                          flight: flight,
                          isSelectionMode: _isSelectionMode,
                          isSelected: _selectedFlightIndices.contains(index),
                          isDismissible:
                              false, // No se puede deslizar en All Departures
                          selectionColor: Colors.green.shade300,
                          onSelectionToggle: (bool? value) {
                            _toggleFlightSelection(index);
                          },
                          onTap: () {
                            if (_isSelectionMode) {
                              // En modo selección, seleccionar/deseleccionar
                              _toggleFlightSelection(index);
                            } else {
                              // En modo normal, navegar a detalles
                              print(
                                  'LOG: User selected flight ${flight['flight_id']} to ${flight['airport']}');

                              // Navegar a la pantalla de detalles
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
          ),
        ],
      ),
    );
  }
}
