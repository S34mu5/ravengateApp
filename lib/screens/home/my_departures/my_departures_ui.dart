import 'package:flutter/material.dart';
import '../../../utils/airline_helper.dart';
import '../flight_details/flight_details_screen.dart';

/// Widget que muestra la interfaz de usuario para la lista de vuelos del usuario
class MyDeparturesUI extends StatelessWidget {
  final List<Map<String, dynamic>> flights;
  final Future<void> Function(String flightId)? onRemoveFlight;

  const MyDeparturesUI({
    required this.flights,
    this.onRemoveFlight,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    print('LOG: Construyendo UI para mis vuelos (${flights.length} vuelos)');
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search my flights...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.grey.shade100,
            ),
            onChanged: (value) {
              print('LOG: Usuario buscando en sus vuelos con texto: $value');
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          alignment: Alignment.centerLeft,
          child: const Text(
            'My Departures',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(
          child: flights.isEmpty
              ? _buildEmptyState(context)
              : ListView.builder(
                  itemCount: flights.length,
                  itemBuilder: (context, index) {
                    final flight = flights[index];
                    return Dismissible(
                      key: Key(flight['id'] ??
                          flight['flight_id'] ??
                          'flight-$index'),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        color: Colors.red,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20.0),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      confirmDismiss: (direction) async {
                        // Show confirmation dialog before deleting
                        return await showDialog<bool>(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              title: const Text("Confirm"),
                              content: Text(
                                  "Are you sure you want to remove ${flight['flight_id']} from your list?"),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(context).pop(false),
                                  child: const Text("Cancel"),
                                ),
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(context).pop(true),
                                  child: const Text("Delete"),
                                ),
                              ],
                            );
                          },
                        );
                      },
                      onDismissed: (direction) {
                        // Call the remove function passed from parent
                        if (onRemoveFlight != null) {
                          onRemoveFlight!(flight['id'] ?? flight['flight_id']);
                        }
                      },
                      child: Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: flight['color'] ??
                                AirlineHelper.getAirlineColor(
                                    flight['airline']),
                            child: Text(
                              flight['airline'],
                              style: TextStyle(
                                color: AirlineHelper.getTextColorForAirline(
                                    flight['airline']),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(
                            '${flight['flight_id']} - ${flight['schedule_time']} ${flight['airport']}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text('Gate: ${flight['gate']}'),
                          trailing:
                              const Icon(Icons.arrow_forward_ios, size: 16),
                          onTap: () {
                            print(
                                'LOG: Usuario seleccionó su vuelo ${flight['flight_id']} para ${flight['airport']}');

                            // Navegar a la pantalla de detalles
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => FlightDetailsScreen(
                                  flightId: flight['flight_id'],
                                  documentId: flight['id'] ?? '',
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.flight_takeoff,
            size: 72,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No saved flights yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Long press on a flight in All Departures\nto add it to your list',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}
