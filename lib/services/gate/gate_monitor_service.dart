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
  // Último valor conocido de las marcas de tiempo del cambio de puerta para cada vuelo
  final Map<String, Timestamp> _lastChangeTimestamps = {};
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
  void _monitorFlightGate(String docId, Map<String, dynamic> flightData) async {
    // Verificar el estado del vuelo
    final String statusCode = flightData['status_code']?.toString() ?? '';
    // No monitorear vuelos que ya han despegado (D) o aterrizado (L)
    if (statusCode == 'D' || statusCode == 'L') {
      print(
          'LOG: Flight ${flightData['flight_id']} already departed/landed, not monitoring');
      return;
    }

    final String flightId = flightData['flight_id'] ?? '';

    // Obtener el último cambio de puerta (si existe) para establecer la línea base
    try {
      final QuerySnapshot lastChangeSnapshot = await _firestore
          .collection('flights')
          .doc(docId)
          .collection('history')
          .orderBy('change_time', descending: true)
          .limit(1)
          .get();

      // Si hay al menos un cambio previo, guardamos su timestamp como referencia
      if (lastChangeSnapshot.docs.isNotEmpty) {
        final lastChangeDoc = lastChangeSnapshot.docs.first;
        final Map<String, dynamic> lastChangeData =
            lastChangeDoc.data() as Map<String, dynamic>;

        if (lastChangeData.containsKey('change_time')) {
          _lastChangeTimestamps[docId] =
              lastChangeData['change_time'] as Timestamp;
          print(
              'LOG: Last gate change for flight $flightId was at ${_lastChangeTimestamps[docId]!.toDate()}');
        }
      } else {
        print('LOG: No previous gate changes for flight $flightId');
      }
    } catch (e) {
      print('LOG: Error getting last gate change: $e');
    }

    print('LOG: Starting gate monitoring for flight $flightId');

    // Suscribirse a cambios en la subcolección history del vuelo
    // Ordenamos por change_time para asegurar que obtenemos los cambios en orden cronológico
    final StreamSubscription<QuerySnapshot> subscription = _firestore
        .collection('flights')
        .doc(docId)
        .collection('history')
        .orderBy('change_time', descending: true)
        .limit(5) // Observamos los últimos cambios por si acaso
        .snapshots()
        .listen((QuerySnapshot snapshot) {
      _handleHistoryChanges(snapshot, docId, flightId);
    }, onError: (error) {
      print('LOG: Error monitoring gate changes for flight $flightId: $error');
    });

    // Guardar la suscripción para poder cancelarla más tarde
    _gateMonitorSubscriptions[docId] = subscription;
  }

  /// Maneja los cambios en la colección history
  void _handleHistoryChanges(
      QuerySnapshot snapshot, String docId, String flightId) async {
    // Si no hay documentos, no hay nada que hacer
    if (snapshot.docs.isEmpty) return;

    // Verificar si el vuelo aún existe y su estado
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

      // Obtenemos el documento más reciente (debería ser el primero ya que ordenamos por change_time descendente)
      final DocumentSnapshot latestChangeDoc = snapshot.docs.first;
      final Map<String, dynamic> latestChangeData =
          latestChangeDoc.data() as Map<String, dynamic>;

      // Verificamos si este cambio tiene timestamp
      if (!latestChangeData.containsKey('change_time')) return;

      final Timestamp changeTimestamp =
          latestChangeData['change_time'] as Timestamp;
      final Timestamp? lastKnownTimestamp = _lastChangeTimestamps[docId];

      // Verificar si este es un cambio nuevo que no hemos procesado antes
      if (lastKnownTimestamp == null ||
          changeTimestamp.compareTo(lastKnownTimestamp) > 0) {
        // Es un cambio nuevo
        final String newGate = latestChangeData['new_gate']?.toString() ?? '';
        final String oldGate = latestChangeData['old_gate']?.toString() ?? '';

        print(
            'LOG: New gate change detected for flight $flightId: $oldGate -> $newGate (at ${changeTimestamp.toDate()})');

        // Verificar que las notificaciones estén habilitadas
        final bool notificationsEnabled =
            await CacheService.getGateChangeNotificationsPreference();
        if (!notificationsEnabled) {
          print(
              'LOG: Gate change notifications disabled, not sending notification');
          // Actualizar el último timestamp conocido aunque no enviemos notificación
          _lastChangeTimestamps[docId] = changeTimestamp;
          return;
        }

        // Enviar notificación de cambio de puerta
        try {
          await _notificationService.notifyGateChange(
            flightId: flightId,
            airline: flightData['airline'] ?? '',
            destination: flightData['airport'] ?? '',
            newGate: newGate,
            oldGate: oldGate,
          );

          // Actualizar el último timestamp conocido
          _lastChangeTimestamps[docId] = changeTimestamp;
          print('LOG: Gate change notification sent for flight $flightId');
        } catch (e) {
          print('LOG: Error sending gate change notification: $e');
        }
      }
    } catch (e) {
      print('LOG: Error processing gate changes for flight $flightId: $e');
    }
  }

  /// Detiene el monitoreo de un vuelo específico
  void _stopMonitoringFlight(String docId) {
    final StreamSubscription<QuerySnapshot>? subscription =
        _gateMonitorSubscriptions[docId];
    if (subscription != null) {
      subscription.cancel();
      _gateMonitorSubscriptions.remove(docId);
      _lastChangeTimestamps.remove(docId);
      print('LOG: Stopped monitoring flight with document ID $docId');
    }
  }

  /// Detiene todo el monitoreo de cambios de puerta
  void stopMonitoring() {
    for (final subscription in _gateMonitorSubscriptions.values) {
      subscription.cancel();
    }
    _gateMonitorSubscriptions.clear();
    _lastChangeTimestamps.clear();
    print('LOG: Stopped all gate monitoring');
  }

  /// Liberar recursos al cerrar la aplicación
  void dispose() {
    stopMonitoring();
    _isInitialized = false;
  }
}
