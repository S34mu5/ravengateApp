import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/logger.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Servicio para obtener y gestionar la ubicación actual del usuario
class LocationService {
  static const String _locationKey = 'selected_location';
  static const String _trolleyHistoryCacheKey = 'trolley_history_cache_';
  static const String _trolleyHistoryTimestampKey =
      'trolley_history_timestamp_';
  static const Duration _cacheExpiration =
      Duration(minutes: 5); // Cache válido por 5 minutos

  // Cache en memoria para evitar múltiples consultas a SharedPreferences
  static final Map<String, List<Map<String, dynamic>>> _memoryCache = {};
  static final Map<String, DateTime> _memoryCacheTimestamps = {};

  /// Convierte datos de Firestore a formato serializable para JSON
  static Map<String, dynamic> _convertFirestoreData(Map<String, dynamic> data) {
    final Map<String, dynamic> converted = {};

    for (final entry in data.entries) {
      final key = entry.key;
      final value = entry.value;

      if (value is Timestamp) {
        // Convertir Timestamp a milisegundos
        converted[key] = value.millisecondsSinceEpoch;
      } else if (value is Map<String, dynamic>) {
        // Recursivamente convertir mapas anidados
        converted[key] = _convertFirestoreData(value);
      } else if (value is List) {
        // Convertir listas que puedan contener Timestamps
        converted[key] = value.map((item) {
          if (item is Timestamp) {
            return item.millisecondsSinceEpoch;
          } else if (item is Map<String, dynamic>) {
            return _convertFirestoreData(item);
          }
          return item;
        }).toList();
      } else {
        // Mantener otros tipos como están
        converted[key] = value;
      }
    }

    return converted;
  }

  /// Convierte datos del cache de vuelta a formato de Firestore
  static Map<String, dynamic> _convertFromCacheData(Map<String, dynamic> data) {
    final Map<String, dynamic> converted = {};

    for (final entry in data.entries) {
      final key = entry.key;
      final value = entry.value;

      // Si la clave es 'timestamp' y el valor es un entero, convertir de vuelta a Timestamp
      if (key == 'timestamp' && value is int) {
        converted[key] = Timestamp.fromMillisecondsSinceEpoch(value);
      } else if (key == 'deleted_at' && value is int) {
        converted[key] = Timestamp.fromMillisecondsSinceEpoch(value);
      } else if (value is Map<String, dynamic>) {
        // Recursivamente convertir mapas anidados
        converted[key] = _convertFromCacheData(value);
      } else if (value is List) {
        // Convertir listas
        converted[key] = value.map((item) {
          if (item is Map<String, dynamic>) {
            return _convertFromCacheData(item);
          }
          return item;
        }).toList();
      } else {
        // Mantener otros tipos como están
        converted[key] = value;
      }
    }

    return converted;
  }

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
        final bestAcc = bestPosition?.accuracy.toStringAsFixed(1) ?? 'N/A';
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

  // —— Cache de historial de trolleys ——

  /// Obtiene el historial de trolleys del cache si está disponible y válido
  static Future<List<Map<String, dynamic>>?> getCachedTrolleyHistory(
      String documentId) async {
    try {
      // Primero verificar cache en memoria
      final memoryCacheKey = documentId;
      if (_memoryCache.containsKey(memoryCacheKey) &&
          _memoryCacheTimestamps.containsKey(memoryCacheKey)) {
        final timestamp = _memoryCacheTimestamps[memoryCacheKey]!;
        if (DateTime.now().difference(timestamp) < _cacheExpiration) {
          AppLogger.debug('🎯 Cache en memoria válido para $documentId', null,
              'LocationService');
          return _memoryCache[memoryCacheKey];
        } else {
          AppLogger.debug('⏰ Cache en memoria expirado para $documentId', null,
              'LocationService');
          _memoryCache.remove(memoryCacheKey);
          _memoryCacheTimestamps.remove(memoryCacheKey);
        }
      }

      // Verificar cache en SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final timestampKey = '$_trolleyHistoryTimestampKey$documentId';
      final cacheKey = '$_trolleyHistoryCacheKey$documentId';

      final timestampMillis = prefs.getInt(timestampKey);
      if (timestampMillis == null) {
        AppLogger.debug('📭 No hay timestamp de cache para $documentId', null,
            'LocationService');
        return null;
      }

      final cacheTimestamp =
          DateTime.fromMillisecondsSinceEpoch(timestampMillis);
      final age = DateTime.now().difference(cacheTimestamp);

      if (age > _cacheExpiration) {
        AppLogger.debug(
            '⏰ Cache expirado para $documentId (edad: ${age.inMinutes}min)',
            null,
            'LocationService');
        // Limpiar cache expirado
        await prefs.remove(timestampKey);
        await prefs.remove(cacheKey);
        return null;
      }

      final cachedJson = prefs.getString(cacheKey);
      if (cachedJson == null) {
        AppLogger.debug('📭 No hay datos de cache para $documentId', null,
            'LocationService');
        return null;
      }

      final List<dynamic> decoded = json.decode(cachedJson);
      final history = decoded
          .map((item) => _convertFromCacheData(Map<String, dynamic>.from(item)))
          .toList();

      // Guardar en cache de memoria para próximas consultas
      _memoryCache[memoryCacheKey] = history;
      _memoryCacheTimestamps[memoryCacheKey] = cacheTimestamp;

      AppLogger.debug(
          '✅ Cache válido encontrado para $documentId (${history.length} items)',
          null,
          'LocationService');
      return history;
    } catch (e) {
      AppLogger.error('💥 Error leyendo cache de trolleys para $documentId: $e',
          e, 'LocationService');
      return null;
    }
  }

  /// Guarda el historial de trolleys en cache
  static Future<void> cacheTrolleyHistory(
      String documentId, List<Map<String, dynamic>> history) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestampKey = '$_trolleyHistoryTimestampKey$documentId';
      final cacheKey = '$_trolleyHistoryCacheKey$documentId';
      final now = DateTime.now();

      // Convertir datos de Firestore a formato serializable
      final serializableHistory =
          history.map((item) => _convertFirestoreData(item)).toList();

      // Guardar en SharedPreferences
      await prefs.setInt(timestampKey, now.millisecondsSinceEpoch);
      await prefs.setString(cacheKey, json.encode(serializableHistory));

      // Guardar en cache de memoria
      _memoryCache[documentId] = history;
      _memoryCacheTimestamps[documentId] = now;

      AppLogger.debug(
          '💾 Cache guardado para $documentId (${history.length} items)',
          null,
          'LocationService');
    } catch (e) {
      AppLogger.error(
          '💥 Error guardando cache de trolleys para $documentId: $e',
          e,
          'LocationService');
    }
  }

  /// Invalida el cache para un documento específico
  static Future<void> invalidateTrolleyCache(String documentId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestampKey = '$_trolleyHistoryTimestampKey$documentId';
      final cacheKey = '$_trolleyHistoryCacheKey$documentId';

      // Limpiar SharedPreferences
      await prefs.remove(timestampKey);
      await prefs.remove(cacheKey);

      // Limpiar cache de memoria
      _memoryCache.remove(documentId);
      _memoryCacheTimestamps.remove(documentId);

      AppLogger.debug(
          '🗑️ Cache invalidado para $documentId', null, 'LocationService');
    } catch (e) {
      AppLogger.error('💥 Error invalidando cache para $documentId: $e', e,
          'LocationService');
    }
  }

  /// Limpia todo el cache de trolleys (útil para liberar memoria)
  static Future<void> clearAllTrolleyCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();

      // Encontrar y eliminar todas las claves de cache de trolleys
      for (final key in keys) {
        if (key.startsWith(_trolleyHistoryCacheKey) ||
            key.startsWith(_trolleyHistoryTimestampKey)) {
          await prefs.remove(key);
        }
      }

      // Limpiar cache de memoria
      _memoryCache.clear();
      _memoryCacheTimestamps.clear();

      AppLogger.debug('🧹 Todo el cache de trolleys ha sido limpiado', null,
          'LocationService');
    } catch (e) {
      AppLogger.error(
          '💥 Error limpiando cache de trolleys: $e', e, 'LocationService');
    }
  }
}
