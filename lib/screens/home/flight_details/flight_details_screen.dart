import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'flight_details_ui.dart';
import '../../../services/navigation/swipeable_flight_details.dart';
import '../../../services/navigation/swipeable_flights_service.dart';

/// Component that handles the logic and data for the flight details screen
/// Gets detailed data of a specific flight from Firestore
class FlightDetailsScreen extends StatefulWidget {
  final String flightId;
  final String documentId;
  final List<Map<String, dynamic>>? flightsList;
  final String? flightsSource; // 'all' o 'my' para saber de dónde viene

  const FlightDetailsScreen(
      {required this.flightId,
      required this.documentId,
      this.flightsList,
      this.flightsSource,
      super.key});

  @override
  State<FlightDetailsScreen> createState() => _FlightDetailsScreenState();
}

class _FlightDetailsScreenState extends State<FlightDetailsScreen>
    with SwipeableFlightDetails {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Map<String, dynamic>? _flightDetails;
  List<Map<String, dynamic>> _gateHistory = [];
  List<Map<String, dynamic>> _fullHistory = [];
  bool _isLoading = true;
  String? _errorMessage;

  // Variables para el vuelo adyacente
  Map<String, dynamic>? _adjacentFlightDetails;
  bool _loadingAdjacentFlight = false;

  // Implementación de los getters requeridos por el mixin SwipeableFlightDetails
  @override
  List<Map<String, dynamic>> get flightsList => widget.flightsList ?? [];

  @override
  String get currentFlightDocId => widget.documentId;

  @override
  String get flightsSource => widget.flightsSource ?? 'all';

  @override
  void initState() {
    super.initState();
    _loadFlightDetails();
    _debugSwipeInfo();
  }

  /// Loads the complete flight details from Firestore
  Future<void> _loadFlightDetails() async {
    print('LOG: Loading flight details for ${widget.flightId}...');

    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // Get the flight document using its ID
      final DocumentSnapshot flightDoc =
          await _firestore.collection('flights').doc(widget.documentId).get();

      if (!flightDoc.exists) {
        print('LOG: Flight with ID ${widget.documentId} not found');
        setState(() {
          _errorMessage = 'No data found for this flight';
          _isLoading = false;
        });
        return;
      }

      // Convert data to Map
      final Map<String, dynamic> flightData =
          flightDoc.data() as Map<String, dynamic>;

      // Calculate the cutoff time (2 hours before scheduled flight time)
      DateTime? cutoffTime;
      try {
        // Get the schedule_time from flight data
        final String scheduleTimeStr = flightData['schedule_time'] ?? '';
        if (scheduleTimeStr.isNotEmpty) {
          // Create a DateTime object based on schedule_time
          DateTime scheduleDateTime;

          // Check if it's in ISO 8601 format (contains 'T')
          if (scheduleTimeStr.contains('T')) {
            scheduleDateTime = DateTime.parse(scheduleTimeStr);
          } else {
            // It's in HH:MM format, we need to create a DateTime for today
            final List<String> timeParts = scheduleTimeStr.split(':');
            if (timeParts.length == 2) {
              final int hour = int.parse(timeParts[0]);
              final int minute = int.parse(timeParts[1]);
              final DateTime now = DateTime.now();
              scheduleDateTime =
                  DateTime(now.year, now.month, now.day, hour, minute);
            } else {
              throw FormatException('Invalid time format: $scheduleTimeStr');
            }
          }

          // Calculate 2 hours before the schedule time
          cutoffTime = scheduleDateTime.subtract(const Duration(hours: 2));

          print(
              'LOG: Schedule time: $scheduleDateTime, Cutoff time: $cutoffTime');
        }
      } catch (timeError) {
        print('LOG: Error calculating cutoff time: $timeError');
        // If there's an error, we'll continue without filtering
      }

      // Load gate change history from the 'history' subcollection
      List<Map<String, dynamic>> gateHistory = [];
      List<Map<String, dynamic>> fullHistory = [];

      try {
        print(
            'LOG: Checking for history subcollection at path: flights/${widget.documentId}/history');

        // Primero verificar si la colección history existe
        final collectionRef = _firestore
            .collection('flights')
            .doc(widget.documentId)
            .collection('history');

        // Intentar obtener un solo documento para verificar si la colección existe
        final testQuery = await collectionRef.limit(1).get();

        if (testQuery.docs.isEmpty) {
          print('LOG: History subcollection is empty or does not exist');
          // No hay historial, dejar las listas vacías
        } else {
          print('LOG: History subcollection exists, retrieving all documents');

          // La subcolección existe, obtener todos los documentos
          final QuerySnapshot historySnapshot = await collectionRef
              .orderBy('change_time', descending: true)
              .get();

          print(
              'LOG: Retrieved ${historySnapshot.docs.length} history documents from Firestore');

          // Process each history document - extract full history first
          if (historySnapshot.docs.isNotEmpty) {
            // Obtener historial completo de todos los documentos
            fullHistory = historySnapshot.docs.map((historyDoc) {
              final String id = historyDoc.id;
              final Map<String, dynamic> data =
                  historyDoc.data() as Map<String, dynamic>;

              print(
                  'LOG DEBUG: Processing history document with ID: $id and keys: ${data.keys.toList()}');

              // Añadir el ID del documento al mapa de datos
              return {
                'id': id,
                ...data, // Incluir todos los campos originales
              };
            }).toList();

            print(
                'LOG: Loaded ${fullHistory.length} complete history records with fields');
            // Mostrar algunos ejemplos para depuración
            if (fullHistory.isNotEmpty) {
              final example = fullHistory.first;
              print(
                  'LOG DEBUG: Example history record - ID: ${example['id']}, Fields: ${example.keys.toList()}');
            }

            // Procesar historial de cambios de puerta (compatible con el código existente)
            gateHistory = historySnapshot.docs.map((historyDoc) {
              final data = historyDoc.data() as Map<String, dynamic>;

              // Format the data to a consistent structure
              return {
                'id': historyDoc.id,
                'timestamp': data[
                    'change_time'], // Keep original timestamp for sorting and display
                'new_gate': data['new_gate'] ?? '-',
                'old_gate': data['old_gate'] ?? '-',
              };
            }).toList();

            // Filter history items if cutoff time is available
            if (cutoffTime != null) {
              gateHistory = gateHistory.where((item) {
                // Convert timestamp to DateTime
                final timestamp = item['timestamp'];
                DateTime? changeTime;

                try {
                  if (timestamp is Timestamp) {
                    changeTime = timestamp.toDate();
                  } else if (timestamp is String) {
                    changeTime = DateTime.parse(timestamp);
                  } else if (timestamp != null) {
                    print(
                        'LOG: Unexpected timestamp type: ${timestamp.runtimeType}');
                  }
                } catch (e) {
                  print('LOG ERROR: Failed to convert timestamp: $e');
                  return false;
                }

                // Si no se pudo convertir el timestamp, omitir este registro
                if (changeTime == null) return false;

                // Compare with cutoff time
                return changeTime.isAfter(cutoffTime!);
              }).toList();

              print(
                  'LOG: Filtered to ${gateHistory.length} gate history records after cutoff time');
            }
          }
        }

        print('LOG: Loaded ${gateHistory.length} gate history records for UI');
        print(
            'LOG: Loaded ${fullHistory.length} complete history records for debug');
      } catch (historyError) {
        print('LOG ERROR: Error loading history subcollection: $historyError');
        // Continue with main data even if history fails to load
      }

      // Assign values for the UI
      setState(() {
        _flightDetails = flightData;
        _gateHistory = gateHistory;
        _fullHistory = fullHistory;
        _isLoading = false;
      });

      print('LOG: Flight details loaded successfully');
      print('LOG: Gate change history: ${_gateHistory.length} records');
      print('LOG: Full history: ${_fullHistory.length} records');
    } catch (e) {
      print('LOG: Error loading flight details: $e');
      setState(() {
        _errorMessage = 'Error loading details: $e';
        _isLoading = false;
      });
    }
  }

  /// Imprime información de debug sobre la navegación entre vuelos
  void _debugSwipeInfo() {
    print('LOG: SwipeInfo - Current Flight ID: ${widget.flightId}');
    print('LOG: SwipeInfo - Document ID: ${widget.documentId}');
    print('LOG: SwipeInfo - Source: ${widget.flightsSource}');
    print('LOG: SwipeInfo - Has Flights List: ${widget.flightsList != null}');

    if (widget.flightsList != null) {
      final int flightsCount = widget.flightsList!.length;
      print('LOG: SwipeInfo - Flights Count: $flightsCount');

      // Verificar si el vuelo actual está en la lista
      final int index = widget.flightsList!
          .indexWhere((flight) => flight['id'] == widget.documentId);
      if (index != -1) {
        print('LOG: SwipeInfo - Current Flight Index: $index');
      } else {
        // Intentar encontrar por flight_ref (para MyDepartures)
        final int refIndex = widget.flightsList!.indexWhere((flight) =>
            (flight['flight_ref'] != null &&
                flight['flight_ref'] == widget.documentId) ||
            (flight['doc_id'] != null &&
                flight['doc_id'] == widget.documentId));

        if (refIndex != -1) {
          print('LOG: SwipeInfo - Current Flight Index (by ref): $refIndex');
        } else {
          print('LOG: SwipeInfo - WARNING: Current flight not found in list!');
        }
      }
    }
  }

  /// Obtiene el índice del vuelo actual en la lista
  int _getCurrentFlightIndex() {
    if (flightsList.isEmpty) return -1;

    // Buscar por id
    int index =
        flightsList.indexWhere((flight) => flight['id'] == widget.documentId);

    // Si no se encuentra, buscar por flight_ref (para MyDepartures)
    if (index == -1) {
      index = flightsList.indexWhere((flight) =>
          (flight['flight_ref'] != null &&
              flight['flight_ref'] == widget.documentId) ||
          (flight['doc_id'] != null && flight['doc_id'] == widget.documentId));
    }

    return index;
  }

  /// Obtiene el índice del vuelo adyacente en la dirección especificada
  int _getAdjacentFlightIndex(bool isNext) {
    final currentIndex = _getCurrentFlightIndex();
    if (currentIndex == -1 || flightsList.isEmpty) return -1;

    if (isNext) {
      return (currentIndex + 1) % flightsList.length;
    } else {
      return (currentIndex - 1 + flightsList.length) % flightsList.length;
    }
  }

  /// Precargar detalles del vuelo adyacente
  Future<void> _preloadAdjacentFlightDetails(bool isNext) async {
    if (flightsList.isEmpty || _loadingAdjacentFlight) return;

    final adjacentIndex = _getAdjacentFlightIndex(isNext);
    if (adjacentIndex == -1) return;

    final adjacentFlight = flightsList[adjacentIndex];
    final String docId = flightsSource == 'my'
        ? (adjacentFlight['flight_ref'] ?? adjacentFlight['id'] ?? '')
        : adjacentFlight['id'];

    print(
        'LOG: Precargando detalles del vuelo ${adjacentFlight['flight_id']} (ID: $docId)');

    _loadingAdjacentFlight = true;

    try {
      // Obtener datos del vuelo adyacente
      final DocumentSnapshot flightDoc =
          await _firestore.collection('flights').doc(docId).get();

      if (!flightDoc.exists) {
        print('LOG: Vuelo adyacente no encontrado');
        _loadingAdjacentFlight = false;
        return;
      }

      if (mounted) {
        setState(() {
          _adjacentFlightDetails = flightDoc.data() as Map<String, dynamic>;
          _loadingAdjacentFlight = false;
        });
      }
    } catch (e) {
      print('LOG: Error precargando vuelo adyacente: $e');
      _loadingAdjacentFlight = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Flight ${widget.flightId}'),
            Text(
              'ID: ${widget.documentId}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadFlightDetails,
            tooltip: 'Refresh data',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadFlightDetails,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : buildSwipeableContent(
                  FlightDetailsUI(
                    flightDetails: _flightDetails!,
                    gateHistory: _gateHistory,
                    fullHistory: _fullHistory,
                    onRefresh: _loadFlightDetails,
                    documentId: widget.documentId,
                    canSwipe: widget.flightsList != null &&
                        widget.flightsList!.isNotEmpty,
                    onSwipe: _handleSwipe,
                    onDragStart: _handleDragStart,
                    adjacentFlightDetails: _adjacentFlightDetails,
                  ),
                ),
    );
  }

  /// Maneja el evento de swipe y navega al vuelo correspondiente
  void _handleSwipe(DragEndDetails details) {
    // La velocidad horizontal determina la dirección del swipe
    final velocity = details.velocity.pixelsPerSecond.dx;

    // Si es positivo, swipe hacia la derecha (vuelo anterior)
    // Si es negativo, swipe hacia la izquierda (siguiente vuelo)
    final isNext = velocity < 0;

    // Usar el servicio de navegación para ir al vuelo adyacente
    SwipeableFlightsService.navigateToAdjacentFlight(
      context: context,
      currentFlightDocId: currentFlightDocId,
      flightsList: flightsList,
      isNext: isNext,
      flightsSource: flightsSource,
    );
  }

  /// Maneja el inicio de arrastre y precarga el vuelo adyacente
  void _handleDragStart(DragStartDetails details, bool isRightDirection) {
    // Precargar el vuelo en la dirección del arrastre
    _preloadAdjacentFlightDetails(
        !isRightDirection); // isRightDirection es true cuando arrastramos hacia la derecha
  }
}
