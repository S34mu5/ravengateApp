import 'package:flutter/material.dart';
import 'oversize_item_registration_ui.dart';

/// Formulario para registrar elementos sobredimensionados
/// Este widget actúa como wrapper que mantiene la compatibilidad con la API existente
class OversizeItemRegistrationForm extends StatelessWidget {
  final String flightId;
  final String documentId;
  final String currentGate;
  final VoidCallback onSuccess;
  final bool showCloseIcon;

  const OversizeItemRegistrationForm({
    required this.flightId,
    required this.documentId,
    required this.currentGate,
    required this.onSuccess,
    this.showCloseIcon = true,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return OversizeItemRegistrationUI(
      flightId: flightId,
      documentId: documentId,
      currentGate: currentGate,
      onSuccess: onSuccess,
      showCloseIcon: showCloseIcon,
    );
  }
}
