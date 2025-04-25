import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_init;

/// Servicio para manejar notificaciones locales en la aplicación
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// Inicializa el servicio de notificaciones
  Future<void> init() async {
    if (_initialized) {
      return;
    }

    try {
      // Inicializar timezone
      tz_init.initializeTimeZones();

      // Configuración para Android
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      // Configuración para iOS
      const DarwinInitializationSettings initializationSettingsIOS =
          DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      // Configuración general
      const InitializationSettings initializationSettings =
          InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
      );

      // Inicializar plugin
      await _flutterLocalNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse:
            (NotificationResponse response) async {
          // Esta función maneja cuando el usuario toca una notificación
          print('LOG: User tapped notification: ${response.payload}');
        },
      );

      _initialized = true;
      print('LOG: Notification service initialized');
    } catch (e) {
      print('LOG: Error initializing notifications: $e');
    }
  }

  /// Solicitar permisos para notificaciones (importante en iOS)
  Future<bool> requestPermissions() async {
    if (Platform.isIOS) {
      final bool? result = await _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()!
          .requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
      return result ?? false;
    } else if (Platform.isAndroid) {
      // En Android, usamos el método correcto para solicitar permisos
      try {
        // A partir de Android 13 (API nivel 33), se requiere solicitar permisos explícitamente
        final bool? result = await _flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.requestNotificationsPermission();

        // Si result es null (versión antigua) o true, consideramos los permisos concedidos
        return result ?? true;
      } catch (e) {
        // Si hay error, verificamos si las notificaciones están habilitadas de otra manera
        print('LOG: Error requesting permissions: $e');
        final bool? areEnabled = await _flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.areNotificationsEnabled();
        return areEnabled ??
            true; // Asumimos permisos por defecto si no podemos verificar
      }
    }
    return false;
  }

  /// Muestra una notificación inmediata
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_initialized) {
      await init();
    }

    try {
      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        'flight_delay_channel',
        'Flight Delays',
        channelDescription: 'Notifications about flight delays',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
      );

      const NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
      );

      await _flutterLocalNotificationsPlugin.show(
        id,
        title,
        body,
        platformChannelSpecifics,
        payload: payload,
      );

      print('LOG: Notification sent: $title - $body');
    } catch (e) {
      print('LOG: Error showing notification: $e');
    }
  }

  /// Notificar retraso en vuelo específico
  Future<void> notifyFlightDelay({
    required String flightId,
    required String airline,
    required String destination,
    String? newTime,
  }) async {
    final int notificationId = flightId.hashCode;
    final String title = 'Flight $flightId Delayed';
    final String body = newTime != null
        ? '$airline to $destination delayed. New time: $newTime'
        : '$airline to $destination delayed';

    await showNotification(
      id: notificationId,
      title: title,
      body: body,
      payload: flightId,
    );
  }

  /// Notificar despegue de vuelo específico
  Future<void> notifyFlightDeparture({
    required String flightId,
    required String airline,
    required String destination,
    String? departureTime,
  }) async {
    final int notificationId =
        flightId.hashCode + 1000; // Diferente ID para evitar conflictos
    final String title = 'Flight $flightId Departed';
    final String body = departureTime != null
        ? '$airline to $destination departed at $departureTime'
        : '$airline to $destination departed';

    await showNotification(
      id: notificationId,
      title: title,
      body: body,
      payload: flightId,
    );
  }

  /// Notificar cambio de puerta para un vuelo específico
  Future<void> notifyGateChange({
    required String flightId,
    required String airline,
    required String destination,
    required String newGate,
    String? oldGate,
  }) async {
    final int notificationId = flightId.hashCode +
        2000; // ID diferente para notificaciones de cambios de puerta
    final String title = 'Gate Change: Flight $flightId';
    final String body = oldGate != null
        ? '$airline to $destination: Gate changed from $oldGate to $newGate'
        : '$airline to $destination: New gate assigned: $newGate';

    await showNotification(
      id: notificationId,
      title: title,
      body: body,
      payload: flightId,
    );
  }

  /// Programar una notificación para el futuro
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'flight_reminder_channel',
      'Flight Reminders',
      channelDescription: 'Scheduled flight reminders',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails();

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    await _flutterLocalNotificationsPlugin.zonedSchedule(
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

    print(
        'LOG: Notification scheduled for ${scheduledDate.toIso8601String()}: $title');
  }

  /// Cancelar una notificación específica
  Future<void> cancelNotification(int id) async {
    await _flutterLocalNotificationsPlugin.cancel(id);
    print('LOG: Notification with ID $id canceled');
  }

  /// Cancelar todas las notificaciones
  Future<void> cancelAllNotifications() async {
    await _flutterLocalNotificationsPlugin.cancelAll();
    print('LOG: All notifications canceled');
  }
}
