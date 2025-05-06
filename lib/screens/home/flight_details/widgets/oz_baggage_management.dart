import 'package:flutter/material.dart';

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
    Key? key,
  }) : super(key: key);

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
              color: Colors.grey.withOpacity(0.2),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.luggage, color: Colors.amber),
                const SizedBox(width: 8),
                const Text(
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
    // Por ahora solo mostraremos un SnackBar para indicar que se ha pulsado el botón
    // Esta funcionalidad se implementará más adelante
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'Registering oversize item for flight $flightId at gate $currentGate'),
        backgroundColor: Colors.amber,
        duration: const Duration(seconds: 2),
      ),
    );

    // Llamar al callback si se proporciona
    if (onRegisterSuccess != null) {
      onRegisterSuccess!();
    }
  }
}
