import 'package:flutter/material.dart';
import 'all_departures_ui.dart';

/// Componente que maneja la lógica y los datos para la pantalla de todos los vuelos de salida
class AllDeparturesScreen extends StatelessWidget {
  const AllDeparturesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Lista ficticia para mostrar todos los vuelos de salida
    final List<Map<String, dynamic>> allFlights = [
      {
        'airline': 'D8',
        'flight_id': 'D85323',
        'schedule_time': '17:50',
        'airport': 'ALC',
        'gate': 'D9',
        'color': const Color.fromARGB(255, 255, 68, 68),
      },
      {
        'airline': 'DY',
        'flight_id': 'DY328',
        'schedule_time': '17:50',
        'airport': 'TOS',
        'gate': 'A8',
        'color': const Color.fromARGB(255, 255, 68, 68),
      },
      {
        'airline': 'DY',
        'flight_id': 'DY1054',
        'schedule_time': '17:55',
        'airport': 'GDN',
        'gate': 'D4',
        'color': const Color.fromARGB(255, 255, 68, 68),
      },
      {
        'airline': 'DY',
        'flight_id': 'DY436',
        'schedule_time': '17:55',
        'airport': 'MOL',
        'gate': 'A21',
        'color': const Color.fromARGB(255, 255, 68, 68),
      },
      {
        'airline': 'SK',
        'flight_id': 'SK1330',
        'schedule_time': '18:10',
        'airport': 'AES',
        'gate': 'A2',
        'color': const Color.fromARGB(255, 33, 150, 243),
      },
      {
        'airline': 'DX',
        'flight_id': 'DX578',
        'schedule_time': '18:15',
        'airport': 'FRO',
        'gate': 'A27',
        'color': const Color.fromARGB(255, 76, 175, 80),
      },
      {
        'airline': 'DY',
        'flight_id': 'DY636',
        'schedule_time': '18:20',
        'airport': 'BGO',
        'gate': 'C6',
        'color': const Color.fromARGB(255, 255, 68, 68),
      },
      {
        'airline': 'SK',
        'flight_id': 'SK320',
        'schedule_time': '18:20',
        'airport': 'HAU',
        'gate': 'A14',
        'color': const Color.fromARGB(255, 33, 150, 243),
      },
      {
        'airline': 'SK',
        'flight_id': 'SK4055',
        'schedule_time': '18:20',
        'airport': 'SVG',
        'gate': 'C3',
        'color': const Color.fromARGB(255, 33, 150, 243),
      },
      {
        'airline': 'SK',
        'flight_id': 'SK4432',
        'schedule_time': '18:20',
        'airport': 'TOS',
        'gate': 'A19',
        'color': const Color.fromARGB(255, 33, 150, 243),
      },
      {
        'airline': 'SK',
        'flight_id': 'SK815',
        'schedule_time': '18:20',
        'airport': 'LHR',
        'gate': 'F31',
        'color': const Color.fromARGB(255, 33, 150, 243),
      },
      {
        'airline': 'AY',
        'flight_id': 'AY918',
        'schedule_time': '18:30',
        'airport': 'HEL',
        'gate': 'E5',
        'color': Colors.white,
      },
      {
        'airline': 'SK',
        'flight_id': 'SK291',
        'schedule_time': '18:30',
        'airport': 'BGO',
        'gate': 'A15',
        'color': const Color.fromARGB(255, 33, 150, 243),
      },
      {
        'airline': 'SK',
        'flight_id': 'SK380',
        'schedule_time': '18:30',
        'airport': 'TRD',
        'gate': 'A6',
        'color': const Color.fromARGB(255, 33, 150, 243),
      },
      {
        'airline': 'SK',
        'flight_id': 'SK2309',
        'schedule_time': '18:35',
        'airport': 'KSU',
        'gate': 'C7',
        'color': const Color.fromARGB(255, 33, 150, 243),
      },
      {
        'airline': 'DY',
        'flight_id': 'DY336',
        'schedule_time': '18:40',
        'airport': 'BDU',
        'gate': 'A10',
        'color': const Color.fromARGB(255, 255, 68, 68),
      },
      {
        'airline': 'SK',
        'flight_id': 'SK1475',
        'schedule_time': '18:55',
        'airport': 'CPH',
        'gate': 'D5',
        'color': const Color.fromARGB(255, 33, 150, 243),
      },
      {
        'airline': 'DY',
        'flight_id': 'DY368',
        'schedule_time': '19:00',
        'airport': 'EVE',
        'gate': 'C2',
        'color': const Color.fromARGB(255, 255, 68, 68),
      },
      {
        'airline': 'SK',
        'flight_id': 'SK372',
        'schedule_time': '19:05',
        'airport': 'KRS',
        'gate': 'B3',
        'color': const Color.fromARGB(255, 33, 150, 243),
      },
      {
        'airline': 'DY',
        'flight_id': 'DY994',
        'schedule_time': '19:15',
        'airport': 'OSL',
        'gate': 'D7',
        'color': const Color.fromARGB(255, 255, 68, 68),
      },
    ];

    // En el futuro, aquí podrías agregar lógica para cargar datos desde una API,
    // filtrar vuelos, manejar estados de carga, etc.

    return AllDeparturesUI(flights: allFlights);
  }
}
