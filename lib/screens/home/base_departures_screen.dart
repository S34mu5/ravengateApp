import 'package:flutter/material.dart';
import 'dart:async';

/// Clase base abstracta para las pantallas de vuelos
abstract class BaseDeparturesScreen extends StatefulWidget {
  const BaseDeparturesScreen({super.key});
}

/// Estado base abstracto para las pantallas de vuelos
abstract class BaseDeparturesScreenState<T extends BaseDeparturesScreen>
    extends State<T> {
  // Variables comunes
  bool _isLoading = true;
  String? _errorMessage;
  Timer? _refreshTimer;
  DateTime? _lastUpdated;
  bool _usingCachedData = false;

  // Getters
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  DateTime? get lastUpdated => _lastUpdated;
  bool get usingCachedData => _usingCachedData;

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _loadData();
    _setupRefreshTimer();
  }

  /// Inicializa los servicios necesarios
  Future<void> _initializeServices() async {
    // Implementación por defecto vacía, las subclases pueden sobreescribir
  }

  /// Configura el timer de actualización automática
  void _setupRefreshTimer() {
    _refreshTimer = Timer.periodic(const Duration(minutes: 3), (timer) {
      print('LOG: Actualizando datos automáticamente cada 3 minutos');
      _onRefreshTimer(timer);
    });
  }

  /// Método principal para cargar datos
  Future<void> _loadData() async {
    print('LOG: Iniciando carga de datos...');
    await loadFlights();
  }

  /// Método abstracto para cargar los vuelos
  Future<void> loadFlights({bool forceRefresh = false});

  /// Método abstracto para construir el widget de la UI
  Widget buildUI();

  /// Método que se ejecuta cuando el timer de actualización se dispara
  void _onRefreshTimer(Timer timer) {
    loadFlights(forceRefresh: timer.tick % 3 == 0);
  }

  /// Actualiza el estado de carga
  void setLoading(bool loading) {
    if (mounted) {
      setState(() {
        _isLoading = loading;
      });
    }
  }

  /// Actualiza el mensaje de error
  void setError(String? error) {
    if (mounted) {
      setState(() {
        _errorMessage = error;
      });
    }
  }

  /// Actualiza el estado de la caché
  void setUsingCachedData(bool usingCache) {
    if (mounted) {
      setState(() {
        _usingCachedData = usingCache;
      });
    }
  }

  /// Actualiza la fecha de última actualización
  void setLastUpdated(DateTime? date) {
    if (mounted) {
      setState(() {
        _lastUpdated = date;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildErrorWidget()
              : RefreshIndicator(
                  onRefresh: () => loadFlights(forceRefresh: true),
                  child: buildUI(),
                ),
    );
  }

  /// Construye el widget de error
  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            _errorMessage!,
            style: TextStyle(color: Colors.red.shade700),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => loadFlights(forceRefresh: true),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    print('LOG: Disposing ${runtimeType} and canceling refresh timer');
    super.dispose();
  }
}
