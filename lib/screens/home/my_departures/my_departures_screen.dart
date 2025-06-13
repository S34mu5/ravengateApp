import 'package:flutter/material.dart';
import 'my_departures_ui.dart';
import '../../../services/user/user_flights/user_flights_service.dart';
// ignore: unused_import
import '../../../services/notifications/notification_service.dart';
import '../../../services/flights/flight_delay_detector.dart';
import '../base_departures_screen.dart';

/// Componente que maneja la lógica y los datos para la pantalla de vuelos del usuario
class MyDeparturesScreen extends BaseDeparturesScreen {
  const MyDeparturesScreen({super.key});

  @override
  State<MyDeparturesScreen> createState() => _MyDeparturesScreenState();
}

class _MyDeparturesScreenState
    extends BaseDeparturesScreenState<MyDeparturesScreen> {
  List<Map<String, dynamic>> _userFlights = [];
  List<Map<String, dynamic>> _previousUserFlights = [];
  final FlightDelayDetector _delayDetector = FlightDelayDetector();

  @override
  Future<void> loadFlights({bool forceRefresh = false}) async {
    print(
        'LOG: Cargando datos de vuelos del usuario en MyDeparturesScreen ${forceRefresh ? "(FORZANDO ACTUALIZACIÓN)" : ""}');

    try {
      if (!mounted) return;

      setLoading(true);
      setError(null);
      setLastUpdated(DateTime.now());

      // Obtener vuelos del usuario desde el servicio
      final userFlights =
          await UserFlightsService.getUserFlights(forceRefresh: forceRefresh);

      if (!mounted) return;

      // Guardar vuelos actuales
      final List<Map<String, dynamic>> newFlights = userFlights;

      // Verificar si hay retrasos comparando con los vuelos anteriores
      if (_previousUserFlights.isNotEmpty) {
        await _delayDetector.checkForDelays(_previousUserFlights, newFlights);
      }

      setState(() {
        _userFlights = newFlights;
      });
      setLoading(false);
      setUsingCachedData(false);
      setLastUpdated(DateTime.now());

      // Actualizar la lista de vuelos anteriores para futuras comparaciones
      _previousUserFlights = List.from(newFlights);

      print(
          'LOG: Se cargaron ${_userFlights.length} vuelos del usuario (Actualización forzada: $forceRefresh)');
    } catch (e) {
      print('LOG: Error al cargar vuelos del usuario: $e');
      if (!mounted) return;
      setError('Error loading flights: $e');
      setLoading(false);
      setLastUpdated(DateTime.now());
    }
  }

  /// Eliminar un vuelo de la lista del usuario
  Future<void> _removeFlight(String flightId) async {
    try {
      if (!mounted) return;

      setLoading(true);

      // Eliminar el vuelo
      final wasRemoved = await UserFlightsService.removeFlight(flightId);

      if (!mounted) return;

      // Recargar la lista
      await loadFlights(forceRefresh: true);

      if (!mounted) return;

      // Mostrar mensaje de éxito o error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            wasRemoved ? 'Flight removed from your list' : 'Flight not found',
          ),
          backgroundColor:
              wasRemoved ? Colors.green.shade700 : Colors.orange.shade700,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print('LOG: Error removing flight: $e');
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error removing flight: $e'),
          backgroundColor: Colors.red.shade700,
          duration: const Duration(seconds: 2),
        ),
      );

      if (!mounted) return;
      loadFlights();
    }
  }

  @override
  Widget buildUI() {
    return MyDeparturesUI(
      flights: _userFlights,
      onRemoveFlight: _removeFlight,
      onRefresh: () => loadFlights(forceRefresh: true),
      lastUpdated: lastUpdated,
      usingCachedData: usingCachedData,
    );
  }
}
