import 'package:flutter/material.dart';
import 'flight_details_ui.dart';
import 'base_flight_details_screen.dart';

/// Component that handles the logic and data for the flight details screen
/// Gets detailed data of a specific flight from Firestore
class FlightDetailsScreen extends BaseFlightDetailsScreen {
  const FlightDetailsScreen({
    required super.flightId,
    required super.documentId,
    super.flightsList,
    super.flightsSource,
    super.forceRefreshOnReturn = false,
    super.key,
  });

  @override
  State<FlightDetailsScreen> createState() => _FlightDetailsScreenState();
}

class _FlightDetailsScreenState
    extends BaseFlightDetailsScreenState<FlightDetailsScreen> {
  @override
  String getScreenName() {
    return 'FlightDetailsScreen';
  }

  @override
  Widget buildAdjacentFlightScreen({
    required String flightId,
    required String documentId,
    required List<Map<String, dynamic>> flightsList,
    required String flightsSource,
    bool forceRefreshOnReturn = false,
  }) {
    return FlightDetailsScreen(
      flightId: flightId,
      documentId: documentId,
      flightsList: flightsList,
      flightsSource: flightsSource,
      forceRefreshOnReturn: forceRefreshOnReturn,
    );
  }

  @override
  Widget buildContent() {
    // Determine if swipe is available
    final bool canSwipe = widget.flightsList != null &&
        widget.flightsList!.isNotEmpty &&
        widget.flightsList!.length > 1;

    // Determinar si necesitamos forzar actualización al volver
    final bool shouldForceRefresh =
        widget.forceRefreshOnReturn || widget.flightsSource == 'my';

    return Scaffold(
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
            onPressed: loadFlightDetails,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? Center(
                  child: Text(errorMessage!),
                )
              : flightDetails != null
                  ? FlightDetailsUI(
                      flightDetails: flightDetails!,
                      gateHistory: gateHistory,
                      fullHistory: fullHistory,
                      onRefresh: loadFlightDetails,
                      documentId: widget.documentId,
                      canSwipe: canSwipe,
                      onSwipe: handleSwipe,
                      onSwipeDirectionChanged: handleSwipeDirectionChange,
                      adjacentFlightDetails: adjacentFlightDetails,
                    )
                  : const Center(
                      child: Text('No data found for this flight'),
                    ),
    );
  }
}
