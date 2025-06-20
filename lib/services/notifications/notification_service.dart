import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz_init;
import 'package:timezone/timezone.dart' as tz;
import '../developer/developer_mode_service.dart';
import '../../utils/logger.dart';
import '../../screens/home/flight_details/utils/flight_formatters.dart';
import '../../l10n/app_localizations.dart';
import '../localization/language_service.dart';

/// Servicio para manejar notificaciones locales en la aplicación
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final FlutterBackgroundService _backgroundService =
      FlutterBackgroundService();

  // ID para la notificación del servicio en primer plano
  static const int _foregroundServiceNotificationId = 8888;
  // Canal para el servicio en primer plano
  static const String _foregroundServiceChannelId =
      'ravengate_foreground_service';
  // Canal para las notificaciones de cambio de puerta
  static const String _gateChangeChannelId = 'ravengate_gate_changes';

  // Prefix para los logs de este servicio

  /// Método interno de logging – ahora delega en AppLogger con tag 'Notifications'
  void _log(String message, {bool isError = false}) {
    if (isError) {
      AppLogger.error(message, null, 'Notifications');
    } else {
      AppLogger.info(message, null, 'Notifications');
    }
  }

  /// Inicializa el servicio de notificaciones
  Future<void> init() async {
    _log('Inicializando servicio de notificaciones...');

    // Inicializar timezone
    tz_init.initializeTimeZones();

    // Configurar canales de notificación para Android
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // Configurar inicialización para iOS
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    // Configurar inicialización para Linux
    const LinuxInitializationSettings initializationSettingsLinux =
        LinuxInitializationSettings(
      defaultActionName: 'Open notification',
    );

    // Configurar inicialización general
    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
      linux: initializationSettingsLinux,
    );

    // Inicializar el plugin de notificaciones
    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        _log('Notificación recibida: ${response.payload}');
      },
    );

    // Configurar canales de notificación para Android
    await _setupNotificationChannels();

    // Inicializar el servicio en segundo plano
    await _initializeBackgroundService();

    _log('Servicio de notificaciones inicializado correctamente');
  }

  /// Configura los canales de notificación para Android
  Future<void> _setupNotificationChannels() async {
    // Canal para el servicio en primer plano
    const AndroidNotificationChannel foregroundServiceChannel =
        AndroidNotificationChannel(
      _foregroundServiceChannelId,
      'RavenGate Monitor',
      description: 'Monitoreo de cambios de puerta en tiempo real',
      importance: Importance.low,
      enableVibration: false,
      showBadge: false,
    );

    // Canal para notificaciones de cambio de puerta
    const AndroidNotificationChannel gateChangeChannel =
        AndroidNotificationChannel(
      _gateChangeChannelId,
      'Cambios de Puerta',
      description: 'Notificaciones de cambios de puerta',
      importance: Importance.high,
      enableVibration: true,
      showBadge: true,
    );

    // Crear los canales
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(foregroundServiceChannel);

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(gateChangeChannel);

    _log('Canales de notificación configurados');
  }

  /// Inicializa el servicio en segundo plano
  Future<void> _initializeBackgroundService() async {
    // Verificar si el modo desarrollador está activado
    final bool isDeveloperMode =
        await DeveloperModeService.isDeveloperModeEnabled();

    await _backgroundService.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: true,
        isForegroundMode:
            isDeveloperMode, // Solo modo foreground si es developer
        notificationChannelId: _foregroundServiceChannelId,
        initialNotificationTitle: 'RavenGate Monitor',
        initialNotificationContent: 'Monitoreando cambios de puerta',
        foregroundServiceNotificationId: _foregroundServiceNotificationId,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: true,
        onForeground: onStart,
        onBackground: _onIosBackground,
      ),
    );

    _log(
        'Servicio en segundo plano inicializado ${isDeveloperMode ? 'en modo desarrollador' : 'en modo normal'}');
  }

  /// Función que se ejecuta cuando el servicio en segundo plano se inicia en iOS
  @pragma('vm:entry-point')
  static Future<bool> _onIosBackground(ServiceInstance service) async {
    return true;
  }

  /// Función que se ejecuta cuando el servicio en segundo plano inicia
  @pragma('vm:entry-point')
  static Future<void> onStart(ServiceInstance service) async {
    // Constantes que necesitamos acceder en el método estático
    const String foregroundServiceChannelId = 'ravengate_foreground_service';
    const int foregroundServiceNotificationId = 8888;

    // Si es Android, configurar el servicio en primer plano
    if (service is AndroidServiceInstance) {
      service.on('setAsForeground').listen((event) {
        service.setAsForegroundService();
      });

      service.on('setAsBackground').listen((event) {
        service.setAsBackgroundService();
      });
    }

    // Mantener el servicio activo
    service.on('stopService').listen((event) {
      service.stopSelf();
    });

    // Inicializar timezone
    tz_init.initializeTimeZones();

    // Verificar si el modo desarrollador está activado
    bool isDeveloperMode = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      isDeveloperMode = prefs.getBool('developer_mode_enabled') ?? false;
      AppLogger.info(
          'NOTIFICATIONS: Estado de modo desarrollador: ${isDeveloperMode ? 'ACTIVADO' : 'DESACTIVADO'}');
    } catch (e) {
      AppLogger.error(
          'NOTIFICATIONS: Error al verificar modo desarrollador', e);
    }

    // Crear notificación para el servicio en primer plano (siempre, independientemente del modo)
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      foregroundServiceChannelId,
      'RavenGate Monitor',
      channelDescription: 'Monitoreo de cambios de puerta en tiempo real',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      showWhen: false,
    );

    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    // Mostrar la notificación del servicio en primer plano solo si estamos en modo desarrollador
    if (isDeveloperMode) {
      await FlutterLocalNotificationsPlugin().show(
        foregroundServiceNotificationId,
        'RavenGate Monitor (Dev)',
        'Monitoreando cambios de puerta (Modo desarrollador)',
        platformChannelSpecifics,
      );

      // Mantener el servicio activo
      Timer.periodic(const Duration(seconds: 1), (timer) async {
        if (service is AndroidServiceInstance) {
          if (await service.isForegroundService()) {
            // Actualizar la notificación del servicio en primer plano
            await FlutterLocalNotificationsPlugin().show(
              foregroundServiceNotificationId,
              'RavenGate Monitor (Dev)',
              'Monitoreando cambios de puerta (Modo desarrollador)',
              platformChannelSpecifics,
            );
          }
        }
      });

      // Enviar una notificación adicional para confirmar que el modo desarrollador está activo
      try {
        await FlutterLocalNotificationsPlugin().show(
          9998,
          'Modo Desarrollador Activo',
          'Las notificaciones de depuración están habilitadas',
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'ravengate_gate_changes',
              'Cambios de Puerta',
              channelDescription: 'Notificaciones de cambios de puerta',
              importance: Importance.high,
              priority: Priority.high,
            ),
          ),
        );
        AppLogger.info(
            '🔔 NOTIFICATIONS: Notificación de modo desarrollador enviada correctamente');
      } catch (e) {
        AppLogger.error(
            '🔔 NOTIFICATIONS: Error al enviar notificación de modo desarrollador',
            e);
      }
    }
  }

  /// Inicia el servicio en segundo plano
  Future<void> startBackgroundService() async {
    await _backgroundService.startService();
    _log('Servicio en segundo plano iniciado');
  }

  /// Detiene el servicio en segundo plano
  Future<void> stopBackgroundService() async {
    _backgroundService.invoke('stopService');
    _log('Servicio en segundo plano detenido');
  }

  /// Solicita permisos de notificación
  Future<bool> requestPermissions() async {
    _log('Solicitando permisos de notificación...');

    try {
      // Verificar si ya tenemos permisos
      final status = await Permission.notification.status;

      if (status.isGranted) {
        _log('Permisos de notificación ya concedidos');
        return true;
      }

      // Verificar versión de Android
      if (Platform.isAndroid) {
        final int sdkInt = (await _getAndroidSdkInt()) ?? 0;

        if (sdkInt < 33) {
          _log('Android SDK < 33, no se requieren permisos de notificación');
          return true; // No es necesario pedir permiso en Android 12 o menor
        }
      }

      // Solicitar permisos explícitamente
      _log('Solicitando permisos de notificación al usuario...');
      final result = await Permission.notification.request();
      final bool isGranted = result.isGranted;

      _log(
          isGranted
              ? 'Permisos de notificación concedidos'
              : 'Permisos de notificación denegados',
          isError: !isGranted);

      // Si los permisos están denegados en iOS, abrimos la configuración
      if (!isGranted && Platform.isIOS) {
        _log('Intentando abrir la configuración de la app para iOS');
        await openAppSettings();
      }

      return isGranted;
    } catch (e) {
      _log('Error solicitando permisos de notificación: $e', isError: true);
      return false;
    }
  }

  /// Obtiene el SDK de Android en ejecución
  Future<int?> _getAndroidSdkInt() async {
    try {
      final String version =
          await Process.run('getprop', ['ro.build.version.sdk'])
              .then((result) => result.stdout.toString().trim());
      return int.tryParse(version);
    } catch (e) {
      _log('Error obteniendo SDK de Android: $e', isError: true);
      return null;
    }
  }

  /// Muestra una notificación de cambio de puerta
  Future<void> notifyGateChange({
    required String flightId,
    required String airline,
    required String destination,
    required String newGate,
    required String oldGate,
    required DateTime changeDateTime,
  }) async {
    _log('Preparando notificación de cambio de puerta para vuelo $flightId');

    // Configurar detalles de la notificación para Android
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

    // Configurar detalles de la notificación para iOS
    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    // Configurar detalles generales de la notificación
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    // Generar un ID único para la notificación
    final int notificationId = DateTime.now().millisecondsSinceEpoch % 10000;

    // Crear el mensaje de la notificación
    final String formattedDate =
        FlightFormatters.formatDateTime(changeDateTime);

    // Obtener el locale actual desde LanguageService
    final Locale currentLocale = await LanguageService.getSavedLanguage();
    final AppLocalizations localizations =
        lookupAppLocalizations(currentLocale);

    final String notificationTitle = localizations.gateChangeNotificationTitle;
    final String notificationBody = localizations.gateChangeNotificationBody(
        flightId, airline, destination, oldGate, newGate, formattedDate);

    try {
      // Mostrar la notificación
      await _notificationsPlugin.show(
        notificationId,
        notificationTitle,
        notificationBody,
        platformChannelSpecifics,
        payload: 'flight:$flightId',
      );

      _log('Notificación de cambio de puerta enviada correctamente');
    } catch (e) {
      _log('Error al enviar notificación de cambio de puerta: $e',
          isError: true);
      rethrow;
    }
  }

  /// Muestra una notificación de registro de oversize
  Future<void> notifyOversizeRegistration({
    required String itemType,
    required String flightId,
    required String airline,
    required String destination,
    required String gate,
  }) async {
    _log('Preparando notificación de registro oversize para vuelo $flightId');

    // Configurar detalles de la notificación para Android
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

    // Configurar detalles de la notificación para iOS
    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    // Configurar detalles generales de la notificación
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    // Generar un ID único para la notificación
    final int notificationId = DateTime.now().millisecondsSinceEpoch % 10000;

    // Obtener el locale actual desde LanguageService
    final Locale currentLocale = await LanguageService.getSavedLanguage();
    final AppLocalizations localizations =
        lookupAppLocalizations(currentLocale);

    final String notificationTitle =
        localizations.oversizeRegistrationNotificationTitle;
    final String notificationBody =
        localizations.oversizeRegistrationNotificationBody(
            itemType, flightId, airline, destination, gate);

    try {
      // Mostrar la notificación
      await _notificationsPlugin.show(
        notificationId,
        notificationTitle,
        notificationBody,
        platformChannelSpecifics,
        payload: 'flight:$flightId',
      );

      _log('Notificación de registro oversize enviada correctamente');
    } catch (e) {
      _log('Error al enviar notificación de registro oversize: $e',
          isError: true);
      rethrow;
    }
  }

  /// Muestra una notificación genérica
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    _log('Preparando notificación genérica: $title');

    // Configurar detalles de la notificación para Android
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      _gateChangeChannelId,
      'Cambios de Puerta',
      channelDescription: 'Notificaciones de cambios de puerta',
      importance: Importance.high,
      priority: Priority.high,
      ticker: 'ticker',
    );

    // Configurar detalles de la notificación para iOS
    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    // Configurar detalles generales de la notificación
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    try {
      // Mostrar la notificación
      await _notificationsPlugin.show(
        id,
        title,
        body,
        platformChannelSpecifics,
        payload: payload,
      );

      _log('Notificación genérica enviada correctamente');
    } catch (e) {
      _log('Error al enviar notificación genérica: $e', isError: true);
      rethrow;
    }
  }

  /// Programa una notificación para una fecha específica
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    _log('Programando notificación para ${scheduledDate.toIso8601String()}');

    // Configurar detalles de la notificación para Android
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      _gateChangeChannelId,
      'Cambios de Puerta',
      channelDescription: 'Notificaciones de cambios de puerta',
      importance: Importance.high,
      priority: Priority.high,
      ticker: 'ticker',
    );

    // Configurar detalles de la notificación para iOS
    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    // Configurar detalles generales de la notificación
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    try {
      // Programar la notificación
      await _notificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(scheduledDate, tz.local),
        platformChannelSpecifics,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );

      _log('Notificación programada correctamente');
    } catch (e) {
      _log('Error al programar notificación: $e', isError: true);
      rethrow;
    }
  }

  /// Cancela una notificación programada
  Future<void> cancelScheduledNotification(int id) async {
    _log('Cancelando notificación programada con ID: $id');
    await _notificationsPlugin.cancel(id);
  }

  /// Cancela todas las notificaciones programadas
  Future<void> cancelAllScheduledNotifications() async {
    _log('Cancelando todas las notificaciones programadas');
    await _notificationsPlugin.cancelAll();
  }

  /// Muestra una notificación de retraso de vuelo
  Future<void> notifyFlightDelay({
    required String flightId,
    required String airline,
    required String destination,
    required String newTime,
  }) async {
    _log('Preparando notificación de retraso para vuelo $flightId');

    // Configurar detalles de la notificación para Android
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

    // Configurar detalles de la notificación para iOS
    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    // Configurar detalles generales de la notificación
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    // Generar un ID único para la notificación
    final int notificationId = DateTime.now().millisecondsSinceEpoch % 10000;

    // Crear el mensaje de la notificación
    final String notificationBody =
        'El vuelo $flightId ($airline) a $destination se ha retrasado. Nueva hora: $newTime';

    try {
      // Mostrar la notificación
      await _notificationsPlugin.show(
        notificationId,
        'Retraso de Vuelo',
        notificationBody,
        platformChannelSpecifics,
        payload: 'flight:$flightId',
      );

      _log('Notificación de retraso de vuelo enviada correctamente');
    } catch (e) {
      _log('Error al enviar notificación de retraso de vuelo: $e',
          isError: true);
      rethrow;
    }
  }

  /// Muestra una notificación de despegue de vuelo
  Future<void> notifyFlightDeparture({
    required String flightId,
    required String airline,
    required String destination,
    required String departureTime,
  }) async {
    _log('Preparando notificación de despegue para vuelo $flightId');

    // Configurar detalles de la notificación para Android
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

    // Configurar detalles de la notificación para iOS
    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    // Configurar detalles generales de la notificación
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    // Generar un ID único para la notificación
    final int notificationId = DateTime.now().millisecondsSinceEpoch % 10000;

    // Crear el mensaje de la notificación
    final String notificationBody =
        'El vuelo $flightId ($airline) a $destination ha despegado a las $departureTime';

    try {
      // Mostrar la notificación
      await _notificationsPlugin.show(
        notificationId,
        'Despegue de Vuelo',
        notificationBody,
        platformChannelSpecifics,
        payload: 'flight:$flightId',
      );

      _log('Notificación de despegue de vuelo enviada correctamente');
    } catch (e) {
      _log('Error al enviar notificación de despegue de vuelo: $e',
          isError: true);
      rethrow;
    }
  }
}
