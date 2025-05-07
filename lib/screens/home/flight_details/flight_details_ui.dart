import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'widgets/flight_header.dart';
import 'widgets/gate_history.dart';
import 'widgets/gate_trolleys.dart';
import 'widgets/oversize_baggage.dart';
import 'widgets/debug_information.dart';
import 'utils/flight_formatters.dart';
import 'base_flight_details_ui.dart';

/// Widget that displays the user interface for a specific flight details
class FlightDetailsUI extends BaseFlightDetailsUI {
  const FlightDetailsUI({
    required super.flightDetails,
    required super.gateHistory,
    required super.fullHistory,
    required super.onRefresh,
    required super.documentId,
    super.canSwipe = false,
    super.onSwipe,
    super.onSwipeDirectionChanged,
    super.adjacentFlightDetails,
    super.key,
  });

  @override
  _FlightDetailsUIState createState() => _FlightDetailsUIState();
}

class _FlightDetailsUIState extends BaseFlightDetailsUIState<FlightDetailsUI> {
  @override
  Widget buildMainContent(
    Map<String, dynamic> flightDetails,
    List<Map<String, dynamic>> gateHistory,
    String formattedScheduleTime,
    String? formattedStatusTime,
    bool isDelayed,
    bool isDeparted,
    bool isCancelled,
    Color airlineColor,
    String currentGate,
    String documentId,
    bool developerModeEnabled,
    Future<void> Function() onRefresh,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header con información principal
        FlightHeader(
          flightDetails: flightDetails,
          formattedScheduleTime: formattedScheduleTime,
          formattedStatusTime: formattedStatusTime,
          isDelayed: isDelayed,
          isDeparted: isDeparted,
          isCancelled: isCancelled,
          airlineColor: airlineColor,
          documentId: documentId,
        ),

        // Historial de cambios de puerta/gate
        GateHistory(
          gateHistory: gateHistory,
          formattedScheduleTime: formattedScheduleTime,
        ),

        // Gestión de trolleys en la puerta
        GateTrolleys(
          documentId: documentId,
          flightId: flightDetails['flight_id'] ?? '',
          currentGate: currentGate,
          onUpdateSuccess: onRefresh,
        ),

        // Gestión de equipaje de gran tamaño
        OversizeBaggage(
          documentId: documentId,
          flightId: flightDetails['flight_id'] ?? '',
          currentGate: currentGate,
        ),

        const SizedBox(height: 16),

        // Debug Information - solo visible en modo desarrollador
        if (developerModeEnabled)
          DebugInformation(
            documentId: documentId,
            onShowAdditionalInfo: () => _showAdditionalInfoModal(context),
          ),

        const SizedBox(height: 24),
      ],
    );
  }

  /// Muestra un modal con información adicional del vuelo
  void _showAdditionalInfoModal(BuildContext context) {
    // Widget adicional específico para FlightDetailsUI
    final Widget trolleysDataSection = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const SelectableText(
          'Trolleys Data:',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        FutureBuilder<QuerySnapshot>(
          future: FirebaseFirestore.instance
              .collection('flights')
              .doc(widget.documentId)
              .collection('trolleys')
              .get(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return SelectableText(
                'Error loading trolleys data: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              );
            }

            final trolleysData = snapshot.data?.docs
                    .map((doc) => doc.data() as Map<String, dynamic>)
                    .toList() ??
                [];

            if (trolleysData.isEmpty) {
              return const SelectableText(
                'No trolleys data available',
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: Colors.grey,
                ),
              );
            }

            return Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: SelectableText(
                FlightFormatters.formatJsonList(trolleysData),
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
              ),
            );
          },
        ),
      ],
    );

    // Llamar al método de la clase base pasando la sección adicional
    showAdditionalInfoModal(context, additionalSections: [trolleysDataSection]);
  }
}
