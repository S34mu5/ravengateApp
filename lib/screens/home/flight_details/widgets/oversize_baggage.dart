import 'package:flutter/material.dart';

/// Widget para la gestión de equipaje de gran tamaño
class OversizeBaggage extends StatefulWidget {
  final String documentId;
  final String flightId;
  final String currentGate;

  const OversizeBaggage({
    required this.documentId,
    required this.flightId,
    required this.currentGate,
    super.key,
  });

  @override
  State<OversizeBaggage> createState() => _OversizeBaggageState();
}

class _OversizeBaggageState extends State<OversizeBaggage> {
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
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.luggage, color: Colors.amber),
                SizedBox(width: 8),
                Text(
                  'Oversize / Special Baggage',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Text(
              'This feature will allow tracking oversize baggage items for this flight.',
              style: TextStyle(
                color: Colors.grey,
                fontStyle: FontStyle.italic,
              ),
            ),
            SizedBox(height: 16),
            Center(
              child: Text(
                'Functionality coming in future update',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.amber,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
