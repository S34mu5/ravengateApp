import 'package:flutter/material.dart';
import 'dart:async'; // Importar para usar Timer
import 'my_departures_ui.dart';
import '../../../services/user/user_flights_service.dart';
import '../../../services/notifications/notification_service.dart';
import '../../../services/flights/flight_delay_detector.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  bool _usingCachedData = false; // Indicador de si los datos son de la caché

  // Claves para la caché
  static const String _userFlightsLastUpdatedKey = 'user_flights_last_updated';

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _loadData(); // Usar el nuevo método de carga en dos fases

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

    // Solicitar permisos para las notificaciones
    final bool hasPermission = await _notificationService.requestPermissions();
    print(
        'LOG: Permisos de notificaciones ${hasPermission ? 'concedidos' : 'denegados'}');
  }

  /// Método principal para cargar datos en dos fases
  /// Primero intenta cargar la caché, luego actualiza desde Firestore
  Future<void> _loadData() async {
    print('LOG: Iniciando carga de datos en dos fases...');

    // Intentar cargar desde la caché primero a través del servicio
    // (ya está implementado en UserFlightsService.getUserFlights())
    await _loadUserFlights();
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

      // Obtener la fecha de última actualización antes de la carga
      final prefs = await SharedPreferences.getInstance();
      final lastUpdatedStr = prefs.getString(_userFlightsLastUpdatedKey);
      final lastUpdatedBefore =
          lastUpdatedStr != null ? DateTime.parse(lastUpdatedStr) : null;

      // Obtener vuelos del usuario desde el servicio
      // (El servicio intentará cargar desde caché primero)
      final userFlights = await UserFlightsService.getUserFlights();

      // Verificar si los datos provienen de la caché comparando timestamps
      final lastUpdatedStr2 = prefs.getString(_userFlightsLastUpdatedKey);
      final lastUpdatedAfter =
          lastUpdatedStr2 != null ? DateTime.parse(lastUpdatedStr2) : null;

      // Si el timestamp es igual antes y después de la carga, se usó la caché
      final usedCache = lastUpdatedBefore != null &&
          lastUpdatedAfter != null &&
          lastUpdatedBefore.isAtSameMomentAs(lastUpdatedAfter);

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
        _lastUpdated = lastUpdatedAfter ?? DateTime.now();
        _usingCachedData = usedCache;
      });

      // Actualizar la lista de vuelos anteriores para futuras comparaciones
      _previousUserFlights = List.from(newFlights);

      print(
          'LOG: Se cargaron ${_userFlights.length} vuelos del usuario (Desde caché: $_usingCachedData)');
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
                    usingCachedData:
                        _usingCachedData, // Pasar la información de caché a la UI
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

  @override
  void dispose() {
    // Cancelar el timer cuando se destruye el widget
    _refreshTimer?.cancel();
    print('LOG: Disposing MyDeparturesScreen and canceling refresh timer');
    super.dispose();
  }
}
