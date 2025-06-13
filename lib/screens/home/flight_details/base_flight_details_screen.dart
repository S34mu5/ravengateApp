import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../services/navigation/swipeable_flight_details.dart';
import '../../../utils/flight_sort_util.dart';
import '../../../utils/logger.dart';

/// Clase base abstracta que contiene la lógica común para las pantallas de detalles de vuelo
abstract class BaseFlightDetailsScreen extends StatefulWidget {
  final String flightId;
  final String documentId;
  final List<Map<String, dynamic>>? flightsList;
  final String? flightsSource; // 'all' o 'my' para saber de dónde viene
  final bool
      forceRefreshOnReturn; // Indica si debe forzarse una actualización al volver

  const BaseFlightDetailsScreen({
    required this.flightId,
    required this.documentId,
    this.flightsList,
    this.flightsSource,
    this.forceRefreshOnReturn = false,
    super.key,
  });
}

/// Estado base abstracto que contiene la lógica común para las pantallas de detalles de vuelo
abstract class BaseFlightDetailsScreenState<T extends BaseFlightDetailsScreen>
    extends State<T> with SwipeableFlightDetails {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  Map<String, dynamic>? flightDetails;
  List<Map<String, dynamic>> gateHistory = [];
  List<Map<String, dynamic>> fullHistory = [];
  bool isLoading = true;
  String? errorMessage;

  // Variables para el vuelo adyacente
  Map<String, dynamic>? adjacentFlightDetails;
  bool loadingAdjacentFlight = false;

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
    loadFlightDetails();
    debugSwipeInfo();
  }

  /// Imprime información de debug sobre la navegación entre vuelos
  void debugSwipeInfo() {
    AppLogger.debug('SwipeInfo - Current Flight ID: ${widget.flightId}');
    AppLogger.debug('SwipeInfo - Document ID: ${widget.documentId}');
    AppLogger.debug('SwipeInfo - Source: ${widget.flightsSource}');
    AppLogger.debug(
        'SwipeInfo - Has Flights List: ${widget.flightsList != null}');

    if (widget.flightsList != null) {
      final int flightsCount = widget.flightsList!.length;
      AppLogger.debug('SwipeInfo - Flights Count: $flightsCount');

      // Verificar si el vuelo actual está en la lista
      final int index = widget.flightsList!
          .indexWhere((flight) => flight['id'] == widget.documentId);
      if (index != -1) {
        AppLogger.debug('SwipeInfo - Current Flight Index: $index');
      } else {
        // Intentar encontrar por flight_ref (para MyDepartures)
        final int refIndex = widget.flightsList!.indexWhere((flight) =>
            (flight['flight_ref'] != null &&
                flight['flight_ref'] == widget.documentId) ||
            (flight['doc_id'] != null &&
                flight['doc_id'] == widget.documentId));

        if (refIndex != -1) {
          AppLogger.debug(
              'SwipeInfo - Current Flight Index (by ref): $refIndex');
        } else {
          AppLogger.warning(
              'SwipeInfo - WARNING: Current flight not found in list');
        }
      }
    }
  }

  /// Verifica si es posible navegar entre vuelos (necesita al menos 2 vuelos en la lista)
  bool canSwipeThroughFlights() {
    return flightsList.length >= 2;
  }

  /// Método para obtener el ID del documento del vuelo siguiente en la lista
  String? getNextFlight(String currentDocId) {
    if (!canSwipeThroughFlights()) return null;

    // Ordenar la lista de vuelos usando el utilitario común
    final sortedFlights = FlightSortUtil.sortFlightsByTime(flightsList);

    // Encontrar el índice del siguiente vuelo
    final nextIndex = FlightSortUtil.findNextFlightIndex(
        sortedFlights, currentDocId, flightsSource);

    if (nextIndex == -1) return null;

    // Obtener el ID del documento del vuelo objetivo
    return getDocIdFromFlightItem(sortedFlights[nextIndex]);
  }

  /// Obtiene el ID del documento del vuelo anterior en la lista
  String? getPreviousFlight(String currentDocId) {
    if (!canSwipeThroughFlights()) return null;

    // Ordenar la lista de vuelos usando el utilitario común
    final sortedFlights = FlightSortUtil.sortFlightsByTime(flightsList);

    // Encontrar el índice del vuelo anterior
    final prevIndex = FlightSortUtil.findPreviousFlightIndex(
        sortedFlights, currentDocId, flightsSource);

    if (prevIndex == -1) return null;

    // Obtener el ID del documento del vuelo objetivo
    return getDocIdFromFlightItem(sortedFlights[prevIndex]);
  }

  /// Obtiene el ID del documento de un elemento de la lista de vuelos
  String getDocIdFromFlightItem(Map<String, dynamic> flightItem) {
    // Identificar el ID del documento según el origen de los datos
    return flightsSource == 'my'
        ? (flightItem['flight_ref'] ?? flightItem['id'] ?? '')
        : flightItem['id'];
  }

  /// Loads the complete flight details from Firestore
  Future<void> loadFlightDetails() async {
    final String screenName = getScreenName();
    AppLogger.debug(
        '$screenName: Loading flight details for ${widget.flightId}');

    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      // Get the flight document using its ID
      final DocumentSnapshot flightDoc =
          await firestore.collection('flights').doc(widget.documentId).get();

      if (!flightDoc.exists) {
        AppLogger.warning(
            '$screenName: Flight with ID ${widget.documentId} not found');
        setState(() {
          errorMessage = 'No data found for this flight';
          isLoading = false;
        });
        return;
      }

      // Convert data to Map
      final Map<String, dynamic> flightData =
          flightDoc.data() as Map<String, dynamic>;

      AppLogger.debug(
          '$screenName: Flight data loaded: ${flightData.keys.toList()}');

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

          AppLogger.debug(
              '$screenName: Schedule=$scheduleDateTime, Cutoff=$cutoffTime');
        }
      } catch (timeError) {
        AppLogger.error(
            '$screenName: Error calculating cutoff time', timeError);
        // If there's an error, we'll continue without filtering
      }

      // Load gate change history from the 'history' subcollection
      List<Map<String, dynamic>> gateHistoryTemp = [];
      List<Map<String, dynamic>> fullHistoryTemp = [];

      try {
        AppLogger.debug(
            '$screenName: Checking history subcollection flights/${widget.documentId}/history');

        // Primero verificar si la colección history existe
        final collectionRef = firestore
            .collection('flights')
            .doc(widget.documentId)
            .collection('history');

        // Intentar obtener un solo documento para verificar si la colección existe
        final testQuery = await collectionRef.limit(1).get();

        if (testQuery.docs.isEmpty) {
          AppLogger.info('$screenName: History subcollection empty or missing');
          // No hay historial, dejar las listas vacías
        } else {
          AppLogger.debug(
              '$screenName: History subcollection exists, retrieving');

          // La subcolección existe, obtener todos los documentos
          final QuerySnapshot historySnapshot = await collectionRef
              .orderBy('change_time', descending: true)
              .get();

          AppLogger.debug(
              '$screenName: Retrieved ${historySnapshot.docs.length} history documents');

          // Process each history document - extract full history first
          if (historySnapshot.docs.isNotEmpty) {
            // Obtener historial completo de todos los documentos
            fullHistoryTemp = historySnapshot.docs.map((historyDoc) {
              final String id = historyDoc.id;
              final Map<String, dynamic> data =
                  historyDoc.data() as Map<String, dynamic>;

              // Añadir el ID del documento al mapa de datos
              return {
                'id': id,
                ...data, // Incluir todos los campos originales
              };
            }).toList();

            AppLogger.debug(
                '$screenName: Loaded ${fullHistoryTemp.length} full history records');

            // Procesar historial de cambios de puerta (compatible con el código existente)
            gateHistoryTemp = historySnapshot.docs.map((historyDoc) {
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
              gateHistoryTemp = gateHistoryTemp.where((item) {
                // Convert timestamp to DateTime
                final timestamp = item['timestamp'];
                DateTime? changeTime;

                try {
                  if (timestamp is Timestamp) {
                    changeTime = timestamp.toDate();
                  } else if (timestamp is String) {
                    changeTime = DateTime.parse(timestamp);
                  } else if (timestamp != null) {
                    AppLogger.debug(
                        '$screenName: Unexpected timestamp type: ${timestamp.runtimeType}');
                  }
                } catch (e) {
                  AppLogger.error(
                      '$screenName: Failed to convert timestamp', e);
                  return false;
                }

                // Si no se pudo convertir el timestamp, omitir este registro
                if (changeTime == null) return false;

                // Compare with cutoff time
                return changeTime.isAfter(cutoffTime!);
              }).toList();

              AppLogger.debug(
                  '$screenName: Filtered to ${gateHistoryTemp.length} gate history records after cutoff');
            }
          }
        }
      } catch (historyError) {
        AppLogger.error(
            '$screenName: Error loading history subcollection', historyError);
        // Continue with main data even if history fails to load
      }

      // Assign values for the UI
      setState(() {
        flightDetails = flightData;
        gateHistory = gateHistoryTemp;
        fullHistory = fullHistoryTemp;
        isLoading = false;
      });

      AppLogger.debug('$screenName: Flight details loaded');
      AppLogger.debug(
          '$screenName: Gate change history: ${gateHistory.length}');
      AppLogger.debug('$screenName: Full history: ${fullHistory.length}');

      // Hook para procesamiento específico por subclase después de cargar datos
      onFlightDetailsLoaded();
    } catch (e) {
      AppLogger.error('$screenName: Error loading flight details', e);
      setState(() {
        errorMessage = 'Error loading details: $e';
        isLoading = false;
      });
    }
  }

  /// Handles swipe actions based on the provided end details
  void handleSwipe(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    final bool isNext = velocity < 0; // true if right to left swipe

    // Only process swipe if velocity is sufficient
    if (velocity.abs() > 500) {
      AppLogger.debug('Swipe detected velocity=$velocity');
      navigateToAdjacentFlight(isNext);
    }
  }

  /// Updates the adjacent flight details based on swipe direction
  void handleSwipeDirectionChange(bool isNext) {
    // Do not load if we're at the edge of the list
    if (checkIfAtEdgeOfList(isNext)) {
      return;
    }

    // Load the adjacent flight details in background
    loadAdjacentFlightDetails(isNext);
  }

  /// Loads the details of the adjacent flight in the specified direction
  Future<void> loadAdjacentFlightDetails(bool isNext) async {
    if (flightsList.isEmpty || loadingAdjacentFlight) {
      return;
    }

    // Ordenar la lista de vuelos usando el utilitario compartido
    final sortedFlights = FlightSortUtil.sortFlightsByTime(flightsList);

    // Encontrar el índice del vuelo actual
    int currentIndex = -1;
    for (int i = 0; i < sortedFlights.length; i++) {
      final flight = sortedFlights[i];
      final String id = flightsSource == 'my'
          ? (flight['flight_ref'] ?? flight['id'] ?? '')
          : flight['id'];

      if (id == currentFlightDocId) {
        currentIndex = i;
        break;
      }
    }

    if (currentIndex == -1) {
      return;
    }

    // Calcular índice adyacente según la dirección
    int adjacentIndex = isNext ? currentIndex + 1 : currentIndex - 1;

    // Verificar índice válido
    if (adjacentIndex < 0 || adjacentIndex >= sortedFlights.length) {
      return;
    }

    // Obtener datos del vuelo adyacente
    final adjacentFlight = sortedFlights[adjacentIndex];
    final String docId = flightsSource == 'my'
        ? (adjacentFlight['flight_ref'] ?? adjacentFlight['id'] ?? '')
        : adjacentFlight['id'];

    AppLogger.debug('Precargando detalles vuelo ID=$docId');

    setState(() {
      loadingAdjacentFlight = true;
    });

    try {
      // Get flight document
      final DocumentSnapshot flightDoc =
          await firestore.collection('flights').doc(docId).get();

      if (!flightDoc.exists) {
        AppLogger.info('Vuelo adyacente no encontrado');
        if (mounted) {
          setState(() {
            loadingAdjacentFlight = false;
          });
        }
        return;
      }

      if (mounted) {
        setState(() {
          adjacentFlightDetails = flightDoc.data() as Map<String, dynamic>;
          loadingAdjacentFlight = false;
        });
      }
    } catch (e) {
      AppLogger.error('Error precargando vuelo adyacente', e);
      if (mounted) {
        setState(() {
          loadingAdjacentFlight = false;
        });
      }
    }
  }

  /// Checks if we're at the edge of the flight list
  bool checkIfAtEdgeOfList(bool isNext) {
    if (flightsList.isEmpty) {
      return true;
    }

    // Ordenar la lista de vuelos usando el utilitario compartido
    final sortedFlights = FlightSortUtil.sortFlightsByTime(flightsList);

    // Encontrar la posición actual
    int currentIndex = -1;
    for (int i = 0; i < sortedFlights.length; i++) {
      final flight = sortedFlights[i];
      final String id = flightsSource == 'my'
          ? (flight['flight_ref'] ?? flight['id'] ?? '')
          : flight['id'];

      if (id == currentFlightDocId) {
        currentIndex = i;
        break;
      }
    }

    if (currentIndex == -1) {
      return true; // No se encontró el vuelo actual
    }

    // Verificar si estamos en el borde de la lista
    if (isNext && currentIndex >= sortedFlights.length - 1) {
      return true; // Ya estamos en el último vuelo
    }

    if (!isNext && currentIndex <= 0) {
      return true; // Ya estamos en el primer vuelo
    }

    return false; // No estamos en el borde
  }

  /// Navigate to adjacent flight
  void navigateToAdjacentFlight(bool isNext) {
    if (flightsList.isEmpty) {
      AppLogger.warning('No se puede navegar - lista de vuelos vacía');
      return;
    }

    // Indicar que debe forzar actualización al volver si la fuente es my_departures
    final bool shouldForceRefresh = flightsSource == 'my';

    // Obtener el destino del vuelo
    final String? targetDocId = isNext
        ? getNextFlight(currentFlightDocId)
        : getPreviousFlight(currentFlightDocId);

    if (targetDocId == null) {
      AppLogger.info(
          'No hay ${isNext ? "siguiente" : "anterior"} vuelo disponible');
      return;
    }

    // Navegar al vuelo adyacente
    final Widget targetScreen = buildAdjacentFlightScreen(
      flightId: '', // Se actualizará después de cargar los datos
      documentId: targetDocId,
      flightsList: flightsList,
      flightsSource: flightsSource,
      forceRefreshOnReturn: shouldForceRefresh,
    );

    // Usar Navigator para navegar a la nueva pantalla
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => targetScreen),
    );
  }

  /// Método abstracto para obtener el nombre de la pantalla (para logs)
  String getScreenName();

  /// Método abstracto para construir una pantalla adyacente
  Widget buildAdjacentFlightScreen({
    required String flightId,
    required String documentId,
    required List<Map<String, dynamic>> flightsList,
    required String flightsSource,
    bool forceRefreshOnReturn = false,
  });

  /// Hook para acciones después de cargar datos (puede ser sobreescrito por subclases)
  void onFlightDetailsLoaded() {
    // Por defecto no hace nada, las subclases pueden sobreescribir
  }

  /// Método abstracto para construir el contenido principal
  Widget buildContent();

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      // Devolver true al salir para indicar que es necesario actualizar datos
      onWillPop: () async {
        // Forzar actualización solo si es necesario
        final bool shouldForceRefresh =
            widget.forceRefreshOnReturn || widget.flightsSource == 'my';

        if (shouldForceRefresh) {
          AppLogger.debug('Forzando actualización de datos al volver');
          Navigator.of(context)
              .pop(true); // Retornar true para forzar actualización
          return false; // No ejecutar el pop nativo ya que lo hicimos manualmente
        }
        return true; // Ejecutar pop normal
      },
      child: buildContent(),
    );
  }
}
