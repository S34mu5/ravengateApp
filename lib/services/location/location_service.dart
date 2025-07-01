import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/logger.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';

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
  /// Obtiene la mejor posición disponible con la máxima precisión.
  ///
  /// * [desiredAccuracyMeters] precisión objetivo en metros (por defecto 10 m).
  /// * [samplingDuration] tiempo máximo para muestrear (por defecto 8 s).
  /// * [forceRequest] vuelve a solicitar permisos aunque ya estuvieran concedidos.
  static Future<Position?> getCurrentPosition({
    bool forceRequest = false,
    double desiredAccuracyMeters = 10,
    Duration samplingDuration = const Duration(seconds: 8),
  }) async {
    try {
      // 1) ¿Están activos los servicios de ubicación?
      if (!await Geolocator.isLocationServiceEnabled()) {
        AppLogger.warning('GPS: Location service disabled');
        return null;
      }

      // 2) Comprobar / solicitar permisos
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied || forceRequest) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          AppLogger.warning('GPS: Permission denied');
          return null;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        AppLogger.warning('GPS: Permission denied forever');
        return null;
      }

      // 3) Iniciar stream con máxima precisión
      final locationSettings = LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
        // Garantizamos alta frecuencia en Android; otros OS ignorarán.
        // Para AndroidSettings: intervalDuration sólo disponible en subclase,
        // pero mantenerlo simple con genérico.
      );

      final completer = Completer<Position?>();
      Position? bestPosition;
      late final StreamSubscription<Position> sub;

      void finish() {
        sub.cancel();
        completer.complete(bestPosition);
      }

      // Timer para cancelar tras la duración de muestreo
      final timeout = Timer(samplingDuration, () {
        final bestAcc = bestPosition?.accuracy?.toStringAsFixed(1) ?? 'N/A';
        AppLogger.info(
            'GPS: Sampling timeout reached. Best accuracy: $bestAcc m');
        finish();
      });

      sub = Geolocator.getPositionStream(locationSettings: locationSettings)
          .listen((pos) {
        AppLogger.debug(
            'GPS: sample → lat=${pos.latitude}, lon=${pos.longitude}, accuracy=${pos.accuracy}');

        // Mantener la mejor precisión.
        if (bestPosition == null || (pos.accuracy < bestPosition!.accuracy)) {
          bestPosition = pos;
        }

        // ¿Alcanzamos la precisión requerida?
        if (pos.accuracy <= desiredAccuracyMeters) {
          AppLogger.info('GPS: Desired accuracy reached (${pos.accuracy} m)');
          timeout.cancel();
          finish();
        }
      }, onError: (e) {
        AppLogger.error('GPS: Stream error', e);
        timeout.cancel();
        if (!completer.isCompleted) completer.complete(null);
      });

      return completer.future;
    } catch (e) {
      AppLogger.error('GPS: Exception while acquiring position', e);
      return null;
    }
  }
}
