import 'package:flutter/material.dart';
import '../forms/oversize_item_registration_form.dart';

/// Widget para la gestión de equipaje sobredimensionado
class OzBaggageManagement extends StatelessWidget {
  final String flightId;
  final String documentId;
  final String currentGate;
  final VoidCallback? onRegisterSuccess;

  const OzBaggageManagement({
    required this.flightId,
    required this.documentId,
    required this.currentGate,
    this.onRegisterSuccess,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.2),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.luggage, color: Colors.amber),
                SizedBox(width: 8),
                Text(
                  'Oversize Baggage Management',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'This screen allows you to register and track oversize baggage items for this flight.',
              style: TextStyle(
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                // Aquí se implementará la lógica para registrar un nuevo elemento
                _registerNewOversizeItem(context);
              },
              icon: const Icon(Icons.add),
              label: const Text('Register New Oversize Item'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Método para registrar un nuevo elemento de equipaje sobredimensionado
  void _registerNewOversizeItem(BuildContext context) {
    // Abrir un modal con el formulario de registro de equipaje sobredimensionado
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => OversizeItemRegistrationForm(
        flightId: flightId,
        documentId: documentId, // Este es el flight_ref
        currentGate: currentGate,
        onSuccess: () {
          // Cerrar el modal
          Navigator.pop(context);

          // Notificar éxito
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Artículo registrado correctamente'),
              backgroundColor: Colors.green,
            ),
          );

          // Llamar al callback para actualizar la UI si es necesario
          if (onRegisterSuccess != null) {
            onRegisterSuccess!();
          }
        },
      ),
    );
  }
}
