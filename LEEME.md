# RavenGate App

Aplicación Flutter para monitoreo de vuelos en tiempo real en aeropuertos.

# Sistema de Notificaciones en RavenGate

El sistema de notificaciones de RavenGate está diseñado para mantener a los usuarios informados sobre los cambios críticos en sus vuelos en tiempo real. La aplicación implementa dos sistemas diferentes de detección y notificación: uno para cambios de puerta y otro para retrasos de vuelos, cada uno optimizado para su caso de uso específico.

## 1. Sistema de Notificación de Cambios de Puerta

### Arquitectura y Funcionamiento

El sistema de notificación de cambios de puerta funciona mediante un monitoreo en tiempo real de la base de datos Firestore. Este enfoque permite detectar y notificar cambios casi instantáneamente cuando ocurren.

#### Inicialización

- El servicio `GateMonitorService` se inicializa automáticamente al arrancar la aplicación.
- Se activa cuando el usuario se autentica y se detiene cuando cierra sesión.

```dart
FirebaseAuth.instance.authStateChanges().listen((User? user) {
  if (user != null) {
    gateMonitorService.startMonitoring();
  } else {
    gateMonitorService.stopMonitoring();
  }
});
```

#### Monitoreo en Tiempo Real

1. Al iniciar el monitoreo, el sistema obtiene todos los vuelos guardados por el usuario que no están archivados.
2. Para cada vuelo, establece una suscripción a la subcolección `history` en Firestore que contiene registros de cambios.
3. Las suscripciones utilizan el método `snapshots().listen()` para recibir actualizaciones en tiempo real:

```dart
final StreamSubscription<QuerySnapshot> subscription = _firestore
    .collection('flights')
    .doc(flightRef)
    .collection('history')
    .orderBy('change_time', descending: true)
    .limit(5)
    .snapshots()
    .listen((QuerySnapshot snapshot) {
        _handleHistoryChanges(snapshot, flightRef, flightId);
    });
```

#### Filtrado Inteligente

- Se establece un tiempo de corte (cutoff time) de 2 horas antes del horario programado del vuelo.
- Los cambios de puerta que ocurren antes de este tiempo de corte no generan notificaciones.
- Se mantiene un registro de los últimos cambios notificados para evitar duplicados.

#### Detección de Cambios Válidos

Un cambio de puerta se considera válido para notificación cuando:

1. El vuelo no ha despegado ni aterrizado (status_code ≠ 'D' o 'L').
2. El cambio tiene una marca de tiempo más reciente que el último cambio notificado.
3. El cambio ocurre después del tiempo de corte establecido.
4. Las notificaciones de cambio de puerta están habilitadas en las preferencias del usuario.

#### Presentación de la Notificación

Cuando se detecta un cambio válido, el sistema construye una notificación con:

- **Título**: "Cambio de Puerta"
- **Mensaje**: "El vuelo [ID] ([Aerolínea]) a [Destino] ha cambiado de puerta de [Puerta Antigua] a [Puerta Nueva]"

## 2. Sistema de Notificación de Retrasos de Vuelos

A diferencia del sistema de cambio de puerta, las notificaciones de retrasos funcionan mediante un sistema de comparación periódica de datos.

### Arquitectura y Funcionamiento

#### Inicialización Periódica

- El sistema se activa en la pantalla `MyDeparturesScreen` al cargar los vuelos del usuario.
- Se configura un temporizador que verifica los retrasos cada 3 minutos:

```dart
_refreshTimer = Timer.periodic(const Duration(minutes: 3), (timer) {
  _previousUserFlights = List.from(_userFlights);
  _loadUserFlights();
});
```

#### Detección de Retrasos

El detector de retrasos (`FlightDelayDetector`) utiliza una lógica de comparación entre los datos anteriores y actuales:

1. **Verificación de estado previo**: Se comprueba si el vuelo ya ha despegado (status_code = 'D') o está cancelado (status_code = 'C'). En estos casos, no se notifican retrasos.

2. **Verificación de indicador directo**: Se analiza si el campo booleano `delayed` ha cambiado de `false` a `true`.

3. **Comparación de horarios**: Si no hay un indicador directo, se comparan:

   - `schedule_time`: El horario programado original
   - `status_time`: El horario actualizado actual
   - `previousStatusTimeStr`: El último horario conocido

4. **Lógica de detección**: Un retraso se considera válido cuando:
   - El indicador `delayed` cambia de falso a verdadero, o
   - El horario actual (`status_time`) es posterior al horario programado (`schedule_time`) y además ha cambiado desde la última verificación

```dart
bool _detectDelayChange({
  required Map<String, dynamic> previousFlight,
  required Map<String, dynamic> currentFlight,
}) {
  // Verificar si el vuelo ya despegó o está cancelado
  if (currentStatus == 'D' || currentStatus == 'C') {
    return false;
  }

  // Verificar cambio en la bandera 'delayed'
  if (!wasDelayedBefore && isDelayedNow) {
    return true;
  }

  // Comparar cambios en horarios
  if (statusTimeStr.isNotEmpty) {
    if (_isTimeAfter(statusTimeFormatted, scheduleTimeFormatted)) {
      return previousStatusTimeStr != statusTimeStr;
    }
  }

  return false;
}
```

#### Presentación de la Notificación

Cuando se detecta un retraso, se construye una notificación con:

- **Título**: "Retraso de Vuelo"
- **Mensaje**: "El vuelo [ID] ([Aerolínea]) a [Destino] se ha retrasado. Nueva hora: [Nueva Hora]"

## 3. Diferencias Clave Entre los Sistemas

| Característica               | Cambios de Puerta                                      | Retrasos de Vuelos                          |
| ---------------------------- | ------------------------------------------------------ | ------------------------------------------- |
| **Mecanismo de detección**   | Escucha en tiempo real (Firestore)                     | Verificación periódica (cada 3 min)         |
| **Momento de activación**    | Inmediato                                              | Solo al ejecutar el temporizador            |
| **Fuente de datos**          | Subcolección `history`                                 | Comparación entre actualizaciones completas |
| **Prevención de duplicados** | Registro de marcas de tiempo de cambios                | Comparación con última actualización        |
| **Persistencia**             | Se mantiene activo incluso con la app en segundo plano | Solo funciona con la app en uso             |

## 4. Configuración de Canales de Notificación

La aplicación configura canales específicos para las notificaciones:

- **`_gateChangeChannelId`**: Utilizado para todas las notificaciones relacionadas con vuelos (cambios de puerta, retrasos y despegues).
- **`_foregroundServiceChannelId`**: Utilizado para el servicio en primer plano que mantiene el monitoreo activo.

Cada canal se configura con sus propias características de importancia, prioridad y comportamiento.

**Nota Importante**: Todas las notificaciones relacionadas con vuelos (incluyendo retrasos, cambios de puerta y despegues) utilizan el mismo canal de notificación (`_gateChangeChannelId`) para mantener la consistencia en la experiencia del usuario. Esto significa que comparten el mismo sonido de notificación, patrón de vibración y nivel de importancia.

```dart
// Ejemplo de configuración de canal para todas las notificaciones de vuelos
const AndroidNotificationDetails androidPlatformChannelSpecifics =
    AndroidNotificationDetails(
  _gateChangeChannelId,
  'Cambios de Puerta',
  channelDescription: 'Notificaciones de cambios de puerta',
  importance: Importance.high,
  priority: Priority.high,
  ticker: 'ticker',
  styleInformation: BigTextStyleInformation(''),
);
```

## 5. Control de Usuario

Los usuarios tienen control sobre las notificaciones a través de preferencias almacenadas:

- `CacheService.getGateChangeNotificationsPreference()`: Controla las notificaciones de cambios de puerta
- `CacheService.getDelayNotificationsPreference()`: Controla las notificaciones de retrasos
- `CacheService.getDepartureNotificationsPreference()`: Controla las notificaciones de despegues

Estas preferencias se almacenan mediante SharedPreferences y por defecto están activadas.

## 6. Gestión de Permisos

El sistema verifica y solicita los permisos necesarios para mostrar notificaciones:

```dart
Future<bool> requestPermissions() async {
  // Verificar versión de Android (para Android 13+ se requiere permiso explícito)
  if (Platform.isAndroid) {
    final int sdkInt = (await _getAndroidSdkInt()) ?? 0;
    if (sdkInt < 33) {
      return true; // No es necesario pedir permiso en Android 12 o menor
    }
  }

  // Verificar y solicitar permisos
  final status = await Permission.notification.status;
  if (status.isGranted) {
    return true;
  }
  final result = await Permission.notification.request();
  return result.isGranted;
}
```

## Consideraciones Técnicas

1. **Rendimiento y Batería**: El sistema de monitoreo de cambios de puerta utiliza un servicio en segundo plano para mantener las suscripciones activas, lo que puede tener un impacto en la duración de la batería. Por ello, se implementa:

   - Filtrado por tiempo de corte para reducir notificaciones innecesarias
   - Límite de 5 documentos por consulta
   - Cancelación de suscripciones para vuelos que ya han despegado

2. **Manejo de Errores**: Ambos sistemas implementan manejo de errores para asegurar que la aplicación siga funcionando incluso si falla la entrega de notificaciones.

3. **Depuración**: Se incluye un modo de depuración opcional para forzar notificaciones durante las pruebas:

   ```dart
   bool isDebugMode = false; // Cambiar a true para forzar notificaciones
   ```

4. **Logs Detallados**: Los sistemas generan logs detallados para facilitar la depuración, usando un formato consistente con prefijos identificativos:
   - `🔔 NOTIFICATIONS`: Para el servicio de notificaciones
   - `🚪 GATE-MONITOR`: Para el monitor de cambios de puerta

La arquitectura dual de notificaciones en RavenGate permite balancear la inmediatez necesaria para los cambios de puerta con la eficiencia energética para los retrasos de vuelos, proporcionando a los usuarios información oportuna sin comprometer la experiencia de usuario.

## Primeros pasos con el desarrollo Flutter

Este proyecto es un punto de partida para una aplicación Flutter.

Algunos recursos para comenzar si este es tu primer proyecto Flutter:

- [Lab: Escribe tu primera aplicación Flutter](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Ejemplos útiles de Flutter](https://docs.flutter.dev/cookbook)

Para obtener ayuda con el desarrollo de Flutter, consulta la
[documentación en línea](https://docs.flutter.dev/), que ofrece tutoriales,
ejemplos, orientación sobre desarrollo móvil y una referencia completa de la API.
