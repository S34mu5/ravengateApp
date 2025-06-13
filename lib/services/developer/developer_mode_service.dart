import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/logger.dart';

/// Servicio para gestionar el modo desarrollador
class DeveloperModeService {
  static const String _developerModeKey = 'developer_mode_enabled';
  static const String _defaultPin = '1913';

  /// Verifica si el modo desarrollador está activado
  static Future<bool> isDeveloperModeEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_developerModeKey) ?? false;
    } catch (e) {
      AppLogger.error('Error al verificar modo desarrollador', e);
      return false;
    }
  }

  /// Activa o desactiva el modo desarrollador
  static Future<bool> setDeveloperModeEnabled(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_developerModeKey, enabled);
      AppLogger.info(
          'Modo desarrollador ${enabled ? 'activado' : 'desactivado'}');
      return true;
    } catch (e) {
      AppLogger.error('Error al configurar modo desarrollador', e);
      return false;
    }
  }

  /// Verifica si el PIN es correcto
  static bool verifyPin(String pin) {
    return pin == _defaultPin;
  }

  /// Ejecuta una acción solo si el modo desarrollador está activado
  static Future<T?> runIfEnabled<T>(Future<T> Function() action) async {
    if (await isDeveloperModeEnabled()) {
      return await action();
    }
    AppLogger.warning('Acción no ejecutada, modo desarrollador desactivado');
    return null;
  }
}
