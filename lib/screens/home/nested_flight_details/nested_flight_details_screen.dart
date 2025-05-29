import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../services/navigation/nested_navigation_service.dart';
import '../../../services/location/location_service.dart';
import '../flight_details/flight_details_ui.dart';
import '../flight_details/oz_flight_details_ui.dart';
import '../flight_details/utils/flight_formatters.dart';
import '../../../utils/airline_helper.dart';
import '../../../l10n/app_localizations.dart';

/// Pantalla de detalles de vuelo anidada que mantiene el BottomNavigationBar visible
class NestedFlightDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> flight;
  final List<Map<String, dynamic>> flightsList;
  final String flightsSource;

  const NestedFlightDetailsScreen({
    required this.flight,
    required this.flightsList,
    required this.flightsSource,
    super.key,
  });

  @override
  State<NestedFlightDetailsScreen> createState() =>
      _NestedFlightDetailsScreenState();
}

class _NestedFlightDetailsScreenState extends State<NestedFlightDetailsScreen> {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final NestedNavigationService navigationService = NestedNavigationService();

  Map<String, dynamic>? flightDetails;
  List<Map<String, dynamic>> gateHistory = [];
  List<Map<String, dynamic>> fullHistory = [];
  bool isLoading = true;
  String? errorMessage;

  // Variables para el vuelo adyacente
  Map<String, dynamic>? adjacentFlightDetails;
  bool loadingAdjacentFlight = false;

  @override
  void initState() {
    super.initState();
    loadFlightDetails();

    // Escuchar cambios en el servicio de navegación para detectar cambios de vuelo
    navigationService.addListener(_onNavigationServiceChanged);

    // Registrar callback de refresh para la AppBar principal
    navigationService.registerRefreshCallback(loadFlightDetails);
  }

  @override
  void dispose() {
    navigationService.removeListener(_onNavigationServiceChanged);
    navigationService.unregisterRefreshCallback();
    super.dispose();
  }

  /// Callback que se ejecuta cuando cambia el estado del servicio de navegación
  void _onNavigationServiceChanged() {
    // Si el vuelo actual ha cambiado, recargar los detalles
    final currentFlightData = navigationService.currentFlightData;
    if (currentFlightData != null &&
        currentFlightData['flight_id'] != widget.flight['flight_id']) {
      print(
          'LOG: NestedFlightDetails - Vuelo cambiado, recargando detalles...');

      // Actualizar el estado y recargar detalles
      if (mounted) {
        setState(() {
          flightDetails = null;
          gateHistory = [];
          fullHistory = [];
          isLoading = true;
          errorMessage = null;
        });

        loadFlightDetails();
      }
    }
  }

  /// Parsea un timestamp de schedule_time a DateTime
  DateTime? _parseScheduleTime(String? scheduleTimeStr) {
    if (scheduleTimeStr == null || scheduleTimeStr.isEmpty) return null;

    try {
      return DateTime.parse(scheduleTimeStr);
    } catch (e) {
      print(
          'LOG ERROR: NestedFlightDetails - Error parseando schedule_time: $e');
      return null;
    }
  }

  /// Parsea un timestamp de Firestore a DateTime
  DateTime? _parseTimestamp(dynamic timestamp) {
    if (timestamp == null) return null;

    try {
      if (timestamp is Timestamp) {
        return timestamp.toDate();
      } else if (timestamp is String) {
        return DateTime.parse(timestamp);
      } else if (timestamp is Map && timestamp.containsKey('_seconds')) {
        // Formato de timestamp de Firestore
        final seconds = timestamp['_seconds'] as int;
        final nanoseconds = timestamp['_nanoseconds'] as int? ?? 0;
        return DateTime.fromMillisecondsSinceEpoch(
            seconds * 1000 + (nanoseconds / 1000000).round());
      }
      return null;
    } catch (e) {
      print('LOG ERROR: NestedFlightDetails - Error parseando timestamp: $e');
      return null;
    }
  }

  /// Carga los detalles completos del vuelo desde Firestore
  Future<void> loadFlightDetails() async {
    // Obtener los datos actuales del vuelo desde el servicio de navegación
    final currentFlight = navigationService.currentFlightData ?? widget.flight;
    final currentFlightsSource =
        navigationService.flightsSource ?? widget.flightsSource;

    final String currentDocumentId = currentFlightsSource == 'my'
        ? (currentFlight['flight_ref'] ?? currentFlight['id'] ?? '')
        : currentFlight['id'];

    print(
        'LOG: NestedFlightDetails - Cargando detalles del vuelo: ${currentFlight['flight_id']}');
    print('LOG: NestedFlightDetails - Document ID: $currentDocumentId');

    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      // Obtener el documento del vuelo usando su ID
      final DocumentSnapshot flightDoc =
          await firestore.collection('flights').doc(currentDocumentId).get();

      if (!flightDoc.exists) {
        setState(() {
          errorMessage = 'Vuelo no encontrado';
          isLoading = false;
        });
        return;
      }

      final Map<String, dynamic> flightData =
          flightDoc.data() as Map<String, dynamic>;

      // Cargar historial de cambios de puerta
      List<Map<String, dynamic>> gateHistoryTemp = [];
      List<Map<String, dynamic>> fullHistoryTemp = [];

      try {
        final QuerySnapshot historySnapshot = await firestore
            .collection('flights')
            .doc(currentDocumentId)
            .collection('gate_history')
            .orderBy('timestamp', descending: true)
            .get();

        for (final doc in historySnapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          fullHistoryTemp.add(data);

          // Filtrar solo cambios de puerta para el historial principal
          if (data['field_name'] == 'gate') {
            gateHistoryTemp.add(data);
          }
        }

        // Aplicar filtro de tiempo si es necesario
        if (gateHistoryTemp.isNotEmpty) {
          final String? scheduleTimeStr = flightData['schedule_time'];
          if (scheduleTimeStr != null) {
            final DateTime? scheduleTime = _parseScheduleTime(scheduleTimeStr);

            if (scheduleTime != null) {
              final DateTime cutoffTime =
                  scheduleTime.subtract(const Duration(hours: 2));

              gateHistoryTemp = gateHistoryTemp.where((record) {
                final DateTime? changeTime =
                    _parseTimestamp(record['timestamp']);
                if (changeTime == null) return false;
                return changeTime.isAfter(cutoffTime);
              }).toList();
            }
          }
        }
      } catch (historyError) {
        print(
            'LOG ERROR: NestedFlightDetails - Error cargando historial: $historyError');
      }

      setState(() {
        flightDetails = flightData;
        gateHistory = gateHistoryTemp;
        fullHistory = fullHistoryTemp;
        isLoading = false;
      });

      print('LOG: NestedFlightDetails - Detalles cargados exitosamente');
      print(
          'LOG: NestedFlightDetails - Historial de cambios de puerta: ${gateHistory.length} registros');
    } catch (e) {
      print('LOG ERROR: NestedFlightDetails - Error cargando detalles: $e');
      setState(() {
        errorMessage = 'Error cargando detalles: $e';
        isLoading = false;
      });
    }
  }

  /// Maneja los gestos de swipe
  void handleSwipe(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    final bool isNext = velocity < 0; // true si es swipe de derecha a izquierda

    if (velocity.abs() > 500) {
      print(
          'LOG: NestedFlightDetails - Swipe detectado con velocidad: $velocity');
      navigateToAdjacentFlight(isNext);
    }
  }

  /// Navega al vuelo adyacente
  void navigateToAdjacentFlight(bool isNext) {
    // Obtener datos actuales del servicio de navegación
    final currentFlightsList =
        navigationService.flightsList ?? widget.flightsList;
    final currentFlightsSource =
        navigationService.flightsSource ?? widget.flightsSource;
    final currentFlight = navigationService.currentFlightData ?? widget.flight;

    final String currentDocumentId = currentFlightsSource == 'my'
        ? (currentFlight['flight_ref'] ?? currentFlight['id'] ?? '')
        : currentFlight['id'];

    if (currentFlightsList.isEmpty) {
      print(
          'LOG: NestedFlightDetails - No se puede navegar - lista de vuelos vacía');
      return;
    }

    // Encontrar el índice del vuelo actual
    int currentIndex = -1;
    for (int i = 0; i < currentFlightsList.length; i++) {
      final flight = currentFlightsList[i];
      final String id = currentFlightsSource == 'my'
          ? (flight['flight_ref'] ?? flight['id'] ?? '')
          : flight['id'];

      if (id == currentDocumentId) {
        currentIndex = i;
        break;
      }
    }

    if (currentIndex == -1) {
      print(
          'LOG: NestedFlightDetails - Vuelo actual no encontrado en la lista');
      return;
    }

    // Calcular índice del vuelo objetivo
    int targetIndex;
    if (currentFlightsSource == 'my') {
      // Para my_departures invertir la lógica
      targetIndex = isNext ? currentIndex - 1 : currentIndex + 1;
    } else {
      // Para all_departures lógica normal
      targetIndex = isNext ? currentIndex + 1 : currentIndex - 1;
    }

    // Verificar que el índice sea válido
    if (targetIndex < 0 || targetIndex >= currentFlightsList.length) {
      print(
          'LOG: NestedFlightDetails - No hay ${isNext ? "siguiente" : "anterior"} vuelo disponible');
      return;
    }

    // Obtener el vuelo objetivo
    final targetFlight = currentFlightsList[targetIndex];
    print(
        'LOG: NestedFlightDetails - Navegando a vuelo: ${targetFlight['flight_id']}');

    // Usar el servicio de navegación anidada para cambiar al vuelo adyacente
    navigationService.navigateToAdjacentFlight(flight: targetFlight);
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    // Ya no necesitamos AppBar personalizada, la principal se encarga de todo
    return isLoading
        ? const Center(child: CircularProgressIndicator())
        : errorMessage != null
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(errorMessage!),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: loadFlightDetails,
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              )
            : flightDetails != null
                ? _buildFlightDetailsContent()
                : Center(
                    child: Text(localizations.noDataFoundForFlight),
                  );
  }

  Widget _buildFlightDetailsContent() {
    // Obtener datos actuales
    final currentFlight = navigationService.currentFlightData ?? widget.flight;
    final currentFlightsList =
        navigationService.flightsList ?? widget.flightsList;
    final currentFlightsSource =
        navigationService.flightsSource ?? widget.flightsSource;

    final String currentDocumentId = currentFlightsSource == 'my'
        ? (currentFlight['flight_ref'] ?? currentFlight['id'] ?? '')
        : currentFlight['id'];

    // Determinar si usar la UI de Oversize o normal
    return FutureBuilder<bool>(
      future: LocationService.isOversizeLocation(),
      builder: (context, snapshot) {
        final bool isOversize = snapshot.data ?? false;

        // Determinar si se puede hacer swipe
        final bool canSwipe =
            currentFlightsList.isNotEmpty && currentFlightsList.length > 1;

        if (isOversize) {
          return OzFlightDetailsUI(
            flightDetails: flightDetails!,
            gateHistory: gateHistory,
            fullHistory: fullHistory,
            onRefresh: loadFlightDetails,
            documentId: currentDocumentId,
            canSwipe: canSwipe,
            onSwipe: handleSwipe,
            onSwipeDirectionChanged: (isNext) {
              // Precargar vuelo adyacente si es necesario
            },
            adjacentFlightDetails: adjacentFlightDetails,
          );
        } else {
          return FlightDetailsUI(
            flightDetails: flightDetails!,
            gateHistory: gateHistory,
            fullHistory: fullHistory,
            onRefresh: loadFlightDetails,
            documentId: currentDocumentId,
            canSwipe: canSwipe,
            onSwipe: handleSwipe,
            onSwipeDirectionChanged: (isNext) {
              // Precargar vuelo adyacente si es necesario
            },
            adjacentFlightDetails: adjacentFlightDetails,
          );
        }
      },
    );
  }
}
