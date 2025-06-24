import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../notifications/notification_service.dart';
import '../developer/developer_mode_service.dart';
import '../cache/cache_service.dart';
import '../../utils/logger.dart';
import '../../screens/home/flight_details/forms/models/oversize_item_types.dart';

/// Servicio para monitorear nuevos registros de oversize en los vuelos guardados por el usuario
class OversizeMonitorService {
  static final OversizeMonitorService _instance =
      OversizeMonitorService._internal();
  factory OversizeMonitorService() => _instance;
  OversizeMonitorService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final NotificationService _notificationService = NotificationService();

  // Streams de suscripción para monitorear registros de oversize
  final Map<String, List<StreamSubscription<QuerySnapshot>>>
      _oversizeMonitorSubscriptions = {};

  // Último timestamp conocido de registros para cada vuelo y colección
  final Map<String, Timestamp> _lastRegistrationTimestamps = {};

  // Último tiempo que se procesó un snapshot para cada colección (para throttling)
  final Map<String, DateTime> _lastSnapshotProcessed = {};

  // Verificar si ya hemos inicializado el servicio
  bool _isInitialized = false;

  /// Método interno de logging – ahora delega en AppLogger con tag 'OversizeMonitor'
  void _log(String message, {bool isError = false, String? flightId}) {
    final String flightInfo = flightId != null ? '[$flightId] ' : '';
    final String formattedMessage = '$flightInfo$message';

    if (isError) {
      AppLogger.error(formattedMessage, null, 'OversizeMonitor');
    } else {
      AppLogger.info(formattedMessage, null, 'OversizeMonitor');
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

  /// Inicializa el servicio de monitoreo de registros oversize
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Inicializar el servicio de notificaciones
    await _notificationService.init();

    // Solicitar permisos si es necesario
    await _notificationService.requestPermissions();

    _isInitialized = true;
    _log('Servicio inicializado correctamente');
  }

  /// Inicia el monitoreo de registros oversize para los vuelos del usuario actual
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

    // Verificar si el modo desarrollador está activado para mostrar notificación de prueba
    final bool isDeveloperMode =
        await DeveloperModeService.isDeveloperModeEnabled();

    _log(
        'Estado de modo desarrollador: ${isDeveloperMode ? 'ACTIVADO' : 'DESACTIVADO'}');

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

      _log(
          'Encontrados ${userFlights.docs.length} vuelos para monitorear registros oversize');

      // Primero, listar TODOS los vuelos encontrados
      for (int i = 0; i < userFlights.docs.length; i++) {
        final DocumentSnapshot flightDoc = userFlights.docs[i];
        final Map<String, dynamic> flightData =
            flightDoc.data() as Map<String, dynamic>;
        final String flightId = flightData['flight_id']?.toString() ?? '';
        final String flightRef = flightData['flight_ref']?.toString() ?? '';
        final String statusCode = flightData['status_code']?.toString() ?? '';
        final String archived = flightData['archived']?.toString() ?? '';

        _log(
            'DEBUG - Flight ${i + 1}/${userFlights.docs.length}: ID=$flightId, Ref=$flightRef, Status=$statusCode, Archived=$archived');
      }

      // Comenzar a monitorear cada vuelo
      for (final DocumentSnapshot flightDoc in userFlights.docs) {
        final Map<String, dynamic> flightData =
            flightDoc.data() as Map<String, dynamic>;
        final String flightId = flightData['flight_id']?.toString() ?? '';
        final String flightRef = flightData['flight_ref']?.toString() ?? '';

        _log(
            'DEBUG - Processing flight: $flightId with flight_ref: $flightRef');

        // Si tenemos un flight_ref válido y un ID de vuelo, comenzar a monitorear
        if (flightRef.isNotEmpty && flightId.isNotEmpty) {
          _logFlight('Iniciando monitoreo oversize con flight_ref: $flightRef',
              flightId);
          _monitorFlightOversizeRegistrations(flightRef, flightData);
        } else {
          _log('No se puede monitorear vuelo $flightId - falta flight_ref');
        }
      }
    } catch (e) {
      _logError('Error al iniciar monitoreo de registros oversize', error: e);
    }
  }

  /// Monitorea los registros de oversize para un vuelo específico
  void _monitorFlightOversizeRegistrations(
      String flightRef, Map<String, dynamic> flightData) async {
    final String flightId = flightData['flight_id'] ?? '';
    final String statusCode = flightData['status_code']?.toString() ?? '';

    // No monitorear vuelos que ya han despegado (D) o aterrizado (L)
    if (statusCode == 'D' || statusCode == 'L') {
      _logFlight(
          'Flight already departed/landed (status=$statusCode), not monitoring oversize',
          flightId,
          flightRef: flightRef);
      return;
    }

    _logFlight('Setting up oversize monitoring using flight_ref: $flightRef',
        flightId);

    // Lista para guardar todas las suscripciones de este vuelo
    final List<StreamSubscription<QuerySnapshot>> flightSubscriptions = [];

    // Monitorear cada tipo de oversize en su colección correspondiente
    for (final OversizeItemType type in OversizeItemType.values) {
      final String collectionName =
          OversizeItemTypeUtils.collectionNameForType(type);
      final String subscriptionKey = '${flightRef}_$collectionName';

      _logFlight('Setting up monitoring for $collectionName', flightId);

      try {
        // Obtener el último registro de este tipo para establecer la línea base
        final QuerySnapshot lastRegistrationSnapshot = await _firestore
            .collection('flights')
            .doc(flightRef)
            .collection(collectionName)
            .orderBy('timestamp', descending: true)
            .limit(1)
            .get();

        _logFlight(
            'DEBUG - Found ${lastRegistrationSnapshot.docs.length} existing documents in $collectionName',
            flightId);

        // Si hay al menos un registro previo, guardamos su timestamp como referencia
        if (lastRegistrationSnapshot.docs.isNotEmpty) {
          final lastRegistrationDoc = lastRegistrationSnapshot.docs.first;
          final Map<String, dynamic> lastRegistrationData =
              lastRegistrationDoc.data() as Map<String, dynamic>;

          if (lastRegistrationData.containsKey('timestamp') &&
              lastRegistrationData['timestamp'] != null) {
            _lastRegistrationTimestamps[subscriptionKey] =
                lastRegistrationData['timestamp'] as Timestamp;
            _logFlight(
                'Last $collectionName registration was at ${_lastRegistrationTimestamps[subscriptionKey]!.toDate()}',
                flightId);
          } else {
            _logFlight(
                'Last $collectionName registration found but has null timestamp',
                flightId);
          }
        } else {
          _logFlight(
              'No previous $collectionName registrations found', flightId);
        }

        // Suscribirse a cambios en la subcolección específica del vuelo
        final StreamSubscription<QuerySnapshot> subscription = _firestore
            .collection('flights')
            .doc(flightRef)
            .collection(collectionName)
            .orderBy('timestamp', descending: true)
            .limit(5) // Observamos los últimos registros por si acaso
            .snapshots()
            .listen((QuerySnapshot snapshot) {
          _logFlight(
              'Received snapshot from $collectionName with ${snapshot.docs.length} documents',
              flightId);
          _handleOversizeRegistrationChanges(
              snapshot, flightRef, flightId, flightData, type, collectionName);
        }, onError: (error) {
          _logError('Error monitoring $collectionName registrations',
              flightId: flightId, error: error);
        });

        // Añadir la suscripción a la lista
        flightSubscriptions.add(subscription);
        _logFlight('Successfully set up $collectionName stream subscription',
            flightId);
      } catch (e) {
        _logError('Failed to set up $collectionName stream subscription',
            flightId: flightId, error: e);
      }
    }

    // Guardar todas las suscripciones para poder cancelarlas más tarde
    _oversizeMonitorSubscriptions[flightRef] = flightSubscriptions;
    _logFlight(
        'Successfully set up all oversize stream subscriptions', flightId);
  }

  /// Maneja los cambios en las colecciones de oversize
  void _handleOversizeRegistrationChanges(
      QuerySnapshot snapshot,
      String flightRef,
      String flightId,
      Map<String, dynamic> flightData,
      OversizeItemType type,
      String collectionName) async {
    // Si no hay documentos, no hay nada que hacer
    if (snapshot.docs.isEmpty) {
      _logFlight('Empty $collectionName snapshot received, ignoring', flightId);
      return;
    }

    // Verificar si es un snapshot sin cambios reales (solo metadatos)
    if (snapshot.metadata.isFromCache && !snapshot.metadata.hasPendingWrites) {
      _logFlight(
          '$collectionName snapshot from cache without changes, ignoring',
          flightId);
      return;
    }

    // Throttling: no procesar snapshots muy frecuentes (menos de 2 segundos de diferencia)
    final String throttleKey = '${flightRef}_$collectionName';
    final DateTime now = DateTime.now();
    final DateTime? lastProcessed = _lastSnapshotProcessed[throttleKey];

    if (lastProcessed != null && now.difference(lastProcessed).inSeconds < 2) {
      _logFlight(
          '$collectionName snapshot throttled (too frequent - ${now.difference(lastProcessed).inSeconds}s), ignoring',
          flightId);
      return;
    }

    _logFlight(
        'DEBUG - Processing $collectionName snapshot (last processed: ${lastProcessed?.toString() ?? "never"})',
        flightId);
    _lastSnapshotProcessed[throttleKey] = now;

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

      final Map<String, dynamic> currentFlightData =
          flightDoc.data() as Map<String, dynamic>;
      final String statusCode =
          currentFlightData['status_code']?.toString() ?? '';

      // Verificar si el vuelo ya ha despegado o aterrizado
      if (statusCode == 'D' || statusCode == 'L') {
        _logFlight(
            'Flight has departed/landed (status=$statusCode), stopping oversize monitoring',
            flightId);
        _stopMonitoringFlight(flightRef);
        return;
      }

      // Obtenemos el documento más reciente (debería ser el primero ya que ordenamos por timestamp descendente)
      final DocumentSnapshot latestRegistrationDoc = snapshot.docs.first;
      final Map<String, dynamic> latestRegistrationData =
          latestRegistrationDoc.data() as Map<String, dynamic>;

      // Verificamos si este registro tiene timestamp
      if (!latestRegistrationData.containsKey('timestamp')) {
        _logFlight(
            '$collectionName registration document is missing timestamp field, ignoring',
            flightId);
        return;
      }

      // Manejar timestamp que puede ser null
      final dynamic timestampValue = latestRegistrationData['timestamp'];
      if (timestampValue == null) {
        _logFlight(
            '$collectionName registration document has null timestamp, ignoring',
            flightId);
        return;
      }

      final Timestamp registrationTimestamp = timestampValue as Timestamp;
      final String subscriptionKey = '${flightRef}_$collectionName';
      final Timestamp? lastKnownTimestamp =
          _lastRegistrationTimestamps[subscriptionKey];

      _logFlight(
          'Comparing timestamps - Current: ${registrationTimestamp.toDate()}, Last known: ${lastKnownTimestamp?.toDate() ?? 'None'}',
          flightId);

      // Verificar si este es un registro nuevo que no hemos procesado antes
      bool isNewRegistration = lastKnownTimestamp == null ||
          registrationTimestamp.compareTo(lastKnownTimestamp) > 0;

      _logFlight('DEBUG - isNewRegistration: $isNewRegistration', flightId);
      if (!isNewRegistration) {
        final int timeDiffSeconds = registrationTimestamp
            .toDate()
            .difference(lastKnownTimestamp.toDate())
            .inSeconds;
        _logFlight(
            'DEBUG - Time difference: ${timeDiffSeconds}s (${registrationTimestamp.compareTo(lastKnownTimestamp)})',
            flightId);
      }

      // Verificar que el usuario que registró no sea el usuario actual (para evitar auto-notificaciones)
      final String? registeredBy = latestRegistrationData[
          'user_id']; // Cambiado de 'registered_by' a 'user_id'
      final String? registeredByEmail = latestRegistrationData['user_email'];
      final String? currentUserId = _auth.currentUser?.uid;
      final String? currentUserEmail = _auth.currentUser?.email;

      _logFlight(
          'DEBUG - registeredBy: $registeredBy, currentUserId: $currentUserId',
          flightId);
      _logFlight(
          'DEBUG - registeredByEmail: $registeredByEmail, currentUserEmail: $currentUserEmail',
          flightId);

      // Verificar por UID o por email
      bool isSameUser = false;
      if (registeredBy != null &&
          currentUserId != null &&
          registeredBy == currentUserId) {
        isSameUser = true;
        _logFlight('DEBUG - Same user detected by UID', flightId);
      } else if (registeredByEmail != null &&
          currentUserEmail != null &&
          registeredByEmail == currentUserEmail) {
        isSameUser = true;
        _logFlight('DEBUG - Same user detected by EMAIL', flightId);
      }

      if (isSameUser) {
        _logFlight(
            'Registration was made by current user, not sending notification',
            flightId);
        // Actualizar el último timestamp conocido para futuras comparaciones
        _logFlight(
            'DEBUG - Updating timestamp (same user): ${registrationTimestamp.toDate()}',
            flightId);
        _lastRegistrationTimestamps[subscriptionKey] = registrationTimestamp;
        return;
      } else {
        _logFlight(
            'DEBUG - Different user detected, will proceed with notification',
            flightId);
      }

      _logFlight('DEBUG - Will check if registration is new...', flightId);

      if (isNewRegistration) {
        // Es un registro nuevo
        final String itemType =
            type.name; // Usar el nombre del enum directamente
        final String destination = currentFlightData['airport'] ?? '';
        final String gate = currentFlightData['gate'] ?? '';

        // Obtener la cantidad registrada del documento
        final int count = latestRegistrationData['count'] ?? 1;

        _logFlight(
            'NEW ${collectionName.toUpperCase()} REGISTRATION DETECTED: $count x $itemType for flight $flightId (at ${registrationTimestamp.toDate()})',
            flightId);

        _logFlight(
            'DEBUG - About to check notification preferences and permissions...',
            flightId);

        // Verificar si las notificaciones de oversize están habilitadas
        final bool oversizeNotificationsEnabled =
            await CacheService.getOversizeNotificationsPreference();
        if (!oversizeNotificationsEnabled) {
          _logFlight(
              'Oversize notifications are disabled by user, skipping notification',
              flightId);
          // Actualizar el timestamp para evitar reprocesar
          _lastRegistrationTimestamps[subscriptionKey] = registrationTimestamp;
          return;
        }

        // Verificar permisos de notificación de nuevo
        final bool hasPermissions =
            await _notificationService.requestPermissions();
        if (!hasPermissions) {
          _logFlight(
              'Permissions denied, cannot show oversize notification', flightId,
              isError: true);
          return;
        }

        _logFlight(
            'DEBUG - Permissions OK, about to send notification...', flightId);

        // Enviar notificación de nuevo registro oversize
        try {
          _logFlight('Intentando enviar notificación de registro oversize...',
              flightId);

          await _notificationService.notifyOversizeRegistration(
            itemType: itemType,
            count: count,
            flightId: flightId,
            destination: destination,
            gate: gate,
            flightData: currentFlightData,
          );

          // Actualizar el último timestamp conocido
          _logFlight(
              'DEBUG - Updating timestamp (notification sent): ${registrationTimestamp.toDate()}',
              flightId);
          _lastRegistrationTimestamps[subscriptionKey] = registrationTimestamp;
          _logFlight(
              'Oversize registration notification sent successfully', flightId);
        } catch (e) {
          _logError('Error sending oversize registration notification',
              flightId: flightId, error: e);
        }
      } else {
        _logFlight(
            'This $collectionName registration is not new or has already been processed, ignoring',
            flightId);
        _logFlight(
            'DEBUG - Registration timestamp: ${registrationTimestamp.toDate()}, Last known: ${lastKnownTimestamp.toDate()}',
            flightId);
      }
    } catch (e) {
      _logError('Error processing $collectionName registration changes',
          flightId: flightId, error: e);
    }
  }

  /// Detiene el monitoreo de un vuelo específico
  void _stopMonitoringFlight(String flightRef) {
    final List<StreamSubscription<QuerySnapshot>>? subscriptions =
        _oversizeMonitorSubscriptions[flightRef];
    if (subscriptions != null) {
      for (final subscription in subscriptions) {
        subscription.cancel();
      }
      _oversizeMonitorSubscriptions.remove(flightRef);

      // Remover todos los timestamps de este vuelo
      final List<String> keysToRemove = _lastRegistrationTimestamps.keys
          .where((key) => key.startsWith('${flightRef}_'))
          .toList();
      for (final key in keysToRemove) {
        _lastRegistrationTimestamps.remove(key);
        _lastSnapshotProcessed.remove(key);
      }

      _log('Monitoreo oversize detenido para vuelo con flight_ref: $flightRef');
    }
  }

  /// Detiene todo el monitoreo de registros oversize
  void stopMonitoring() {
    _log(
        'Deteniendo todas las suscripciones de monitoreo oversize (cantidad: ${_oversizeMonitorSubscriptions.length})');
    for (final subscriptions in _oversizeMonitorSubscriptions.values) {
      for (final subscription in subscriptions) {
        subscription.cancel();
      }
    }
    _oversizeMonitorSubscriptions.clear();
    _lastRegistrationTimestamps.clear();
    _lastSnapshotProcessed.clear();
    _log('Todas las suscripciones de monitoreo oversize han sido canceladas');
  }

  /// Liberar recursos al cerrar la aplicación
  void dispose() {
    stopMonitoring();
    _isInitialized = false;
    _log('Servicio de monitoreo oversize disposed');
  }
}
