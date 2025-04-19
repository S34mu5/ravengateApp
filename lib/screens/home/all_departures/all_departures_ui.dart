import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../services/cache/cache_service.dart';
import '../flight_details/flight_details_screen.dart';

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
  String _searchQuery = '';
  List<Map<String, dynamic>> _filteredFlights = [];
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

  // Formatters for date and time
  final DateFormat _dateFormatter = DateFormat('yyyy-MM-dd');
  final DateFormat _timeFormatter = DateFormat('HH:mm');
  final DateFormat _displayFormatter = DateFormat('dd MMM HH:mm');

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
    final isEnabled = await CacheService.getNorwegianEquivalencePreference();
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
          'LOG: End date filter updated to: ${_dateFormatter.format(_endDate)} ${_timeFormatter.format(DateTime(2022, 1, 1, _endTime.hour, _endTime.minute))}');
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

    return '${_displayFormatter.format(startDateTime)} to ${_displayFormatter.format(endDateTime)}';
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
                      title:
                          Text(DateFormat('yyyy-MM-dd').format(tempStartDate)),
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
                      title: Text(DateFormat('yyyy-MM-dd').format(tempEndDate)),
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
    _searchQuery = query;
    _applyFilters();
    _saveFiltersToCache(); // Save filters when they change
  }

  // Apply only the text filter
  void _applyTextFilter(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
      if (_searchQuery.isEmpty) {
        // If query is empty, show all flights
        _filteredFlights = List.from(widget.flights);
      } else {
        // Filter by flight ID or airport (destination)
        _filteredFlights = widget.flights.where((flight) {
          final flightId = flight['flight_id'].toString().toLowerCase();
          final airport = flight['airport'].toString().toLowerCase();
          final airline = flight['airline'].toString().toLowerCase();

          // Check if user is searching for DY or D8 (equivalents) and if preference is enabled
          bool isMatchingNorwegianAirline = false;
          if (_norwegianEquivalenceEnabled &&
              (_searchQuery.contains('dy') || _searchQuery.contains('d8'))) {
            isMatchingNorwegianAirline = flightId.contains('dy') ||
                flightId.contains('d8') ||
                airline == 'dy' ||
                airline == 'd8';
          }

          // Return true if ID, airport or equivalent airline contains the query
          return flightId.contains(_searchQuery) ||
              airport.contains(_searchQuery) ||
              isMatchingNorwegianAirline;
        }).toList();
      }
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
        'LOG: Applying date filter: ${_dateFormatter.format(startDateTime)} ${_timeFormatter.format(startDateTime)} - ${_dateFormatter.format(endDateTime)} ${_timeFormatter.format(endDateTime)}');

    setState(() {
      // Filter flights by date range
      _filteredFlights = _filteredFlights.where((flight) {
        // Try to parse flight date
        try {
          final scheduleTimeStr = flight['schedule_time'].toString();
          DateTime flightDateTime;

          // Handle ISO format
          if (scheduleTimeStr.contains('T')) {
            flightDateTime = DateTime.parse(scheduleTimeStr);
          } else {
            // Simple HH:MM format, assume current date
            final parts = scheduleTimeStr.split(':');
            if (parts.length == 2) {
              final hour = int.parse(parts[0]);
              final minute = int.parse(parts[1]);
              flightDateTime = DateTime(
                _startDate.year,
                _startDate.month,
                _startDate.day,
                hour,
                minute,
              );
            } else {
              // Unrecognized format
              return false;
            }
          }

          // Return true if within range
          return flightDateTime.isAfter(startDateTime) &&
              flightDateTime.isBefore(endDateTime);
        } catch (e) {
          print('LOG: Error parsing date for filtering: $e');
          return false;
        }
      }).toList();
    });

    print('LOG: Filtered ${_filteredFlights.length} flights within date range');
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

  // Encontrar y desplazarse al primer vuelo no departed
  void _scrollToFirstNonDepartedFlight() {
    // Esperar a que la interfaz se actualice antes de desplazarse
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_filteredFlights.isEmpty) {
        return; // No hay vuelos para desplazar
      }

      // Encontrar el índice del primer vuelo no departed
      int index = -1;
      for (int i = 0; i < _filteredFlights.length; i++) {
        if (_filteredFlights[i]['status_code'] != 'D') {
          index = i;
          break;
        }
      }

      // Si encontramos un vuelo no departed, desplazarse a él
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

        print('LOG: Scrolled to first non-departed flight at index $index');
      } else {
        print('LOG: No non-departed flights found to scroll to');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    print(
        'LOG: Building UI for all flights (${_filteredFlights.length} flights shown out of ${widget.flights.length} total)');

    return Column(
      children: [
        // Date and time range selector
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: InkWell(
            onTap: () => _showDateTimeRangePicker(context),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
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
        // Search bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: TextField(
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
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              filled: true,
              fillColor: Colors.white,
              // Add clear button if there is text
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear, color: Colors.grey.shade600),
                      onPressed: () {
                        // Clear search field
                        _filterFlights('');
                        // We also need to clear the TextField
                        final textFieldController = TextEditingController();
                        textFieldController.clear();
                      },
                    )
                  : null,
            ),
            onChanged: _filterFlights,
          ),
        ),
        // Results counter
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
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
              if (_norwegianEquivalenceEnabled &&
                  _searchQuery.toLowerCase().contains('dy'))
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color.fromARGB(
                        255, 255, 68, 68), // Red (DY color)
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Showing also D8',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                )
              else if (_norwegianEquivalenceEnabled &&
                  _searchQuery.toLowerCase().contains('d8'))
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color.fromARGB(
                        255, 255, 68, 68), // Red (DY color)
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Showing also DY',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              if (_searchQuery.isNotEmpty ||
                  widget.flights.length != _filteredFlights.length)
                TextButton.icon(
                  onPressed: () {
                    // Reset search and date filters
                    _resetToDefaultFilters();
                  },
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Reset Filters'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
            ],
          ),
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

                      // Extract only the time from schedule_time
                      final formattedTime =
                          _extractTimeFromSchedule(flight['schedule_time']);

                      // Extract date from schedule_time
                      final formattedDate =
                          _extractDateFromSchedule(flight['schedule_time']);

                      // Extract status time if available
                      final String? statusTime =
                          flight['status_time'] != null &&
                                  flight['status_time'].toString().isNotEmpty
                              ? _extractTimeFromSchedule(flight['status_time'])
                              : null;

                      // Check if flight is delayed (status_time is different and later than schedule_time)
                      final bool isDelayed = statusTime != null &&
                          statusTime != formattedTime &&
                          _isLaterTime(statusTime, formattedTime);

                      // For debugging
                      print(
                          'LOG: Flight ${flight['flight_id']} - Original: ${flight['schedule_time']}, Formatted: $formattedTime, Status: ${flight['status_time']}, Delayed: $isDelayed');

                      // Check if flight is departed
                      final bool isDeparted = flight['status_code'] == 'D';

                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Stack(
                          children: [
                            ListTile(
                              leading: CircleAvatar(
                                backgroundColor: flight['color'],
                                child: Text(
                                  flight['airline'],
                                  style: TextStyle(
                                    color: flight['airline'] == 'AY'
                                        ? const Color.fromARGB(255, 0, 114, 206)
                                        : Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              title: Text(
                                '${flight['flight_id']} - $formattedTime ${flight['airport']} - $formattedDate',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color:
                                      isDeparted ? Colors.grey : Colors.black,
                                  decoration: isDeparted
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                              ),
                              subtitle: Row(
                                children: [
                                  Text('Gate: ${flight['gate']}'),
                                  if (isDelayed) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.amber.shade700,
                                        borderRadius: BorderRadius.circular(4),
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
                              trailing:
                                  const Icon(Icons.arrow_forward_ios, size: 16),
                              onTap: () {
                                print(
                                    'LOG: User selected flight ${flight['flight_id']} to ${flight['airport']}');

                                // Navegar a la pantalla de detalles
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => FlightDetailsScreen(
                                      flightId: flight['flight_id'],
                                      documentId: flight['id'] ?? '',
                                    ),
                                  ),
                                );
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
                          ],
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}
