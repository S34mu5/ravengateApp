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
          print('LOG: Usuario tocó notificación: ${response.payload}');
        },
      );

      _initialized = true;
      print('LOG: Servicio de notificaciones inicializado');
    } catch (e) {
      print('LOG: Error al inicializar notificaciones: $e');
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
        print('LOG: Error al solicitar permisos: $e');
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
        'Retrasos de Vuelos',
        channelDescription: 'Notificaciones sobre retrasos en tus vuelos',
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

      print('LOG: Notificación enviada: $title - $body');
    } catch (e) {
      print('LOG: Error al mostrar notificación: $e');
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
    final String title = 'Retraso en vuelo $flightId';
    final String body = newTime != null
        ? 'Tu vuelo de $airline a $destination se ha retrasado. Nueva hora: $newTime'
        : 'Tu vuelo de $airline a $destination ha sufrido un retraso';

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
      'Recordatorios de Vuelos',
      channelDescription: 'Recordatorios programados para tus vuelos',
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
        'LOG: Notificación programada para ${scheduledDate.toIso8601String()}: $title');
  }

  /// Cancelar una notificación específica
  Future<void> cancelNotification(int id) async {
    await _flutterLocalNotificationsPlugin.cancel(id);
    print('LOG: Notificación con ID $id cancelada');
  }

  /// Cancelar todas las notificaciones
  Future<void> cancelAllNotifications() async {
    await _flutterLocalNotificationsPlugin.cancelAll();
    print('LOG: Todas las notificaciones canceladas');
  }
}
