import 'package:flutter/material.dart';
import 'my_departures_ui.dart';
import '../../../utils/airline_helper.dart';

/// Componente que maneja la lógica y los datos para la pantalla de vuelos del usuario
class MyDeparturesScreen extends StatelessWidget {
  const MyDeparturesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    print('LOG: Cargando datos de vuelos del usuario en MyDeparturesScreen');
    // Lista ficticia para mostrar los vuelos del usuario (ordenados por hora)
    final List<Map<String, dynamic>> myFlights = [
      {
        'airline': 'DY',
        'flight_id': 'DY2218',
        'schedule_time': '08:45',
        'airport': 'BCN',
        'gate': 'B7',
        'color': AirlineHelper.getAirlineColor('DY'),
      },
      {
        'airline': 'DY',
        'flight_id': 'DY7432',
        'schedule_time': '12:30',
        'airport': 'LGW',
        'gate': 'C4',
        'color': AirlineHelper.getAirlineColor('DY'),
      },
      {
        'airline': 'DY',
        'flight_id': 'DY85323',
        'schedule_time': '19:50',
        'airport': 'ALC',
        'gate': 'D9',
        'color': AirlineHelper.getAirlineColor('DY'),
      },
      {
        'airline': 'DY',
        'flight_id': 'DY9104',
        'schedule_time': '22:10',
        'airport': 'ARN',
        'gate': 'A2',
        'color': AirlineHelper.getAirlineColor('DY'),
      },
    ];

    print(
        'LOG: Se cargaron ${myFlights.length} vuelos del usuario en MyDeparturesScreen');
    // En el futuro, aquí podrías agregar lógica para cargar datos de usuario desde una API,
    // filtrar por fechas, recordatorios de check-in, etc.

    return MyDeparturesUI(flights: myFlights);
  }
}
