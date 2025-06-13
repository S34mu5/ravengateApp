import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../notifications/notification_service.dart';
import '../cache/cache_service.dart';
import '../developer/developer_mode_service.dart';
import '../../utils/logger.dart';

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

  // Último valor conocido de las marcas de tiempo del cambio de puerta para cada vuelo
  final Map<String, DateTime> _flightCutoffTimes = {};

  // Prefix para los logs de este servicio

  /// Método interno de logging – ahora delega en AppLogger con tag 'GateMonitor'
  void _log(String message, {bool isError = false, String? flightId}) {
    final String flightInfo = flightId != null ? '[$flightId] ' : '';
    final String formattedMessage = '$flightInfo$message';

    if (isError) {
      AppLogger.error(formattedMessage, null, 'GateMonitor');
    } else {
      AppLogger.info(formattedMessage, null, 'GateMonitor');
    }
  }

  /// Log con nivel de error
  void _logError(String message, {String? flightId, Object? error}) {
    final String errorInfo = error != null ? ' - Error: $error' : '';
    _log('$message$errorInfo', isError: true, flightId: flightId);
  }

  /// Log de nivel informativo específico de un vuelo
  void _logFlight(String message, String flightId,
      {String? flightRef, bool isError = false}) {
    final String refInfo = flightRef != null ? ' (Ref: $flightRef)' : '';
    _log('$message$refInfo', flightId: flightId, isError: isError);
  }

  /// Inicializa el servicio de monitoreo de cambios de puerta
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Inicializar el servicio de notificaciones
    await _notificationService.init();

    // Solicitar permisos si es necesario
    await _notificationService.requestPermissions();

    _isInitialized = true;
    _log('Servicio inicializado correctamente');
  }

  /// Inicia el monitoreo de cambios de puerta para los vuelos del usuario actual
  Future<void> startMonitoring() async {
    if (!_isInitialized) {
      await initialize();
    }

    // Verificar si el usuario está autenticado
    final User? currentUser = _auth.currentUser;
    if (currentUser == null) {
      _log('No se puede iniciar monitoreo: usuario no autenticado');
      return;
    }

    // Verificar explícitamente los permisos de notificación
    final bool hasPermissions = await _notificationService.requestPermissions();
    if (!hasPermissions) {
      _log('No se puede iniciar monitoreo: permisos de notificación denegados',
          isError: true);
      return;
    }

    // Verificar si las notificaciones de cambio de puerta están habilitadas
    final bool notificationsEnabled =
        await CacheService.getGateChangeNotificationsPreference();
    _log(
        'Estado de notificaciones de cambio de puerta: ${notificationsEnabled ? 'ACTIVADAS' : 'DESACTIVADAS'}');

    // Verificar si el modo desarrollador está activado para mostrar notificación de prueba
    final bool isDeveloperMode =
        await DeveloperModeService.isDeveloperModeEnabled();

    _log(
        'Estado de modo desarrollador: ${isDeveloperMode ? 'ACTIVADO' : 'DESACTIVADO'}');

    // Enviar notificación de prueba sólo si el modo desarrollador está activado
    // (independientemente de la configuración de notificaciones)
    if (isDeveloperMode) {
      try {
        _log(
            'Modo desarrollador activado: enviando notificación de prueba para verificar configuración...');

        // Forzar verificación de permisos de nuevo
        final bool hasNotificationPermission =
            await _notificationService.requestPermissions();

        if (!hasNotificationPermission) {
          _logError(
              'No se pudo enviar notificación de prueba: permisos denegados');
          return;
        }

        // Enviar notificación con alta prioridad para asegurar que se muestre
        await _notificationService.showNotification(
          id: 9999,
          title: 'Prueba de Notificaciones (Dev)',
          body: 'Monitoreo de cambios de puerta iniciado correctamente.',
        );

        _log('Notificación de prueba enviada correctamente');

        // Enviar otra notificación 2 segundos después para confirmar que el servicio sigue funcionando
        await Future.delayed(const Duration(seconds: 2));

        await _notificationService.showNotification(
          id: 10000,
          title: 'Confirmación (Dev)',
          body: 'El servicio de notificaciones está funcionando correctamente.',
        );

        _log('Segunda notificación de prueba enviada correctamente');
      } catch (e) {
        _logError('Error al enviar notificación de prueba', error: e);
      }
    } else {
      _log('Modo desarrollador desactivado: omitiendo notificación de prueba');
    }

    // Si las notificaciones están desactivadas y no estamos en modo desarrollador, no continuamos
    if (!notificationsEnabled && !isDeveloperMode) {
      _log(
          'Monitoreo desactivado: notificaciones de cambios de puerta deshabilitadas');
      return;
    }

    try {
      // Detener cualquier monitoreo previo para evitar duplicados
      stopMonitoring();

      // Obtener los vuelos guardados por el usuario
      _log('Obteniendo vuelos guardados del usuario ${currentUser.uid}...');
      final QuerySnapshot userFlights = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('saved_flights')
          .where('archived',
              isEqualTo: false) // No monitorear vuelos archivados
          .get();

      _log('Encontrados ${userFlights.docs.length} vuelos para monitorear');

      // Comenzar a monitorear cada vuelo
      for (final DocumentSnapshot flightDoc in userFlights.docs) {
        final Map<String, dynamic> flightData =
            flightDoc.data() as Map<String, dynamic>;
        final String flightId = flightData['flight_id']?.toString() ?? '';
        final String flightRef = flightData['flight_ref']?.toString() ?? '';

        // Si tenemos un flight_ref válido y un ID de vuelo, comenzar a monitorear
        if (flightRef.isNotEmpty && flightId.isNotEmpty) {
          _logFlight(
              'Iniciando monitoreo con flight_ref: $flightRef', flightId);
          _monitorFlightGate(flightRef, flightData);
        } else {
          _log('No se puede monitorear vuelo $flightId - falta flight_ref');
        }
      }
    } catch (e) {
      _logError('Error al iniciar monitoreo de cambios de puerta', error: e);
    }
  }

  /// Monitorea los cambios de puerta para un vuelo específico
  void _monitorFlightGate(
      String flightRef, Map<String, dynamic> flightData) async {
    // Verificar el estado del vuelo
    final String statusCode = flightData['status_code']?.toString() ?? '';
    final String flightId = flightData['flight_id'] ?? '';

    // No monitorear vuelos que ya han despegado (D) o aterrizado (L)
    if (statusCode == 'D' || statusCode == 'L') {
      _logFlight(
          'Flight already departed/landed (status=$statusCode), not monitoring',
          flightId,
          flightRef: flightRef);
      return;
    }

    _logFlight('Setting up monitoring using flight_ref: $flightRef', flightId);

    // Calcular el tiempo de corte (2 horas antes del horario programado)
    DateTime? cutoffTime;
    try {
      final String scheduleTimeStr =
          flightData['schedule_time']?.toString() ?? '';
      if (scheduleTimeStr.isNotEmpty) {
        // Crear un objeto DateTime basado en schedule_time
        DateTime scheduleDateTime;

        // Comprobar si está en formato ISO 8601 (contiene 'T')
        if (scheduleTimeStr.contains('T')) {
          scheduleDateTime = DateTime.parse(scheduleTimeStr);
        } else {
          // Está en formato HH:MM, necesitamos crear un DateTime para hoy
          final List<String> timeParts = scheduleTimeStr.split(':');
          if (timeParts.length == 2) {
            final int hour = int.parse(timeParts[0]);
            final int minute = int.parse(timeParts[1]);
            final DateTime now = DateTime.now();
            scheduleDateTime =
                DateTime(now.year, now.month, now.day, hour, minute);
          } else {
            throw FormatException('Invalid time format: $scheduleTimeStr');
          }
        }

        // Calcular 2 horas antes del tiempo programado
        cutoffTime = scheduleDateTime.subtract(const Duration(hours: 2));
        _logFlight(
            'Cutoff time for notifications set to: ${cutoffTime.toIso8601String()}',
            flightId);
      }
    } catch (e) {
      _logError('Error calculating cutoff time', flightId: flightId, error: e);
      // Si hay un error, continuamos sin filtrar
    }

    // Obtener el último cambio de puerta (si existe) para establecer la línea base
    try {
      _logFlight(
          'Checking history collection at path: flights/$flightRef/history',
          flightId);

      final QuerySnapshot lastChangeSnapshot = await _firestore
          .collection('flights')
          .doc(flightRef)
          .collection('history')
          .orderBy('change_time', descending: true)
          .limit(1)
          .get();

      // Si hay al menos un cambio previo, guardamos su timestamp como referencia
      if (lastChangeSnapshot.docs.isNotEmpty) {
        final lastChangeDoc = lastChangeSnapshot.docs.first;
        final Map<String, dynamic> lastChangeData =
            lastChangeDoc.data() as Map<String, dynamic>;

        _logFlight(
            'Found history document with data: ${lastChangeData.toString().substring(0, min(lastChangeData.toString().length, 100))}...',
            flightId);

        if (lastChangeData.containsKey('change_time')) {
          _lastChangeTimestamps[flightRef] =
              lastChangeData['change_time'] as Timestamp;
          _logFlight(
              'Last gate change was at ${_lastChangeTimestamps[flightRef]!.toDate()}',
              flightId);

          // Si hay un tiempo de corte y el último cambio es anterior a ese tiempo, lo ignoramos
          if (cutoffTime != null &&
              _lastChangeTimestamps[flightRef]!.toDate().isBefore(cutoffTime)) {
            _logFlight(
                'Last gate change is before cutoff time (${cutoffTime.toIso8601String()}), ignoring',
                flightId);
            // No guardamos este timestamp para que no se use como referencia
            _lastChangeTimestamps.remove(flightRef);
          }
        }
      } else {
        _logFlight('No previous gate changes found in history', flightId);
      }
    } catch (e) {
      _logError('Error getting last gate change', flightId: flightId, error: e);
    }

    _logFlight(
        'Starting gate monitoring using flight_ref: $flightRef', flightId);

    // Guardar el tiempo de corte para este vuelo
    if (cutoffTime != null) {
      _flightCutoffTimes[flightRef] = cutoffTime;
    }

    // Suscribirse a cambios en la subcolección history del vuelo
    // Ordenamos por change_time para asegurar que obtenemos los cambios en orden cronológico
    try {
      final StreamSubscription<QuerySnapshot> subscription = _firestore
          .collection('flights')
          .doc(flightRef)
          .collection('history')
          .orderBy('change_time', descending: true)
          .limit(5) // Observamos los últimos cambios por si acaso
          .snapshots()
          .listen((QuerySnapshot snapshot) {
        _logFlight(
            'Received snapshot from history with ${snapshot.docs.length} documents',
            flightId);
        _handleHistoryChanges(snapshot, flightRef, flightId);
      }, onError: (error) {
        _logError('Error monitoring gate changes',
            flightId: flightId, error: error);
      });

      // Guardar la suscripción para poder cancelarla más tarde
      _gateMonitorSubscriptions[flightRef] = subscription;
      _logFlight('Successfully set up stream subscription', flightId);
    } catch (e) {
      _logError('Failed to set up stream subscription',
          flightId: flightId, error: e);
    }
  }

  /// Maneja los cambios en la colección history
  void _handleHistoryChanges(
      QuerySnapshot snapshot, String flightRef, String flightId) async {
    // Si no hay documentos, no hay nada que hacer
    if (snapshot.docs.isEmpty) {
      _logFlight('Empty snapshot received, ignoring', flightId);
      return;
    }

    // Verificar si el vuelo aún existe y su estado
    try {
      _logFlight(
          'Verifying flight document exists at: flights/$flightRef', flightId);
      final DocumentSnapshot flightDoc =
          await _firestore.collection('flights').doc(flightRef).get();

      if (!flightDoc.exists) {
        _logFlight(
            'Flight document with flight_ref=$flightRef no longer exists',
            flightId);
        _stopMonitoringFlight(flightRef);
        return;
      }

      final Map<String, dynamic> flightData =
          flightDoc.data() as Map<String, dynamic>;
      final String statusCode = flightData['status_code']?.toString() ?? '';

      // Verificar si el vuelo ya ha despegado o aterrizado
      if (statusCode == 'D' || statusCode == 'L') {
        _logFlight(
            'Flight has departed/landed (status=$statusCode), stopping monitoring',
            flightId);
        _stopMonitoringFlight(flightRef);
        return;
      }

      // Obtenemos el documento más reciente (debería ser el primero ya que ordenamos por change_time descendente)
      final DocumentSnapshot latestChangeDoc = snapshot.docs.first;
      final Map<String, dynamic> latestChangeData =
          latestChangeDoc.data() as Map<String, dynamic>;

      // Verificamos si este cambio tiene timestamp
      if (!latestChangeData.containsKey('change_time')) {
        _logFlight('History document is missing change_time field, ignoring',
            flightId);
        return;
      }

      final Timestamp changeTimestamp =
          latestChangeData['change_time'] as Timestamp;
      final DateTime changeDateTime = changeTimestamp.toDate();
      final Timestamp? lastKnownTimestamp = _lastChangeTimestamps[flightRef];
      final DateTime? cutoffTime = _flightCutoffTimes[flightRef];

      _logFlight(
          'Comparing timestamps - Current: ${changeTimestamp.toDate()}, Last known: ${lastKnownTimestamp?.toDate() ?? 'None'}',
          flightId);

      // Verificar si el cambio es anterior al tiempo de corte (2 horas antes del horario programado)
      if (cutoffTime != null && changeDateTime.isBefore(cutoffTime)) {
        _logFlight(
            'Gate change at ${changeDateTime.toIso8601String()} is before cutoff time ${cutoffTime.toIso8601String()}, ignoring',
            flightId);
        return;
      }

      // Si el modo desarrollador está activado, forzamos la notificación (útil en pruebas)
      final bool isDebugMode =
          await DeveloperModeService.isDeveloperModeEnabled();

      // Verificar si este es un cambio nuevo que no hemos procesado antes
      bool isNewChange = lastKnownTimestamp == null ||
          changeTimestamp.compareTo(lastKnownTimestamp) > 0 ||
          isDebugMode;

      // Verificar si este es un cambio nuevo que no hemos procesado antes
      if (isNewChange) {
        // Es un cambio nuevo
        final String newGate = latestChangeData['new_gate']?.toString() ?? '';
        final String oldGate = latestChangeData['old_gate']?.toString() ?? '';

        _logFlight(
            '${isDebugMode ? "[DEBUG FORCE] " : ""}NEW GATE CHANGE DETECTED: $oldGate -> $newGate (at ${changeTimestamp.toDate()})',
            flightId);

        // Verificar que las notificaciones estén habilitadas
        final bool notificationsEnabled =
            await CacheService.getGateChangeNotificationsPreference();
        if (!notificationsEnabled) {
          _logFlight(
              'Gate change notifications disabled, not sending notification',
              flightId);
          // Actualizar el último timestamp conocido aunque no enviemos notificación
          _lastChangeTimestamps[flightRef] = changeTimestamp;
          return;
        }

        // Verificar permisos de notificación de nuevo
        final bool hasPermissions =
            await _notificationService.requestPermissions();
        if (!hasPermissions) {
          _logFlight('Permissions denied, cannot show notification', flightId,
              isError: true);
          return;
        }

        // Enviar notificación de cambio de puerta
        try {
          _logFlight('Intentando enviar notificación de cambio de puerta...',
              flightId);

          await _notificationService.notifyGateChange(
            flightId: flightId,
            airline: flightData['airline'] ?? '',
            destination: flightData['airport'] ?? '',
            newGate: newGate,
            oldGate: oldGate,
          );

          // Actualizar el último timestamp conocido
          _lastChangeTimestamps[flightRef] = changeTimestamp;
          _logFlight('Gate change notification sent successfully', flightId);
        } catch (e) {
          _logError('Error sending gate change notification',
              flightId: flightId, error: e);
        }
      } else {
        _logFlight(
            'This gate change is not new or has already been processed, ignoring',
            flightId);
      }
    } catch (e) {
      _logError('Error processing gate changes', flightId: flightId, error: e);
    }
  }

  /// Detiene el monitoreo de un vuelo específico
  void _stopMonitoringFlight(String flightRef) {
    final StreamSubscription<QuerySnapshot>? subscription =
        _gateMonitorSubscriptions[flightRef];
    if (subscription != null) {
      subscription.cancel();
      _gateMonitorSubscriptions.remove(flightRef);
      _lastChangeTimestamps.remove(flightRef);
      _flightCutoffTimes.remove(flightRef);
      _log('Monitoreo detenido para vuelo con flight_ref: $flightRef');
    }
  }

  /// Detiene todo el monitoreo de cambios de puerta
  void stopMonitoring() {
    _log(
        'Deteniendo todas las suscripciones de monitoreo (cantidad: ${_gateMonitorSubscriptions.length})');
    for (final subscription in _gateMonitorSubscriptions.values) {
      subscription.cancel();
    }
    _gateMonitorSubscriptions.clear();
    _lastChangeTimestamps.clear();
    _flightCutoffTimes.clear();
    _log('Todas las suscripciones de monitoreo han sido canceladas');
  }

  /// Liberar recursos al cerrar la aplicación
  void dispose() {
    stopMonitoring();
    _isInitialized = false;
    _log('Recursos liberados - servicio desactivado');
  }
}
