import 'package:flutter/foundation.dart';

/// Niveles de logging disponibles
enum LogLevel {
  debug(0),
  info(1),
  warning(2),
  error(3),
  none(4); // Para desactivar completamente los logs

  const LogLevel(this.priority);
  final int priority;
}

/// Sistema de logging centralizado para la aplicación
class AppLogger {
  static LogLevel _currentLevel = kDebugMode ? LogLevel.debug : LogLevel.error;

  /// Configura el nivel mínimo de logging
  static void setLevel(LogLevel level) {
    _currentLevel = level;
  }

  /// Obtiene el nivel actual de logging
  static LogLevel get currentLevel => _currentLevel;

  /// Log de nivel DEBUG - solo información de desarrollo
  static void debug(String message, [Object? error, String? tag]) {
    _log(LogLevel.debug, message, error, tag);
  }

  /// Log de nivel INFO - información general del flujo de la app
  static void info(String message, [Object? error, String? tag]) {
    _log(LogLevel.info, message, error, tag);
  }

  /// Log de nivel WARNING - situaciones que requieren atención
  static void warning(String message, [Object? error, String? tag]) {
    _log(LogLevel.warning, message, error, tag);
  }

  /// Log de nivel ERROR - errores que afectan la funcionalidad
  static void error(String message, [Object? error, String? tag]) {
    _log(LogLevel.error, message, error, tag);
  }

  /// Método interno para procesar los logs
  static void _log(LogLevel level, String message,
      [Object? error, String? tag]) {
    // Solo mostrar logs si el nivel es mayor o igual al configurado
    if (level.priority < _currentLevel.priority) return;

    final timestamp = DateTime.now().toIso8601String().substring(11, 19);
    final levelStr = level.name.toUpperCase().padRight(7);
    final tagStr = tag != null ? '[$tag] ' : '';

    String fullMessage = '[$timestamp] $levelStr $tagStr$message';

    if (error != null) {
      fullMessage += '\nError: $error';
    }

    // En modo debug usar debugPrint para mejor integración con Flutter Inspector
    if (kDebugMode) {
      debugPrint(fullMessage);
    } else {
      print(fullMessage);
    }
  }

  /// Configuraciones predefinidas para diferentes entornos

  /// Configuración para desarrollo - muestra todos los logs
  static void enableDevelopmentMode() {
    setLevel(LogLevel.debug);
  }

  /// Configuración para producción - solo errores críticos
  static void enableProductionMode() {
    setLevel(LogLevel.error);
  }

  /// Configuración para testing - solo warnings y errores
  static void enableTestingMode() {
    setLevel(LogLevel.warning);
  }

  /// Desactivar completamente los logs
  static void disableLogs() {
    setLevel(LogLevel.none);
  }
}
