import 'package:shared_preferences/shared_preferences.dart';

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
      print('ERROR: No se pudo obtener la ubicación: $e');
      return 'Bins'; // Valor por defecto en caso de error
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
}
