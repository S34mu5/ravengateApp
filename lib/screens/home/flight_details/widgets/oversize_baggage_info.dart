import 'package:flutter/material.dart';
import 'oversize_baggage_ui.dart';

/// Widget wrapper para la gestión de equipaje de gran tamaño
/// Mantiene compatibilidad con la API existente
class OversizeBaggage extends StatelessWidget {
  final String documentId;
  final String flightId;
  final String currentGate;

  const OversizeBaggage({
    required this.documentId,
    required this.flightId,
    required this.currentGate,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return OversizeBaggageUI(
      documentId: documentId,
      flightId: flightId,
      currentGate: currentGate,
    );
  }
}
