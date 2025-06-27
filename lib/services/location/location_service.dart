import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/logger.dart';
import 'package:geolocator/geolocator.dart';

/// Servicio para obtener y gestionar la ubicación actual del usuario
class LocationService {
  static const String _locationKey = 'selected_location';

  /// Obtiene la ubicación seleccionada por el usuario
  /// Devuelve 'Bins' por defecto si no hay ubicación guardada
  static Future<String> getSelectedLocation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_locationKey) ?? 'Bins';
    } catch (e) {
      AppLogger.error('No se pudo obtener la ubicación', e);
      return 'Bins';
    }
  }

  /// Verifica si la ubicación actual es 'Oversize'
  static Future<bool> isOversizeLocation() async {
    final location = await getSelectedLocation();
    return location == 'Oversize';
  }

  /// Verifica si la ubicación actual es 'Bins'
  static Future<bool> isBinsLocation() async {
    final location = await getSelectedLocation();
    return location == 'Bins';
  }

  // —— Ubicación GPS ——
  static Future<Position?> getCurrentPosition(
      {bool forceRequest = false}) async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied || forceRequest) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          AppLogger.warning('Permiso de ubicación denegado');
          return null;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        AppLogger.warning('Permiso de ubicación denegado permanentemente');
        return null;
      }

      return await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
    } catch (e) {
      AppLogger.error('Error obteniendo posición GPS', e);
      return null;
    }
  }
}
