import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'notifications/notification_service.dart';
import 'cache/cache_service.dart';

/// Clase para detectar retrasos en vuelos comparando datos actualizados
class FlightDelayDetector {
  // Singleton
  static final FlightDelayDetector _instance = FlightDelayDetector._internal();
  factory FlightDelayDetector() => _instance;
  FlightDelayDetector._internal();

  // Referencia al servicio de notificaciones
  final NotificationService _notificationService = NotificationService();

  // Formato para comparar tiempos
  final DateFormat _timeFormat = DateFormat('HH:mm');

  /// Compara vuelos previos con los nuevos para detectar cambios en horarios
  Future<void> checkForDelays(
    List<Map<String, dynamic>> previousFlights,
    List<Map<String, dynamic>> currentFlights,
  ) async {
    print('LOG: Verifying delays in ${currentFlights.length} flights');

    // Inicializar el servicio de notificaciones
    await _notificationService.init();

    // Verificar si las notificaciones de retrasos están habilitadas
    final bool delayNotificationsEnabled =
        await CacheService.getDelayNotificationsPreference();

    // Verificar si las notificaciones de despegue están habilitadas
    final bool departureNotificationsEnabled =
        await CacheService.getDepartureNotificationsPreference();

    // Si ambas notificaciones están desactivadas, salir
    if (!delayNotificationsEnabled && !departureNotificationsEnabled) {
      print('LOG: Flight notifications are disabled by user');
      return;
    }

    // Mapear los vuelos anteriores por ID para búsqueda más rápida
    final Map<String, Map<String, dynamic>> previousFlightsMap = {
      for (var flight in previousFlights) flight['id'].toString(): flight
    };

    // Verificar cada vuelo actual contra su versión anterior
    for (final currentFlight in currentFlights) {
      final String flightId = currentFlight['id'].toString();
      final String flightCode = currentFlight['flight_id'] ?? '';

      // Verificar si tenemos este vuelo en la lista anterior
      if (previousFlightsMap.containsKey(flightId)) {
        final Map<String, dynamic> previousFlight =
            previousFlightsMap[flightId]!;

        // Si las notificaciones de retrasos están habilitadas, verificar retrasos
        if (delayNotificationsEnabled) {
          // Detectar cambios de horario
          final bool hasDelayChange = _detectDelayChange(
            previousFlight: previousFlight,
            currentFlight: currentFlight,
          );

          // Si hay un retraso, enviar notificación
          if (hasDelayChange) {
            final String airline = currentFlight['airline'] ?? '';
            final String destination = currentFlight['airport'] ?? '';
            final String newTime =
                _extractTimeFromSchedule(currentFlight['status_time'] ?? '');

            // Notificar al usuario sobre el retraso
            await _notificationService.notifyFlightDelay(
              flightId: flightCode,
              airline: airline,
              destination: destination,
              newTime: newTime,
            );

            print(
                'LOG: Delay detected in flight $flightCode - New time: $newTime');
          }
        }

        // Si las notificaciones de despegue están habilitadas, verificar despegues
        if (departureNotificationsEnabled) {
          // Detectar si el vuelo ha despegado
          final bool hasDeparted = _detectDeparture(
            previousFlight: previousFlight,
            currentFlight: currentFlight,
          );

          // Si el vuelo ha despegado, enviar notificación
          if (hasDeparted) {
            final String airline = currentFlight['airline'] ?? '';
            final String destination = currentFlight['airport'] ?? '';
            final String departureTime =
                _extractTimeFromSchedule(currentFlight['status_time'] ?? '');

            // Notificar al usuario sobre el despegue usando el método específico
            await _notificationService.notifyFlightDeparture(
              flightId: flightCode,
              airline: airline,
              destination: destination,
              departureTime: departureTime,
            );

            print(
                'LOG: Departure detected for flight $flightCode at time: $departureTime');
          }
        }
      }
    }
  }

  /// Detecta si un vuelo ha despegado (cambio de status_code a 'D')
  bool _detectDeparture({
    required Map<String, dynamic> previousFlight,
    required Map<String, dynamic> currentFlight,
  }) {
    try {
      // Obtener el estado actual y anterior
      final String currentStatus =
          currentFlight['status_code']?.toString() ?? '';
      final String previousStatus =
          previousFlight['status_code']?.toString() ?? '';

      // El vuelo ha despegado si el status_code ha cambiado a 'D' (Departed)
      return previousStatus != 'D' && currentStatus == 'D';
    } catch (e) {
      print('LOG: Error detecting departure: $e');
      return false;
    }
  }

  /// Detecta si hay un cambio de horario que implique un retraso
  bool _detectDelayChange({
    required Map<String, dynamic> previousFlight,
    required Map<String, dynamic> currentFlight,
  }) {
    try {
      // Comprobar si el vuelo ya ha despegado o está cancelado
      final String currentStatus =
          currentFlight['status_code']?.toString() ?? '';

      // Si el vuelo ya ha despegado (D = Departed) o está cancelado (C = Cancelled), no notificar retrasos
      if (currentStatus == 'D' || currentStatus == 'C') {
        return false;
      }

      // Obtener el campo booleano 'delayed' proporcionado por Firebase
      final bool wasDelayedBefore = previousFlight['delayed'] == true;
      final bool isDelayedNow = currentFlight['delayed'] == true;

      // Si delayed ha cambiado de false a true, notificar
      if (!wasDelayedBefore && isDelayedNow) {
        print(
            'LOG: Delay detected based on delayed flag change for flight ${currentFlight['flight_id']}');
        return true;
      }

      // Obtener horario programado original (schedule_time)
      final String scheduleTimeStr =
          currentFlight['schedule_time']?.toString() ?? '';

      // Obtener horario de estado actual (status_time)
      final String statusTimeStr =
          currentFlight['status_time']?.toString() ?? '';

      // Obtener horario de estado anterior para verificar cambios
      final String previousStatusTimeStr =
          previousFlight['status_time']?.toString() ?? '';

      // Si no hay información de horarios, no podemos detectar retrasos
      if (scheduleTimeStr.isEmpty) {
        return false;
      }

      // Si hay un status_time (horario actualizado):
      if (statusTimeStr.isNotEmpty) {
        // Extraer solo la hora para comparar
        final String scheduleTimeFormatted =
            _extractTimeFromSchedule(scheduleTimeStr);
        final String statusTimeFormatted =
            _extractTimeFromSchedule(statusTimeStr);

        // El vuelo está retrasado si status_time es posterior a schedule_time
        if (_isTimeAfter(statusTimeFormatted, scheduleTimeFormatted)) {
          // Verificar si es un nuevo retraso (comparando con el status_time anterior)
          // Solo notificar si el status_time ha cambiado
          return previousStatusTimeStr != statusTimeStr;
        }
      }

      return false;
    } catch (e) {
      print('LOG: Error detecting delay: $e');
      return false;
    }
  }

  /// Extrae la hora de un formato de horario (común en ambas UIs)
  String _extractTimeFromSchedule(String scheduleTime) {
    try {
      // Si es formato ISO completo
      if (scheduleTime.contains('T')) {
        final dateTime = DateTime.parse(scheduleTime);
        return _timeFormat.format(dateTime);
      }

      // Si es formato simple HH:MM
      final parts = scheduleTime.split(':');
      if (parts.length >= 2) {
        return '${parts[0]}:${parts[1]}';
      }

      return scheduleTime;
    } catch (e) {
      print('LOG: Error extracting time: $e');
      return scheduleTime;
    }
  }

  /// Verifica si una hora es posterior a otra
  bool _isTimeAfter(String time1, String time2) {
    try {
      // Convertir al formato actual de tiempo
      final parts1 = time1.split(':');
      final parts2 = time2.split(':');

      if (parts1.length >= 2 && parts2.length >= 2) {
        final hour1 = int.parse(parts1[0]);
        final minute1 = int.parse(parts1[1]);
        final hour2 = int.parse(parts2[0]);
        final minute2 = int.parse(parts2[1]);

        // Comparar horas y minutos
        if (hour1 > hour2) {
          return true;
        } else if (hour1 == hour2) {
          return minute1 > minute2;
        }
      }
      return false;
    } catch (e) {
      print('LOG: Error comparando tiempos: $e');
      return false;
    }
  }
}
