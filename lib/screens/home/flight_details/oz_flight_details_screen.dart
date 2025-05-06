import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'oz_flight_details_ui.dart';
import '../../../services/navigation/swipeable_flight_details.dart';
import '../../../services/navigation/swipeable_flights_service.dart';

/// Component that handles the logic and data for the oversize flight details screen
/// Gets detailed data of a specific flight from Firestore for oversize baggage management
class OzFlightDetailsScreen extends StatefulWidget {
  final String flightId;
  final String documentId;
  final List<Map<String, dynamic>>? flightsList;
  final String? flightsSource; // 'all' o 'my' para saber de dónde viene
  final bool
      forceRefreshOnReturn; // Indica si debe forzarse una actualización al volver

  const OzFlightDetailsScreen({
    required this.flightId,
    required this.documentId,
    this.flightsList,
    this.flightsSource,
    this.forceRefreshOnReturn = false,
    super.key,
  });

  @override
  State<OzFlightDetailsScreen> createState() => _OzFlightDetailsScreenState();
}

class _OzFlightDetailsScreenState extends State<OzFlightDetailsScreen>
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

  // Métodos necesarios para implementar la funcionalidad de swipe
  // Estos métodos deberían implementarse en el mixin, pero los definimos aquí para resolver los errores

  /// Verifica si es posible navegar entre vuelos (necesita al menos 2 vuelos en la lista)
  bool canSwipeThroughFlights() {
    return flightsList.length >= 2;
  }

  /// Obtiene el ID del documento del vuelo siguiente en la lista
  String? getNextFlight(String currentDocId) {
    if (!canSwipeThroughFlights()) return null;

    // Encontrar el índice del vuelo actual
    final currentIndex = findFlightIndex(currentDocId);
    if (currentIndex == -1) return null;

    // Calcular el índice del siguiente vuelo
    // Para my_departures la dirección se invierte
    int targetIndex;
    if (flightsSource == 'my') {
      targetIndex = currentIndex - 1;
      if (targetIndex < 0) return null; // No hay vuelos anteriores
    } else {
      targetIndex = currentIndex + 1;
      if (targetIndex >= flightsList.length) return null; // No hay más vuelos
    }

    // Devolver el ID del documento del vuelo objetivo
    return getDocIdFromFlightItem(flightsList[targetIndex]);
  }

  /// Obtiene el ID del documento del vuelo anterior en la lista
  String? getPreviousFlight(String currentDocId) {
    if (!canSwipeThroughFlights()) return null;

    // Encontrar el índice del vuelo actual
    final currentIndex = findFlightIndex(currentDocId);
    if (currentIndex == -1) return null;

    // Calcular el índice del vuelo anterior
    // Para my_departures la dirección se invierte
    int targetIndex;
    if (flightsSource == 'my') {
      targetIndex = currentIndex + 1;
      if (targetIndex >= flightsList.length) return null; // No hay más vuelos
    } else {
      targetIndex = currentIndex - 1;
      if (targetIndex < 0) return null; // No hay vuelos anteriores
    }

    // Devolver el ID del documento del vuelo objetivo
    return getDocIdFromFlightItem(flightsList[targetIndex]);
  }

  /// Encuentra el índice de un vuelo en la lista de vuelos
  int findFlightIndex(String docId) {
    // Buscar primero por id directo
    int index = flightsList.indexWhere((flight) => flight['id'] == docId);

    // Si no se encuentra, intentar con otros campos
    if (index == -1) {
      index = flightsList.indexWhere((flight) =>
          (flight['flight_ref'] != null && flight['flight_ref'] == docId) ||
          (flight['doc_id'] != null && flight['doc_id'] == docId));
    }

    return index;
  }

  /// Obtiene el ID del documento de un elemento de la lista de vuelos
  String getDocIdFromFlightItem(Map<String, dynamic> flightItem) {
    // Identificar el ID del documento según el origen de los datos
    return flightsSource == 'my'
        ? (flightItem['flight_ref'] ?? flightItem['id'] ?? '')
        : flightItem['id'];
  }

  @override
  void initState() {
    super.initState();
    _loadFlightDetails();
    _debugSwipeInfo();
  }

  /// Logs swipe-related debug information
  void _debugSwipeInfo() {
    print('LOG: OzFlightDetailsScreen._debugSwipeInfo');
    print('LOG: Current Doc ID: $currentFlightDocId');
    print('LOG: Flights List Size: ${flightsList.length}');
    print('LOG: Can Swipe: ${canSwipeThroughFlights()}');
    if (canSwipeThroughFlights()) {
      print('LOG: Previous Flight: ${getPreviousFlight(currentFlightDocId)}');
      print('LOG: Next Flight: ${getNextFlight(currentFlightDocId)}');
    }
  }

  /// Loads the complete flight details from Firestore
  Future<void> _loadFlightDetails() async {
    print('LOG: OZ: Loading flight details for ${widget.flightId}...');

    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // Get the flight document using its ID
      final DocumentSnapshot flightDoc =
          await _firestore.collection('flights').doc(widget.documentId).get();

      if (!flightDoc.exists) {
        print('LOG: OZ: Flight with ID ${widget.documentId} not found');
        setState(() {
          _errorMessage = 'No data found for this flight';
          _isLoading = false;
        });
        return;
      }

      // Convert data to Map
      final Map<String, dynamic> flightData =
          flightDoc.data() as Map<String, dynamic>;

      print('LOG: OZ: Flight data loaded: ${flightData.keys.toList()}');

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
              'LOG: OZ: Schedule time: $scheduleDateTime, Cutoff time: $cutoffTime');
        }
      } catch (timeError) {
        print('LOG: OZ: Error calculating cutoff time: $timeError');
        // If there's an error, we'll continue without filtering
      }

      // Load gate change history from the 'history' subcollection
      List<Map<String, dynamic>> gateHistory = [];
      List<Map<String, dynamic>> fullHistory = [];

      try {
        print(
            'LOG: OZ: Checking for history subcollection at path: flights/${widget.documentId}/history');

        // Primero verificar si la colección history existe
        final collectionRef = _firestore
            .collection('flights')
            .doc(widget.documentId)
            .collection('history');

        // Intentar obtener un solo documento para verificar si la colección existe
        final testQuery = await collectionRef.limit(1).get();

        if (testQuery.docs.isEmpty) {
          print('LOG: OZ: History subcollection is empty or does not exist');
          // No hay historial, dejar las listas vacías
        } else {
          print(
              'LOG: OZ: History subcollection exists, retrieving all documents');

          // La subcolección existe, obtener todos los documentos
          final QuerySnapshot historySnapshot = await collectionRef
              .orderBy('change_time', descending: true)
              .get();

          print(
              'LOG: OZ: Retrieved ${historySnapshot.docs.length} history documents from Firestore');

          // Process each history document - extract full history first
          if (historySnapshot.docs.isNotEmpty) {
            // Obtener historial completo de todos los documentos
            fullHistory = historySnapshot.docs.map((historyDoc) {
              final String id = historyDoc.id;
              final Map<String, dynamic> data =
                  historyDoc.data() as Map<String, dynamic>;

              // Añadir el ID del documento al mapa de datos
              return {
                'id': id,
                ...data, // Incluir todos los campos originales
              };
            }).toList();

            print(
                'LOG: OZ: Loaded ${fullHistory.length} complete history records with fields');

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
                        'LOG: OZ: Unexpected timestamp type: ${timestamp.runtimeType}');
                  }
                } catch (e) {
                  print('LOG: OZ ERROR: Failed to convert timestamp: $e');
                  return false;
                }

                // Si no se pudo convertir el timestamp, omitir este registro
                if (changeTime == null) return false;

                // Compare with cutoff time
                return changeTime.isAfter(cutoffTime!);
              }).toList();

              print(
                  'LOG: OZ: Filtered gate history to ${gateHistory.length} items after cutoff time');
            }
          }
        }
      } catch (historyError) {
        print('LOG: OZ ERROR: Error loading history: $historyError');
      }

      // Set state with loaded data
      setState(() {
        _flightDetails = flightData;
        _gateHistory = gateHistory;
        _fullHistory = fullHistory;
        _isLoading = false;
      });

      // If we can swipe through flights, preload adjacent flight
      if (canSwipeThroughFlights()) {
        _preloadAdjacentFlight(getNextFlight(currentFlightDocId));
      }
    } catch (e) {
      print('LOG: OZ ERROR: Error loading flight details: $e');
      setState(() {
        _errorMessage = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  /// Preloads the adjacent flight details for smoother swiping
  Future<void> _preloadAdjacentFlight(String? adjacentFlightDocId) async {
    if (adjacentFlightDocId == null) {
      print('LOG: OZ: No adjacent flight to preload');
      return;
    }

    if (_loadingAdjacentFlight) {
      print('LOG: OZ: Already loading adjacent flight, skipping');
      return;
    }

    try {
      print('LOG: OZ: Preloading adjacent flight: $adjacentFlightDocId');
      _loadingAdjacentFlight = true;

      final DocumentSnapshot adjacentFlightDoc =
          await _firestore.collection('flights').doc(adjacentFlightDocId).get();

      if (!adjacentFlightDoc.exists) {
        print('LOG: OZ: Adjacent flight not found');
        _adjacentFlightDetails = null;
        _loadingAdjacentFlight = false;
        return;
      }

      final Map<String, dynamic> adjacentFlightData =
          adjacentFlightDoc.data() as Map<String, dynamic>;

      if (mounted) {
        setState(() {
          _adjacentFlightDetails = adjacentFlightData;
          _loadingAdjacentFlight = false;
        });
      } else {
        _adjacentFlightDetails = adjacentFlightData;
        _loadingAdjacentFlight = false;
      }

      print('LOG: OZ: Adjacent flight preloaded successfully');
    } catch (e) {
      print('LOG: OZ ERROR: Error preloading adjacent flight: $e');
      _loadingAdjacentFlight = false;
    }
  }

  /// Handles swipe to navigate to next/previous flight
  void _handleSwipe(DragEndDetails details) {
    if (!canSwipeThroughFlights()) {
      print('LOG: OZ: Cannot swipe through flights');
      return;
    }

    // Si el gesto va de derecha a izquierda (velocidad negativa), mostrar el siguiente vuelo
    // Si el gesto va de izquierda a derecha (velocidad positiva), mostrar el vuelo anterior
    final bool isNext = details.velocity.pixelsPerSecond.dx < 0;
    print('LOG: OZ: Swipe detected, isNext: $isNext');

    final String? targetDocId = isNext
        ? getNextFlight(currentFlightDocId)
        : getPreviousFlight(currentFlightDocId);

    if (targetDocId == null) {
      print(
          'LOG: OZ: No ${isNext ? 'next' : 'previous'} flight to navigate to');
      return;
    }

    print(
        'LOG: OZ: Navigating to ${isNext ? 'next' : 'previous'} flight: $targetDocId');

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => OzFlightDetailsScreen(
          flightId: '', // Este valor se llenará después de cargar los datos
          documentId: targetDocId,
          flightsList: flightsList,
          flightsSource: flightsSource,
        ),
      ),
    );
  }

  /// Notifies the direction of the swipe for preloading
  void _notifySwipeDirection(bool isNext) {
    print('LOG: OZ: Swipe direction changed, isNext: $isNext');
    final String? targetDocId = isNext
        ? getNextFlight(currentFlightDocId)
        : getPreviousFlight(currentFlightDocId);

    if (targetDocId != null) {
      _preloadAdjacentFlight(targetDocId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flight Details (Oversize)'),
        backgroundColor: const Color(0xFFfe8b02),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.red,
                        size: 60,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadFlightDetails,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _flightDetails != null
                  ? OzFlightDetailsUI(
                      flightDetails: _flightDetails!,
                      gateHistory: _gateHistory,
                      fullHistory: _fullHistory,
                      onRefresh: _loadFlightDetails,
                      documentId: widget.documentId,
                      canSwipe: canSwipeThroughFlights(),
                      onSwipe: _handleSwipe,
                      onSwipeDirectionChanged: _notifySwipeDirection,
                      adjacentFlightDetails: _adjacentFlightDetails,
                    )
                  : const Center(
                      child: Text('No flight data available'),
                    ),
    );
  }
}
