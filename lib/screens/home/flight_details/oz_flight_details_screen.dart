import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'oz_flight_details_ui.dart';
import '../../../services/navigation/swipeable_flight_details.dart';
import '../../../services/navigation/swipeable_flights_service.dart';
import 'base_flight_details_screen.dart';

/// Component that handles the logic and data for the oversize flight details screen
/// Gets detailed data of a specific flight from Firestore for oversize baggage management
class OzFlightDetailsScreen extends BaseFlightDetailsScreen {
  const OzFlightDetailsScreen({
    required super.flightId,
    required super.documentId,
    super.flightsList,
    super.flightsSource,
    super.forceRefreshOnReturn = false,
    super.key,
  });

  @override
  State<OzFlightDetailsScreen> createState() => _OzFlightDetailsScreenState();
}

class _OzFlightDetailsScreenState
    extends BaseFlightDetailsScreenState<OzFlightDetailsScreen> {
  @override
  String getScreenName() {
    return 'OzFlightDetailsScreen';
  }

  @override
  Widget buildAdjacentFlightScreen({
    required String flightId,
    required String documentId,
    required List<Map<String, dynamic>> flightsList,
    required String flightsSource,
    bool forceRefreshOnReturn = false,
  }) {
    return OzFlightDetailsScreen(
      flightId: flightId,
      documentId: documentId,
      flightsList: flightsList,
      flightsSource: flightsSource,
      forceRefreshOnReturn: forceRefreshOnReturn,
    );
  }

  @override
  Widget buildContent() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flight Details (Oversize)'),
        backgroundColor: const Color(0xFFfe8b02),
        foregroundColor: Colors.white,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
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
                        errorMessage!,
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: loadFlightDetails,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : flightDetails != null
                  ? OzFlightDetailsUI(
                      flightDetails: flightDetails!,
                      gateHistory: gateHistory,
                      fullHistory: fullHistory,
                      onRefresh: loadFlightDetails,
                      documentId: widget.documentId,
                      canSwipe: canSwipeThroughFlights(),
                      onSwipe: handleSwipe,
                      onSwipeDirectionChanged: handleSwipeDirectionChange,
                      adjacentFlightDetails: adjacentFlightDetails,
                    )
                  : const Center(
                      child: Text('No flight data available'),
                    ),
    );
  }
}
