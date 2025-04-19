import 'package:flutter/material.dart';

/// Widget que muestra la interfaz de usuario para la lista de vuelos del usuario
class MyDeparturesUI extends StatelessWidget {
  final List<Map<String, dynamic>> flights;

  const MyDeparturesUI({
    required this.flights,
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
          child: ListView.builder(
            itemCount: flights.length,
            itemBuilder: (context, index) {
              final flight = flights[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: flight['color'],
                    child: Text(
                      flight['airline'],
                      style: const TextStyle(
                        color: Colors.white,
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
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    print(
                        'LOG: Usuario seleccionó su vuelo ${flight['flight_id']} para ${flight['airport']}');
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
