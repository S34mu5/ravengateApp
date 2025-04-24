import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'notifications/notification_service.dart';

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
    print('LOG: Verificando retrasos en ${currentFlights.length} vuelos');

    // Inicializar el servicio de notificaciones
    await _notificationService.init();

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
              _extractTimeFromSchedule(currentFlight['schedule_time'] ?? '');

          // Notificar al usuario sobre el retraso
          await _notificationService.notifyFlightDelay(
            flightId: flightCode,
            airline: airline,
            destination: destination,
            newTime: newTime,
          );

          print(
              'LOG: Retraso detectado en vuelo $flightCode - Nueva hora: $newTime');
        }
      }
    }
  }

  /// Detecta si hay un cambio de horario que implique un retraso
  bool _detectDelayChange({
    required Map<String, dynamic> previousFlight,
    required Map<String, dynamic> currentFlight,
  }) {
    try {
      // Obtener horarios programados
      final String previousScheduleStr =
          previousFlight['schedule_time']?.toString() ?? '';
      final String currentScheduleStr =
          currentFlight['schedule_time']?.toString() ?? '';

      // Si no hay información de horario, no podemos detectar retrasos
      if (previousScheduleStr.isEmpty || currentScheduleStr.isEmpty) {
        return false;
      }

      // Detectar si el vuelo ha sido retrasado
      if (previousScheduleStr != currentScheduleStr) {
        // Extraer solo la hora para comparar
        final String previousTimeStr =
            _extractTimeFromSchedule(previousScheduleStr);
        final String currentTimeStr =
            _extractTimeFromSchedule(currentScheduleStr);

        // Si la nueva hora es posterior a la anterior, es un retraso
        if (_isTimeAfter(currentTimeStr, previousTimeStr)) {
          return true;
        }

        // También verificar cambios de estado que indiquen retraso
        final String previousStatus =
            previousFlight['status_code']?.toString() ?? '';
        final String currentStatus =
            currentFlight['status_code']?.toString() ?? '';

        if (previousStatus != currentStatus &&
            (currentStatus.toLowerCase().contains('delay') ||
                currentStatus.toLowerCase().contains('retraso'))) {
          return true;
        }
      }

      return false;
    } catch (e) {
      print('LOG: Error al detectar retraso: $e');
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
