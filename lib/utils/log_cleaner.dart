/// Utilidad para limpiar y optimizar el logging del proyecto
/// Este archivo contiene patrones y reglas para mejorar el sistema de logging

class LogCleaner {
  /// Patrones de logs que deben ser eliminados o reducidos
  static const List<String> verbosePatterns = [
    'LOG: Vuelos cargados desde caché',
    'LOG: Forzando actualización, ignorando caché',
    'LOG: No hay datos en caché',
    'LOG: Obteniendo datos completos para',
    'LOG: Procesados',
    'LOG: Iniciando proceso de',
    'LOG: Usuario actual:',
    'LOG: Ruta de Firestore:',
    'LOG: Intentando obtener',
    'LOG: Documento encontrado',
    'LOG: Moviendo documento',
    'LOG: Se encontraron',
  ];

  /// Patrones de logs que son importantes y deben mantenerse como ERROR
  static const List<String> errorPatterns = [
    'Error saving flight',
    'Error getting user flights',
    'Error archiving flight',
    'Error al eliminar',
    'Error al restaurar',
    'Error loading',
    'Error cargando',
    'Error registrando',
    'Error eliminando',
  ];

  /// Patrones de logs que deben convertirse a WARNING
  static const List<String> warningPatterns = [
    'not found',
    'No se encontró',
    'failed, using',
    'ALERTA:',
  ];

  /// Patrones de logs que pueden convertirse a DEBUG
  static const List<String> debugPatterns = [
    'Documento',
    'Total de',
    'IDs de documentos',
    'Found',
    'Usando flight_ref',
    'Converted',
  ];

  /// Generar recomendaciones para un mensaje de log
  static LogRecommendation analyzeLogMessage(String message) {
    // Eliminar patrones verbosos
    for (final pattern in verbosePatterns) {
      if (message.contains(pattern)) {
        return LogRecommendation(
          action: LogAction.remove,
          reason: 'Log demasiado verboso para uso normal',
          originalMessage: message,
        );
      }
    }

    // Clasificar por nivel de importancia
    for (final pattern in errorPatterns) {
      if (message.contains(pattern)) {
        return LogRecommendation(
          action: LogAction.convertToError,
          reason: 'Información crítica de error',
          originalMessage: message,
          suggestedReplacement: _convertToAppLogger(message, 'error'),
        );
      }
    }

    for (final pattern in warningPatterns) {
      if (message.contains(pattern)) {
        return LogRecommendation(
          action: LogAction.convertToWarning,
          reason: 'Situación que requiere atención',
          originalMessage: message,
          suggestedReplacement: _convertToAppLogger(message, 'warning'),
        );
      }
    }

    for (final pattern in debugPatterns) {
      if (message.contains(pattern)) {
        return LogRecommendation(
          action: LogAction.convertToDebug,
          reason: 'Información de depuración',
          originalMessage: message,
          suggestedReplacement: _convertToAppLogger(message, 'debug'),
        );
      }
    }

    // Por defecto, convertir a INFO si no se eliminó
    return LogRecommendation(
      action: LogAction.convertToInfo,
      reason: 'Información general',
      originalMessage: message,
      suggestedReplacement: _convertToAppLogger(message, 'info'),
    );
  }

  /// Convertir un print/debugPrint a AppLogger
  static String _convertToAppLogger(String originalMessage, String level) {
    // Limpiar el mensaje
    String cleanMessage = originalMessage
        .replaceAll('print(\'LOG: ', '')
        .replaceAll('print(\'', '')
        .replaceAll('\');', '')
        .replaceAll('debugPrint(\'', '')
        .replaceAll('LOG: ', '');

    return 'AppLogger.$level(\'$cleanMessage\');';
  }
}

enum LogAction {
  remove,
  convertToError,
  convertToWarning,
  convertToInfo,
  convertToDebug,
}

class LogRecommendation {
  final LogAction action;
  final String reason;
  final String originalMessage;
  final String? suggestedReplacement;

  LogRecommendation({
    required this.action,
    required this.reason,
    required this.originalMessage,
    this.suggestedReplacement,
  });

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.writeln('Acción: ${action.name}');
    buffer.writeln('Razón: $reason');
    buffer.writeln('Original: $originalMessage');
    if (suggestedReplacement != null) {
      buffer.writeln('Sugerencia: $suggestedReplacement');
    }
    return buffer.toString();
  }
}
