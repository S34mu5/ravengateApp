import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../services/cache/cache_service.dart';

/// Widget que muestra la interfaz de usuario para la lista de todos los vuelos de salida
class AllDeparturesUI extends StatefulWidget {
  final List<Map<String, dynamic>> flights;
  final Future<void> Function()? onRefresh;
  final bool isRefreshing;
  final DateTime? lastUpdated;

  const AllDeparturesUI({
    required this.flights,
    this.onRefresh,
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

  // Filtros de fecha y hora
  DateTime _startDate = DateTime.now();
  TimeOfDay _startTime = TimeOfDay(hour: 0, minute: 0);
  DateTime _endDate = DateTime.now().add(const Duration(days: 7));
  TimeOfDay _endTime = TimeOfDay(hour: 23, minute: 59);

  // Formatters para fecha y hora
  final DateFormat _dateFormatter = DateFormat('yyyy-MM-dd');
  final DateFormat _timeFormatter = DateFormat('HH:mm');
  final DateFormat _displayFormatter = DateFormat('dd MMM HH:mm');

  @override
  void initState() {
    super.initState();
    _updateFilteredFlights();
    _loadFiltersFromCache();
  }

  // Cargar filtros guardados desde la caché
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
        // Aplicar los filtros cargados
        _applyFilters();
        print('LOG: Filtros cargados desde caché');
      }
    } catch (e) {
      print('ERROR: No se pudieron cargar los filtros desde caché: $e');
    }
  }

  // Guardar filtros actuales en la caché
  Future<void> _saveFiltersToCache() async {
    try {
      await CacheService.saveFilters(
        startDate: _startDate,
        startTime: _startTime,
        endDate: _endDate,
        endTime: _endTime,
        searchQuery: _searchQuery,
      );
      print('LOG: Filtros guardados en caché');
    } catch (e) {
      print('ERROR: No se pudieron guardar los filtros en caché: $e');
    }
  }

  @override
  void didUpdateWidget(AllDeparturesUI oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Si los vuelos cambian, actualizar la lista filtrada
    if (widget.flights != oldWidget.flights) {
      _updateFilteredFlights();
    }
  }

  // Actualiza la lista de vuelos filtrados cuando cambian los datos
  void _updateFilteredFlights() {
    _filteredFlights = List.from(widget.flights);
    // Aplicar filtros existentes
    _applyFilters();
  }

  // Convertir TimeOfDay a DateTime
  DateTime _timeOfDayToDateTime(DateTime date, TimeOfDay time) {
    return DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
  }

  // Combinar fecha y hora para mostrar
  String _formatDateTimeRange() {
    final startDateTime = _timeOfDayToDateTime(_startDate, _startTime);
    final endDateTime = _timeOfDayToDateTime(_endDate, _endTime);

    return '${_displayFormatter.format(startDateTime)} to ${_displayFormatter.format(endDateTime)}';
  }

  // Abrir modal para seleccionar fecha y hora
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
                  onPressed: () {
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

                    // Aplicar cambios
                    _startDate = tempStartDate;
                    _startTime = tempStartTime;
                    _endDate = tempEndDate;
                    _endTime = tempEndTime;

                    _applyDateTimeFilter();
                    _saveFiltersToCache(); // Guardar los filtros al cambiarlos
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

  // Aplicar filtro por texto de búsqueda y rango de fechas
  void _applyFilters() {
    _applyTextFilter(_searchQuery);
    _applyDateTimeFilter();
  }

  /// Filtra los vuelos según el texto de búsqueda
  void _filterFlights(String query) {
    _searchQuery = query;
    _applyFilters();
    _saveFiltersToCache(); // Guardar los filtros al cambiarlos
  }

  // Aplica solo el filtro de texto
  void _applyTextFilter(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
      if (_searchQuery.isEmpty) {
        // Si la consulta está vacía, mostrar todos los vuelos
        _filteredFlights = List.from(widget.flights);
      } else {
        // Filtrar por ID de vuelo o aeropuerto (destino)
        _filteredFlights = widget.flights.where((flight) {
          final flightId = flight['flight_id'].toString().toLowerCase();
          final airport = flight['airport'].toString().toLowerCase();
          final airline = flight['airline'].toString().toLowerCase();

          // Verificar si el usuario está buscando DY o D8 (equivalentes)
          bool isMatchingNorwegianAirline = false;
          if (_searchQuery.contains('dy') || _searchQuery.contains('d8')) {
            isMatchingNorwegianAirline = flightId.contains('dy') ||
                flightId.contains('d8') ||
                airline == 'dy' ||
                airline == 'd8';
          }

          // Devuelve true si el ID, aeropuerto o aerolínea equivalente contienen la consulta
          return flightId.contains(_searchQuery) ||
              airport.contains(_searchQuery) ||
              isMatchingNorwegianAirline;
        }).toList();
      }
    });

    // Aplicar filtro de fecha y hora a los resultados
    _applyDateTimeFilter();
  }

  // Aplica el filtro de fecha y hora a los vuelos
  void _applyDateTimeFilter() {
    // Crear los DateTime para el rango
    final startDateTime = _timeOfDayToDateTime(_startDate, _startTime);
    final endDateTime = _timeOfDayToDateTime(_endDate, _endTime);

    print(
        'LOG: Aplicando filtro de fecha: ${_dateFormatter.format(startDateTime)} ${_timeFormatter.format(startDateTime)} - ${_dateFormatter.format(endDateTime)} ${_timeFormatter.format(endDateTime)}');

    setState(() {
      // Filtrar los vuelos por rango de fechas
      _filteredFlights = _filteredFlights.where((flight) {
        // Intentar parsear la fecha del vuelo
        try {
          final scheduleTimeStr = flight['schedule_time'].toString();
          DateTime flightDateTime;

          // Manejar formato ISO
          if (scheduleTimeStr.contains('T')) {
            flightDateTime = DateTime.parse(scheduleTimeStr);
          } else {
            // Formato simple HH:MM, asumimos fecha actual
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
              // Formato no reconocido
              return false;
            }
          }

          // Devuelve true si está dentro del rango
          return flightDateTime.isAfter(startDateTime) &&
              flightDateTime.isBefore(endDateTime);
        } catch (e) {
          print('LOG: Error al analizar fecha para filtrado: $e');
          return false;
        }
      }).toList();
    });

    print(
        'LOG: Se filtraron ${_filteredFlights.length} vuelos dentro del rango de fechas');
  }

  /// Extrae la hora del formato ISO 8601 o formato tradicional "HH:MM"
  String _extractTimeFromSchedule(String scheduleTime) {
    try {
      // Verificar si está en formato ISO 8601 (contiene una 'T')
      if (scheduleTime.contains('T')) {
        // Intentar parsear como ISO 8601
        final dateTime = DateTime.parse(scheduleTime);

        // Crear un formateador para solo mostrar la hora
        final formatter = DateFormat('HH:mm');

        // Convertir a hora local y formatear
        return formatter.format(dateTime.toLocal());
      } else if (scheduleTime.contains(':')) {
        // Si es solo un formato de hora "HH:MM", devolverlo directamente
        return scheduleTime;
      } else {
        print('LOG: Formato de hora desconocido: $scheduleTime');
        return scheduleTime;
      }
    } catch (e) {
      print('LOG: Error al formatear la hora: $e');
      return scheduleTime; // Devolvemos el string original si hay error
    }
  }

  @override
  Widget build(BuildContext context) {
    print(
        'LOG: Construyendo UI para todos los vuelos (${_filteredFlights.length} vuelos mostrados de ${widget.flights.length} totales)');

    return Column(
      children: [
        // Selector de rango de fecha y hora simplificado
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
        // Barra de búsqueda
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
              // Añadir botón de limpiar si hay texto
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear, color: Colors.grey.shade600),
                      onPressed: () {
                        // Limpiar el campo de búsqueda
                        _filterFlights('');
                        // También necesitamos limpiar el TextField
                        final textFieldController = TextEditingController();
                        textFieldController.clear();
                      },
                    )
                  : null,
            ),
            onChanged: _filterFlights,
          ),
        ),
        // Contador de resultados
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
              if (_searchQuery.toLowerCase().contains('dy'))
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color.fromARGB(
                        255, 255, 68, 68), // Rojo (color de DY)
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
              else if (_searchQuery.toLowerCase().contains('d8'))
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color.fromARGB(
                        255, 255, 68, 68), // Rojo (color de DY)
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
                    _searchQuery = '';
                    _startDate = DateTime.now();
                    _startTime = TimeOfDay(hour: 0, minute: 0);
                    _endDate = DateTime.now().add(const Duration(days: 7));
                    _endTime = TimeOfDay(hour: 23, minute: 59);
                    setState(() {
                      _filteredFlights = List.from(widget.flights);
                    });

                    // Guardar los filtros al resetearlos
                    _saveFiltersToCache();
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
                          _searchQuery = '';
                          _startDate = DateTime.now();
                          _startTime = TimeOfDay(hour: 0, minute: 0);
                          _endDate =
                              DateTime.now().add(const Duration(days: 7));
                          _endTime = TimeOfDay(hour: 23, minute: 59);
                          setState(() {
                            _filteredFlights = List.from(widget.flights);
                          });

                          // Guardar los filtros al resetearlos
                          _saveFiltersToCache();
                        },
                        child: const Text('Show all flights'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: widget.onRefresh ?? () async {},
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: _filteredFlights.length,
                    itemBuilder: (context, index) {
                      final flight = _filteredFlights[index];

                      // Extraer solo la hora del schedule_time
                      final formattedTime =
                          _extractTimeFromSchedule(flight['schedule_time']);

                      // Para depuración
                      print(
                          'LOG: Vuelo ${flight['flight_id']} - Original: ${flight['schedule_time']}, Formateado: $formattedTime');

                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ListTile(
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
                            '${flight['flight_id']} - $formattedTime ${flight['airport']}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text('Gate: ${flight['gate']}'),
                          trailing:
                              const Icon(Icons.arrow_forward_ios, size: 16),
                          onTap: () {
                            print(
                                'LOG: Usuario seleccionó vuelo ${flight['flight_id']} para ${flight['airport']}');
                          },
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
