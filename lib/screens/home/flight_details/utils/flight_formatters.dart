import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../utils/logger.dart';

/// Clase de utilidades para formatear datos de vuelos
class FlightFormatters {
  /// Formatea una hora en formato String
  static String formatTime(String timeString) {
    try {
      if (timeString.isEmpty) return '-';

      // Si ya está en formato HH:MM, devolverlo
      if (timeString.contains(':') && !timeString.contains('T')) {
        return timeString;
      }

      // Si es un timestamp ISO, convertirlo a hora local
      final DateTime dateTime = DateTime.parse(timeString);
      return DateFormat('HH:mm').format(dateTime.toLocal());
    } catch (e) {
      AppLogger.error('Error formatting time', e);
      return timeString; // Devolver el string original si hay error
    }
  }

  /// Formatea un DateTime a un formato legible
  static String formatDateTime(DateTime dateTime) {
    try {
      return DateFormat('MMM d, yyyy - HH:mm').format(dateTime.toLocal());
    } catch (e) {
      AppLogger.error('Error formatting datetime', e);
      return dateTime.toString(); // Devolver el string por defecto si hay error
    }
  }

  /// Formatea solo la fecha en formato corto (ej: Apr 30)
  static String formatShortDate(DateTime dateTime) {
    try {
      return DateFormat('MMM d').format(dateTime.toLocal());
    } catch (e) {
      AppLogger.error('Error formatting short date', e);
      return dateTime.toString();
    }
  }

  /// Comprueba si una hora es posterior a otra
  static bool isLaterTime(String time1, String time2) {
    try {
      final List<String> parts1 = time1.split(':');
      final List<String> parts2 = time2.split(':');

      if (parts1.length != 2 || parts2.length != 2) {
        return false;
      }

      final int hour1 = int.parse(parts1[0]);
      final int minute1 = int.parse(parts1[1]);
      final int hour2 = int.parse(parts2[0]);
      final int minute2 = int.parse(parts2[1]);

      return hour1 > hour2 || (hour1 == hour2 && minute1 > minute2);
    } catch (e) {
      AppLogger.error('Error comparing times', e);
      return false;
    }
  }

  /// Formatea un objeto JSON para mostrarlo
  static String formatJsonString(Map<String, dynamic> json) {
    const indent = '  ';
    final buffer = StringBuffer();
    buffer.writeln('{');

    json.forEach((key, value) {
      String valueStr;
      if (value is Map) {
        valueStr = '{ ... }';
      } else if (value is List) {
        valueStr = '[ ... ]';
      } else if (value is String) {
        valueStr = '"$value"';
      } else {
        valueStr = value.toString();
      }
      buffer.writeln('$indent$key: $valueStr,');
    });

    buffer.write('}');
    return buffer.toString();
  }

  /// Formatea una lista de objetos JSON para mostrarla
  static String formatJsonList(List<Map<String, dynamic>> jsonList) {
    const indent = '  ';
    final buffer = StringBuffer();
    buffer.writeln('[');

    for (var i = 0; i < jsonList.length; i++) {
      final Map<String, dynamic> json = jsonList[i];
      buffer.writeln('$indent{');

      json.forEach((key, value) {
        String valueStr;
        if (value is Map) {
          valueStr = '{ ... }';
        } else if (value is List) {
          valueStr = '[ ... ]';
        } else if (value is String) {
          valueStr = '"$value"';
        } else if (value is Timestamp) {
          valueStr = '"${value.toDate()}"';
        } else {
          valueStr = value.toString();
        }
        buffer.writeln('$indent$indent$key: $valueStr,');
      });

      if (i < jsonList.length - 1) {
        buffer.writeln('$indent},');
      } else {
        buffer.writeln('$indent}');
      }
    }

    buffer.write(']');
    return buffer.toString();
  }
}
