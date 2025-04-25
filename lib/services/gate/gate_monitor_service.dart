import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../notifications/notification_service.dart';
import '../cache/cache_service.dart';

/// Servicio para monitorear cambios de puerta en los vuelos guardados por el usuario
class GateMonitorService {
  static final GateMonitorService _instance = GateMonitorService._internal();
  factory GateMonitorService() => _instance;
  GateMonitorService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final NotificationService _notificationService = NotificationService();

  // Streams de suscripción para monitorear cambios de puerta
  final Map<String, StreamSubscription<QuerySnapshot>>
      _gateMonitorSubscriptions = {};
  // Último valor conocido de las puertas para cada vuelo
  final Map<String, String> _lastKnownGates = {};
  // Verificar si ya hemos inicializado el servicio
  bool _isInitialized = false;

  /// Inicializa el servicio de monitoreo de cambios de puerta
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Inicializar el servicio de notificaciones
    await _notificationService.init();

    // Solicitar permisos si es necesario
    await _notificationService.requestPermissions();

    _isInitialized = true;
    print('LOG: Gate monitor service initialized');
  }

  /// Inicia el monitoreo de cambios de puerta para los vuelos del usuario actual
  Future<void> startMonitoring() async {
    if (!_isInitialized) {
      await initialize();
    }

    // Verificar si el usuario está autenticado
    final User? currentUser = _auth.currentUser;
    if (currentUser == null) {
      print('LOG: No user logged in, gate monitoring not started');
      return;
    }

    // Verificar si las notificaciones de cambio de puerta están habilitadas
    final bool notificationsEnabled =
        await CacheService.getGateChangeNotificationsPreference();
    if (!notificationsEnabled) {
      print('LOG: Gate change notifications disabled by user preferences');
      return;
    }

    try {
      // Detener cualquier monitoreo previo para evitar duplicados
      stopMonitoring();

      // Obtener los vuelos guardados por el usuario
      final QuerySnapshot userFlights = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('flights')
          .where('archived',
              isEqualTo: false) // No monitorear vuelos archivados
          .get();

      print('LOG: Found ${userFlights.docs.length} user flights to monitor');

      // Comenzar a monitorear cada vuelo
      for (final DocumentSnapshot flightDoc in userFlights.docs) {
        final Map<String, dynamic> flightData =
            flightDoc.data() as Map<String, dynamic>;
        final String flightId = flightData['flight_id']?.toString() ?? '';
        final String docId = flightData['doc_id']?.toString() ?? '';

        // Si tenemos un ID de documento válido y un ID de vuelo, comenzar a monitorear
        if (docId.isNotEmpty && flightId.isNotEmpty) {
          _monitorFlightGate(docId, flightData);
        }
      }
    } catch (e) {
      print('LOG: Error starting gate monitor: $e');
    }
  }

  /// Monitorea los cambios de puerta para un vuelo específico
  void _monitorFlightGate(String docId, Map<String, dynamic> flightData) {
    // Verificar el estado del vuelo
    final String statusCode = flightData['status_code']?.toString() ?? '';
    // No monitorear vuelos que ya han despegado (D) o aterrizado (L)
    if (statusCode == 'D' || statusCode == 'L') {
      print(
          'LOG: Flight ${flightData['flight_id']} already departed/landed, not monitoring');
      return;
    }

    // Obtener la puerta actual (si existe)
    final String currentGate = flightData['gate']?.toString() ?? '';
    // Almacenar la puerta actual como referencia
    _lastKnownGates[docId] = currentGate;

    final String flightId = flightData['flight_id'] ?? '';
    print(
        'LOG: Starting gate monitoring for flight $flightId, current gate: $currentGate');

    // Suscribirse a cambios en la subcolección history del vuelo
    final StreamSubscription<QuerySnapshot> subscription = _firestore
        .collection('flights')
        .doc(docId)
        .collection('history')
        .orderBy('change_time', descending: true)
        .limit(1) // Solo necesitamos el cambio más reciente
        .snapshots()
        .listen((QuerySnapshot snapshot) {
      if (snapshot.docs.isNotEmpty) {
        _handleHistoryUpdate(snapshot.docs.first, docId, flightId);
      }
    }, onError: (error) {
      print('LOG: Error monitoring gate changes for flight $flightId: $error');
    });

    // Guardar la suscripción para poder cancelarla más tarde
    _gateMonitorSubscriptions[docId] = subscription;
  }

  /// Maneja las actualizaciones de un documento de history
  void _handleHistoryUpdate(
      DocumentSnapshot snapshot, String docId, String flightId) async {
    if (!snapshot.exists) {
      print('LOG: History document for flight $flightId no longer exists');
      return;
    }

    final Map<String, dynamic> historyData =
        snapshot.data() as Map<String, dynamic>;

    // Verificar si contiene información de cambio de puerta
    if (!historyData.containsKey('new_gate') ||
        !historyData.containsKey('old_gate')) {
      // Este registro de history no es un cambio de puerta
      return;
    }

    // Obtener información del documento principal del vuelo para verificar estado
    try {
      final DocumentSnapshot flightDoc =
          await _firestore.collection('flights').doc(docId).get();

      if (!flightDoc.exists) {
        print('LOG: Flight document $docId no longer exists');
        _stopMonitoringFlight(docId);
        return;
      }

      final Map<String, dynamic> flightData =
          flightDoc.data() as Map<String, dynamic>;
      final String statusCode = flightData['status_code']?.toString() ?? '';

      // Verificar si el vuelo ya ha despegado o aterrizado
      if (statusCode == 'D' || statusCode == 'L') {
        print('LOG: Flight $flightId has departed/landed, stopping monitoring');
        _stopMonitoringFlight(docId);
        return;
      }

      // Obtener información del cambio de puerta
      final String newGate = historyData['new_gate']?.toString() ?? '';
      final String oldGate = historyData['old_gate']?.toString() ?? '';

      // Para evitar notificaciones duplicadas, usamos el último gate conocido
      final String lastKnownGate = _lastKnownGates[docId] ?? '';

      // Solo notificar si esta es una nueva puerta que no hemos notificado antes
      if (newGate.isNotEmpty && newGate != lastKnownGate) {
        print(
            'LOG: Gate change detected for flight $flightId: $oldGate -> $newGate');

        // Verificar que las notificaciones estén habilitadas
        final bool notificationsEnabled =
            await CacheService.getGateChangeNotificationsPreference();
        if (!notificationsEnabled) {
          print(
              'LOG: Gate change notifications disabled, not sending notification');
          // Actualizar la última puerta conocida aunque no enviemos notificación
          _lastKnownGates[docId] = newGate;
          return;
        }

        // Enviar notificación de cambio de puerta
        try {
          await _notificationService.notifyGateChange(
            flightId: flightId,
            airline: flightData['airline'] ?? '',
            destination: flightData['airport'] ?? '',
            newGate: newGate,
            oldGate: oldGate.isNotEmpty ? oldGate : null,
          );

          // Actualizar la última puerta conocida
          _lastKnownGates[docId] = newGate;
          print('LOG: Gate change notification sent for flight $flightId');
        } catch (e) {
          print('LOG: Error sending gate change notification: $e');
        }
      }
    } catch (e) {
      print('LOG: Error processing gate change for flight $flightId: $e');
    }
  }

  /// Detiene el monitoreo de un vuelo específico
  void _stopMonitoringFlight(String docId) {
    final StreamSubscription<QuerySnapshot>? subscription =
        _gateMonitorSubscriptions[docId];
    if (subscription != null) {
      subscription.cancel();
      _gateMonitorSubscriptions.remove(docId);
      _lastKnownGates.remove(docId);
      print('LOG: Stopped monitoring flight with document ID $docId');
    }
  }

  /// Detiene todo el monitoreo de cambios de puerta
  void stopMonitoring() {
    for (final subscription in _gateMonitorSubscriptions.values) {
      subscription.cancel();
    }
    _gateMonitorSubscriptions.clear();
    _lastKnownGates.clear();
    print('LOG: Stopped all gate monitoring');
  }

  /// Liberar recursos al cerrar la aplicación
  void dispose() {
    stopMonitoring();
    _isInitialized = false;
  }
}
