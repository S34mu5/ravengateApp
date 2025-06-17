import 'package:flutter/material.dart';
import 'widgets/flight_header.dart';
import 'widgets/gate_history.dart';
import 'forms/oversize_item_registration_form.dart';
import 'widgets/oversize_baggage.dart';
import 'widgets/debug_information.dart';
import 'base_flight_details_ui.dart';

/// Widget that displays the user interface for oversize baggage management
/// Reutiliza componentes comunes y evita duplicidad de código
class OzFlightDetailsUI extends BaseFlightDetailsUI {
  const OzFlightDetailsUI({
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
  State<OzFlightDetailsUI> createState() => _OzFlightDetailsUIState();
}

class _OzFlightDetailsUIState
    extends BaseFlightDetailsUIState<OzFlightDetailsUI> {
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
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header con información principal (reutilizado de flight_details_ui.dart)
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

          // Formulario embebido de gestión de equipaje sobredimensionado
          OversizeItemRegistrationForm(
            flightId: flightDetails['flight_id'] ?? '',
            documentId: documentId,
            currentGate: currentGate,
            onSuccess: onRefresh,
            showCloseIcon: false,
          ),

          // Panel informativo/placeholder de Oversize en vez de la lista
          OversizeBaggage(
            documentId: documentId,
            flightId: flightDetails['flight_id'] ?? '',
            currentGate: currentGate,
          ),

          // Debug Information - solo visible en modo desarrollador
          if (developerModeEnabled)
            DebugInformation(
              documentId: documentId,
              onShowAdditionalInfo: () => _showAdditionalInfoModal(context),
            ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  /// Muestra un modal con información adicional del vuelo
  void _showAdditionalInfoModal(BuildContext context) {
    // Simplemente llamar al método de la clase base
    showAdditionalInfoModal(context);
  }
}
