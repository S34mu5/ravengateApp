import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../utils/airline_helper.dart';
import '../../../utils/flight_search_helper.dart';
import '../flight_details/flight_details_screen.dart';
import '../../../services/cache/cache_service.dart';
import '../../../utils/progress_dialog.dart';
import '../../../common/widgets/flight_card.dart';

/// Widget que muestra la interfaz de usuario para la lista de vuelos archivados
class ArchivedFlightsUI extends StatefulWidget {
  final List<Map<String, dynamic>> flights;
  final Future<void> Function()? onRefresh;
  final Future<void> Function(String flightId)? onRestoreFlight;
  final Future<void> Function(String flightId)? onDeleteFlight;

  const ArchivedFlightsUI({
    required this.flights,
    this.onRefresh,
    this.onRestoreFlight,
    this.onDeleteFlight,
    super.key,
  });

  @override
  State<ArchivedFlightsUI> createState() => _ArchivedFlightsUIState();
}

class _ArchivedFlightsUIState extends State<ArchivedFlightsUI> {
  // Variables para búsqueda y filtrado
  List<Map<String, dynamic>> _filteredFlights = [];
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  bool _norwegianEquivalenceEnabled = true; // Habilitado por defecto

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
  void didUpdateWidget(ArchivedFlightsUI oldWidget) {
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
        if (scheduleTime.endsWith('Z')) {
          // Explicit UTC to local conversion
          final localDateTime = dateTime.toLocal();
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
        'LOG: Construyendo UI para vuelos archivados (${widget.flights.length} vuelos, ${_filteredFlights.length} filtrados)');
    return Column(
      children: [
        // Header con información
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          color: Colors.blue.shade50,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Archived Flights',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Here you can see the flights you have archived for this date. You can restore them to your active list.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
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
          padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_filteredFlights.length} archived flights',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
              Row(
                children: [
                  // Información de Norwegian si es relevante
                  if (_norwegianEquivalenceEnabled &&
                      (_searchQuery.toLowerCase().contains('dy') ||
                          _searchQuery.toLowerCase().contains('d8')))
                    FlightSearchHelper.buildNorwegianEquivalenceIndicator(
                      searchQuery: _searchQuery,
                      norwegianEquivalenceEnabled: _norwegianEquivalenceEnabled,
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
                      final String? statusTime =
                          flight['status_time'] != null &&
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

                      // Fecha de archivado
                      final String archivedDate = flight['archived_at'] != null
                          ? _formatArchivedDate(flight['archived_at'])
                          : 'Unknown date';

                      return _buildArchivedFlightItem(context, flight);
                    },
                  ),
                ),
        ),
      ],
    );
  }

  // Formato para la fecha de archivado
  String _formatArchivedDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('dd/MM/yyyy - HH:mm').format(date);
    } catch (e) {
      return dateString;
    }
  }

  // Mostrar diálogo de confirmación para restaurar un vuelo
  Future<void> _confirmRestoreFlight(
      String documentId, String flightNumber) async {
    final shouldRestore = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore Flight'),
        content: Text(
          'Are you sure you want to restore flight $flightNumber to your active flights?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );

    if (shouldRestore == true && widget.onRestoreFlight != null) {
      // Llamar a la función para restaurar el vuelo usando el doc_id
      print('LOG: Intentando restaurar vuelo con ID de documento: $documentId');
      widget.onRestoreFlight!(documentId);
    }
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
              'No archived flights found for "$_searchQuery"',
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

    // Estado vacío normal si no hay vuelos archivados
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.archive_outlined,
            size: 72,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No archived flights',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'When you archive flights, they will appear here',
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

  /// Construye un solo item de vuelo archivado
  Widget _buildArchivedFlightItem(
      BuildContext context, Map<String, dynamic> flight) {
    // Extracting info from the flight
    final flightId = flight['flight_id'] ?? 'Unknown';
    final airline = flight['airline'] ?? '';
    final scheduleTime = flight['schedule_time'] ?? '';
    final gate = flight['gate'] ?? '';
    final airport = flight['airport'] ?? '';
    final wasRemoved = flight['flight_removed'] == true;
    final hasDataError = flight['data_error'] == true;
    final docId = flight['doc_id'] ?? '';

    // Extracción de tiempo de archivo
    String archivedTime = '';
    if (flight['archived_at'] != null) {
      try {
        final dateTime = DateTime.parse(flight['archived_at']);
        archivedTime =
            _timeFormatter.format(dateTime); // Solo mostramos la hora
      } catch (e) {
        print('LOG: Error formatting archived time: $e');
      }
    }

    // Special styling for removed or error flights
    final isDisabled = wasRemoved || hasDataError;
    final cardColor = isDisabled ? Colors.grey.shade200 : Colors.white;
    final textColor = isDisabled ? Colors.grey.shade700 : Colors.black87;

    // Icono de aerolínea
    final Widget airlineIcon = airline.isNotEmpty
        ? Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: AirlineHelper.getAirlineColor(airline),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                airline.substring(0, 1).toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          )
        : const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: 2,
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // Flight info header
            Row(
              children: [
                // Airline icon and flight number
                Expanded(
                  child: Row(
                    children: [
                      airlineIcon,
                      const SizedBox(width: 8),
                      Text(
                        flightId,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: textColor,
                        ),
                      ),
                    ],
                  ),
                ),

                // Flight status pill
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Archived · $archivedTime',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Flight details
            Row(
              children: [
                Icon(Icons.flight_takeoff,
                    size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  airport,
                  style: TextStyle(
                    color: textColor,
                  ),
                ),
                const SizedBox(width: 16),
                Icon(Icons.access_time, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  _extractTimeFromSchedule(scheduleTime),
                  style: TextStyle(
                    color: textColor,
                  ),
                ),
                const SizedBox(width: 16),
                Icon(Icons.meeting_room, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  gate,
                  style: TextStyle(
                    color: textColor,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Restore button
                TextButton.icon(
                  onPressed: isDisabled
                      ? null
                      : () {
                          if (widget.onRestoreFlight != null &&
                              docId.isNotEmpty) {
                            widget.onRestoreFlight!(docId);
                          }
                        },
                  icon: const Icon(Icons.restore, size: 16),
                  label: const Text('Restore'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.blue.shade700,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    visualDensity: VisualDensity.compact,
                  ),
                ),

                // Delete button
                TextButton.icon(
                  onPressed: () {
                    if (widget.onDeleteFlight != null && docId.isNotEmpty) {
                      _confirmDelete(context, docId);
                    }
                  },
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: const Text('Delete'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red.shade700,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Mostrar diálogo de confirmación para eliminar permanentemente
  Future<void> _confirmDelete(BuildContext context, String docId) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Eliminar permanentemente"),
        content: Text(
            "¿Estás seguro que deseas eliminar permanentemente el vuelo $docId? Esta acción no se puede deshacer."),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("Cancelar"),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text("Eliminar permanentemente"),
          ),
        ],
      ),
    );

    if (shouldDelete == true && widget.onDeleteFlight != null) {
      widget.onDeleteFlight!(docId);
    }
  }
}
