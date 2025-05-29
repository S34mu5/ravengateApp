import 'package:flutter/material.dart';

/// Servicio para manejar la navegación anidada manteniendo el BottomNavigationBar fijo
class NestedNavigationService extends ChangeNotifier {
  static final NestedNavigationService _instance =
      NestedNavigationService._internal();

  factory NestedNavigationService() {
    return _instance;
  }

  NestedNavigationService._internal();

  // Estado de navegación
  bool _isShowingFlightDetails = false;
  Map<String, dynamic>? _currentFlightData;
  List<Map<String, dynamic>>? _flightsList;
  String? _flightsSource;
  int _originalTabIndex = 0;

  // Callback para refresh desde la AppBar principal
  VoidCallback? _onRefreshCallback;

  // Getters
  bool get isShowingFlightDetails => _isShowingFlightDetails;
  Map<String, dynamic>? get currentFlightData => _currentFlightData;
  List<Map<String, dynamic>>? get flightsList => _flightsList;
  String? get flightsSource => _flightsSource;
  int get originalTabIndex => _originalTabIndex;

  /// Navega a los detalles de un vuelo manteniendo el BottomNavigationBar
  void navigateToFlightDetails({
    required Map<String, dynamic> flight,
    required List<Map<String, dynamic>> flightsList,
    required String flightsSource,
    required int currentTabIndex,
  }) {
    print(
        'LOG: NestedNavigation - Navegando a detalles de vuelo: ${flight['flight_id']}');
    print('LOG: NestedNavigation - Origen: $flightsSource');
    print('LOG: NestedNavigation - Tab actual: $currentTabIndex');

    _isShowingFlightDetails = true;
    _currentFlightData = flight;
    _flightsList = flightsList;
    _flightsSource = flightsSource;
    _originalTabIndex = currentTabIndex;

    notifyListeners();
  }

  /// Regresa a la pantalla anterior (lista de vuelos)
  void navigateBack() {
    print('LOG: NestedNavigation - Regresando a la lista de vuelos');

    _isShowingFlightDetails = false;
    _currentFlightData = null;
    _flightsList = null;
    _flightsSource = null;

    notifyListeners();
  }

  /// Navega a un vuelo adyacente
  void navigateToAdjacentFlight({
    required Map<String, dynamic> flight,
  }) {
    print(
        'LOG: NestedNavigation - Navegando a vuelo adyacente: ${flight['flight_id']}');

    _currentFlightData = flight;

    notifyListeners();
  }

  /// Limpia el estado (útil para logout o cambios de ubicación)
  void clear() {
    print('LOG: NestedNavigation - Limpiando estado de navegación');

    _isShowingFlightDetails = false;
    _currentFlightData = null;
    _flightsList = null;
    _flightsSource = null;
    _originalTabIndex = 0;

    notifyListeners();
  }

  /// Registra el callback de refresh de la pantalla anidada
  void registerRefreshCallback(VoidCallback callback) {
    _onRefreshCallback = callback;
  }

  /// Desregistra el callback de refresh
  void unregisterRefreshCallback() {
    _onRefreshCallback = null;
  }

  /// Ejecuta el refresh de la pantalla anidada
  void refreshNestedDetails() {
    if (_onRefreshCallback != null) {
      _onRefreshCallback!();
    }
  }
}
