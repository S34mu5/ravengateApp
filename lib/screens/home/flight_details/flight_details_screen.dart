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
  final bool
      forceRefreshOnReturn; // Indica si debe forzarse una actualización al volver

  const FlightDetailsScreen({
    required this.flightId,
    required this.documentId,
    this.flightsList,
    this.flightsSource,
    this.forceRefreshOnReturn = false,
    super.key,
  });

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

      print('LOG: Flight data loaded: ${flightData.keys.toList()}');

      // Log trolley information if available
      if (flightData.containsKey('trolleys_at_gate')) {
        print(
            'LOG: Trolleys at gate info found: ${flightData['trolleys_at_gate']}');
      } else {
        print('LOG: No trolleys at gate information available');

        // Verificar la subcolección 'trolleys'
        try {
          final trolleysSnapshot = await _firestore
              .collection('flights')
              .doc(widget.documentId)
              .collection('trolleys')
              .orderBy('timestamp', descending: true)
              .limit(1)
              .get();

          print(
              'LOG: Trolleys subcollection check - ${trolleysSnapshot.docs.length} documents found');
        } catch (e) {
          print('LOG ERROR: Failed to check trolleys subcollection: $e');
        }
      }

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

  /// Handles swipe actions based on the provided end details
  void _handleSwipe(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    final bool isNext = velocity < 0; // true if right to left swipe

    // Only process swipe if velocity is sufficient
    if (velocity.abs() > 500) {
      print('LOG: Swipe detected with velocity: $velocity');
      _navigateToAdjacentFlight(isNext);
    }
  }

  /// Updates the adjacent flight details based on swipe direction
  void _handleSwipeDirectionChange(bool isNext) {
    // Do not load if we're at the edge of the list
    if (_checkIfAtEdgeOfList(isNext)) {
      return;
    }

    // Load the adjacent flight details in background
    _loadAdjacentFlightDetails(isNext);
  }

  /// Loads the details of the adjacent flight in the specified direction
  Future<void> _loadAdjacentFlightDetails(bool isNext) async {
    if (widget.flightsList == null ||
        widget.flightsList!.isEmpty ||
        _loadingAdjacentFlight) {
      return;
    }

    // Find the current index
    int currentIndex = widget.flightsList!
        .indexWhere((flight) => flight['id'] == widget.documentId);

    if (currentIndex == -1) {
      currentIndex = widget.flightsList!.indexWhere((flight) =>
          (flight['flight_ref'] != null &&
              flight['flight_ref'] == widget.documentId) ||
          (flight['doc_id'] != null && flight['doc_id'] == widget.documentId));
    }

    if (currentIndex == -1) {
      return;
    }

    // Calculate adjacent index based on the source and direction
    int adjacentIndex;
    if (widget.flightsSource == 'my') {
      // For my_departures the logic is reversed
      adjacentIndex = isNext ? currentIndex - 1 : currentIndex + 1;
    } else {
      // For all_departures
      adjacentIndex = isNext ? currentIndex + 1 : currentIndex - 1;
    }

    // Check valid index
    if (adjacentIndex < 0 || adjacentIndex >= widget.flightsList!.length) {
      return;
    }

    // Get adjacent flight data
    final adjacentFlight = widget.flightsList![adjacentIndex];
    final String docId = widget.flightsSource == 'my'
        ? (adjacentFlight['flight_ref'] ?? adjacentFlight['id'] ?? '')
        : adjacentFlight['id'];

    print('LOG: Precargando detalles del vuelo (ID: $docId)');

    setState(() {
      _loadingAdjacentFlight = true;
    });

    try {
      // Get flight document
      final DocumentSnapshot flightDoc =
          await _firestore.collection('flights').doc(docId).get();

      if (!flightDoc.exists) {
        print('LOG: Vuelo adyacente no encontrado');
        if (mounted) {
          setState(() {
            _loadingAdjacentFlight = false;
          });
        }
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
      if (mounted) {
        setState(() {
          _loadingAdjacentFlight = false;
        });
      }
    }
  }

  /// Checks if we're at the edge of the flight list
  bool _checkIfAtEdgeOfList(bool isNext) {
    if (widget.flightsList == null || widget.flightsList!.isEmpty) {
      return true;
    }

    final currentIndex = widget.flightsList!
        .indexWhere((flight) => flight['id'] == widget.documentId);

    int index = currentIndex;
    if (index == -1) {
      index = widget.flightsList!.indexWhere((flight) =>
          (flight['flight_ref'] != null &&
              flight['flight_ref'] == widget.documentId) ||
          (flight['doc_id'] != null && flight['doc_id'] == widget.documentId));
    }

    if (index == -1) {
      return true;
    }

    if (widget.flightsSource == 'my') {
      // For my_departures the logic is reversed
      if (isNext && index <= 0) {
        return true; // Already at first flight
      }
      if (!isNext && index >= widget.flightsList!.length - 1) {
        return true; // Already at last flight
      }
    } else {
      // For all_departures
      if (isNext && index >= widget.flightsList!.length - 1) {
        return true; // Already at last flight
      }
      if (!isNext && index <= 0) {
        return true; // Already at first flight
      }
    }

    return false;
  }

  /// Navigate to adjacent flight
  void _navigateToAdjacentFlight(bool isNext) {
    if (widget.flightsList != null && widget.flightsList!.isNotEmpty) {
      // Indicar a SwipeableFlightsService que debe forzar actualización al volver
      // solo si la fuente es my_departures
      final bool shouldForceRefresh = widget.flightsSource == 'my';

      SwipeableFlightsService.navigateToAdjacentFlight(
        context: context,
        currentFlightDocId: widget.documentId,
        flightsList: widget.flightsList!,
        isNext: isNext,
        flightsSource: widget.flightsSource ?? 'all',
        forceRefreshOnReturn: shouldForceRefresh,
      );
    } else {
      print('LOG: No se puede navegar - lista de vuelos vacía');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determine if swipe is available
    final bool canSwipe = widget.flightsList != null &&
        widget.flightsList!.isNotEmpty &&
        widget.flightsList!.length > 1;

    // Determinar si necesitamos forzar actualización al volver
    final bool shouldForceRefresh =
        widget.forceRefreshOnReturn || widget.flightsSource == 'my';

    return WillPopScope(
      // Devolver true al salir para indicar que es necesario actualizar datos
      onWillPop: () async {
        // Forzar actualización solo si es necesario
        if (shouldForceRefresh) {
          print(
              'LOG: Forzando actualización de datos al volver a MyDepartures');
          Navigator.of(context).pop(
              true); // Retornar true como resultado para forzar actualización
          return false; // No ejecutar el pop nativo ya que lo hicimos manualmente
        }
        return true; // Ejecutar pop normal
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Flight ${widget.flightId}'),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              // Personalizar el comportamiento del botón de retroceso
              if (shouldForceRefresh) {
                Navigator.of(context).pop(true); // Forzar actualización
              } else {
                Navigator.of(context).pop(); // Comportamiento normal
              }
            },
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadFlightDetails,
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
                ? Center(
                    child: Text(_errorMessage!),
                  )
                : _flightDetails != null
                    ? RefreshIndicator(
                        onRefresh: _loadFlightDetails,
                        child: FlightDetailsUI(
                          flightDetails: _flightDetails!,
                          gateHistory: _gateHistory,
                          fullHistory: _fullHistory,
                          onRefresh: _loadFlightDetails,
                          documentId: widget.documentId,
                          canSwipe: canSwipe,
                          onSwipe: _handleSwipe,
                          onSwipeDirectionChanged: _handleSwipeDirectionChange,
                          adjacentFlightDetails: _adjacentFlightDetails,
                        ),
                      )
                    : const Center(
                        child: Text('No data found for this flight'),
                      ),
      ),
    );
  }
}
