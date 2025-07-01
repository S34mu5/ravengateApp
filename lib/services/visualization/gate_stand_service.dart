import '../cache/cache_service.dart';
import '../../utils/gate_to_stand_map.dart';

/// Servicio para manejar la conversión entre gates y stands
class GateStandService {
  /// Obtiene el display apropiado basado en la preferencia del usuario
  /// Si showStand es true y existe el mapeo, retorna el stand
  /// Si no, retorna la gate original
  static Future<String> getDisplayValue(String gate) async {
    final showStand = await CacheService.getShowStandPreference();

    if (showStand && gateToStand.containsKey(gate)) {
      return 'Stand ${gateToStand[gate]}';
    }

    return gate;
  }

  /// Obtiene el valor del stand para una gate específica
  /// Retorna null si no existe mapeo
  static int? getStandForGate(String gate) {
    return gateToStand[gate];
  }

  /// Verifica si una gate tiene mapeo a stand
  static bool hasStandMapping(String gate) {
    return gateToStand.containsKey(gate);
  }

  /// Obtiene la preferencia actual del usuario
  static Future<bool> getShowStandPreference() async {
    return await CacheService.getShowStandPreference();
  }

  /// Guarda la preferencia del usuario
  static Future<void> setShowStandPreference(bool showStand) async {
    await CacheService.saveShowStandPreference(showStand);
  }
}
