import 'package:flutter/material.dart';
import 'dart:async'; // Importar para usar Timer
import 'my_departures_ui.dart';
import '../../../utils/airline_helper.dart';
import '../../../services/user/user_flights_service.dart';
import '../../../utils/progress_dialog.dart';
import '../../../services/notifications/notification_service.dart';
import '../../../services/flight_delay_detector.dart';

/// Componente que maneja la lógica y los datos para la pantalla de vuelos del usuario
class MyDeparturesScreen extends StatefulWidget {
  const MyDeparturesScreen({super.key});

  @override
  State<MyDeparturesScreen> createState() => _MyDeparturesScreenState();
}

class _MyDeparturesScreenState extends State<MyDeparturesScreen> {
  List<Map<String, dynamic>> _userFlights = [];
  List<Map<String, dynamic>> _previousUserFlights = [];
  bool _isLoading = true;
  String? _errorMessage;
  Timer? _refreshTimer; // Timer para actualización periódica
  DateTime? _lastUpdated; // Tiempo de última actualización
  final NotificationService _notificationService = NotificationService();
  final FlightDelayDetector _delayDetector = FlightDelayDetector();

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _loadUserFlights();

    // Configurar actualización automática cada 3 minutos
    _refreshTimer = Timer.periodic(const Duration(minutes: 3), (timer) {
      print(
          'LOG: Actualizando datos de vuelos del usuario automáticamente cada 3 minutos');
      // Guardar los vuelos actuales como "anteriores" antes de cargar los nuevos
      _previousUserFlights = List.from(_userFlights);
      _loadUserFlights();
    });
  }

  /// Inicializa los servicios necesarios
  Future<void> _initializeServices() async {
    // Inicializar el servicio de notificaciones
    await _notificationService.init();
  }

  /// Cargar los vuelos guardados por el usuario
  Future<void> _loadUserFlights() async {
    print('LOG: Cargando datos de vuelos del usuario en MyDeparturesScreen');

    try {
      // Verificar si el widget está montado antes de actualizar estado
      if (!mounted) return;

      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // Obtener vuelos del usuario desde el servicio
      final userFlights = await UserFlightsService.getUserFlights();

      // Verificar nuevamente si el widget sigue montado
      if (!mounted) return;

      // Guardar vuelos actuales
      final List<Map<String, dynamic>> newFlights = userFlights;

      // Verificar si hay retrasos comparando con los vuelos anteriores
      if (_previousUserFlights.isNotEmpty) {
        await _delayDetector.checkForDelays(_previousUserFlights, newFlights);
      }

      setState(() {
        _userFlights = newFlights;
        _isLoading = false;
        _lastUpdated = DateTime.now();
      });

      // Actualizar la lista de vuelos anteriores para futuras comparaciones
      _previousUserFlights = List.from(newFlights);

      print('LOG: Se cargaron ${_userFlights.length} vuelos del usuario');
    } catch (e) {
      print('LOG: Error al cargar vuelos del usuario: $e');

      // Verificar si el widget sigue montado antes de actualizar estado de error
      if (!mounted) return;

      setState(() {
        _errorMessage = 'Error loading flights: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadUserFlights,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadUserFlights,
                  child: MyDeparturesUI(
                    flights: _userFlights,
                    onRemoveFlight: _removeFlight,
                    onRefresh: _loadUserFlights,
                    lastUpdated: _lastUpdated,
                  ),
                ),
    );
  }

  /// Eliminar un vuelo de la lista del usuario
  Future<void> _removeFlight(String flightId) async {
    try {
      // Verificar si el widget está montado antes de actualizar estado
      if (!mounted) return;

      // Mostrar indicador de carga
      setState(() {
        _isLoading = true;
      });

      // Eliminar el vuelo
      final wasRemoved = await UserFlightsService.removeFlight(flightId);

      // Verificar si el widget sigue montado antes de recargar la lista
      if (!mounted) return;

      // Recargar la lista
      await _loadUserFlights();

      // Esta verificación ya existe, se mantiene
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

      // Esta verificación ya existe, se mantiene
      if (!mounted) return;

      // Mostrar mensaje de error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error removing flight: $e'),
          backgroundColor: Colors.red.shade700,
          duration: const Duration(seconds: 2),
        ),
      );

      // Verificar montado antes de recargar
      if (!mounted) return;

      // Recargar la lista de todos modos
      _loadUserFlights();
    }
  }

  /// Envía una notificación de prueba
  Future<void> _sendTestNotification() async {
    try {
      await _notificationService.showNotification(
        id: 1,
        title: "Prueba de notificación",
        body: "Esta es una notificación de prueba de RavenGate",
      );
    } catch (e) {
      print('LOG: Error enviando notificación de prueba: $e');
    }
  }

  @override
  void dispose() {
    // Cancelar el timer cuando se destruye el widget
    _refreshTimer?.cancel();
    print('LOG: Disposing MyDeparturesScreen and canceling refresh timer');
    super.dispose();
  }
}
