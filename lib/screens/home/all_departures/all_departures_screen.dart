import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import 'package:intl/intl.dart';
import 'dart:async'; // Importar para usar Timer
import 'all_departures_ui.dart';
import '../../../services/cache/cache_service.dart';
import '../../../utils/airline_helper.dart'; // Importar la nueva clase utilitaria

/// Componente que maneja la lógica y los datos para la pantalla de todos los vuelos de salida
/// Obtiene los datos desde Firestore en la colección 'flights'
class AllDeparturesScreen extends StatefulWidget {
  const AllDeparturesScreen({super.key});

  @override
  State<AllDeparturesScreen> createState() => _AllDeparturesScreenState();
}

class _AllDeparturesScreenState extends State<AllDeparturesScreen> {
  // Conexión a la instancia de Firestore configurada en firebase_options.dart
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> _flights = [];
  bool _isLoading = true;
  String? _errorMessage;
  bool _usingCachedData = false;
  DateTime? _lastUpdated;
  Timer? _refreshTimer; // Timer para actualización periódica

  @override
  void initState() {
    super.initState();
    _loadData();
    // Configurar actualización automática cada 3 minutos (180000 ms)
    _refreshTimer = Timer.periodic(const Duration(minutes: 3), (timer) {
      print('LOG: Actualizando datos automáticamente cada 3 minutos');
      _loadFlights();
    });
  }

  /// Método principal para cargar datos. Primero intenta cargar desde caché,
  /// luego actualiza desde Firestore
  Future<void> _loadData() async {
    print('LOG: Iniciando carga de datos...');

    // Intentar cargar datos desde la caché
    await _loadFromCache();

    // Luego intentar cargar datos desde Firestore
    await _loadFlights();
  }

  /// Carga los datos desde la caché
  Future<void> _loadFromCache() async {
    print('LOG: Intentando cargar datos desde la caché...');

    try {
      if (!mounted) return;

      setState(() {
        _isLoading = true;
      });

      // Obtener la fecha de última actualización
      _lastUpdated = await CacheService.getLastUpdated();

      // Cargar vuelos de la caché
      final cachedFlights = await CacheService.getFlights();

      if (cachedFlights != null && cachedFlights.isNotEmpty) {
        if (!mounted) return;

        setState(() {
          _flights = cachedFlights;
          _isLoading = false;
          _usingCachedData = true;
          _errorMessage = null;
        });

        print(
            'LOG: Datos cargados desde caché (${cachedFlights.length} vuelos)');

        // Mostrar cuando se actualizaron por última vez
        if (_lastUpdated != null) {
          final timeDiff = DateTime.now().difference(_lastUpdated!);
          if (timeDiff.inMinutes < 1) {
            print('LOG: Datos actualizados hace menos de un minuto');
          } else if (timeDiff.inHours < 1) {
            print('LOG: Datos actualizados hace ${timeDiff.inMinutes} minutos');
          } else {
            print('LOG: Datos actualizados hace ${timeDiff.inHours} horas');
          }
        }
      } else {
        print('LOG: No hay datos en caché');
      }
    } catch (e) {
      print('ERROR: No se pudieron cargar los datos de la caché: $e');
    }
  }

  /// Carga los vuelos desde Firestore
  /// Se adapta a la estructura de la colección existente
  Future<void> _loadFlights() async {
    print('LOG: Cargando vuelos desde Firestore - usando colección existente');
    try {
      // Verificar si el widget sigue montado antes de llamar a setState
      if (!mounted) {
        print('LOG: Widget no montado, cancelando carga de vuelos');
        return;
      }

      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // Calcular la hora de corte (3 horas antes de la hora actual)
      final DateTime now = DateTime.now();
      final DateTime cutoffTime = now.subtract(const Duration(hours: 3));
      final String cutoffTimeString = cutoffTime.toIso8601String();

      print(
          'LOG: Filtrando vuelos a partir de: ${DateFormat('yyyy-MM-dd HH:mm').format(cutoffTime)}');

      // Realizar la consulta a Firestore usando la colección existente con filtro de tiempo
      final QuerySnapshot snapshot = await _firestore
          .collection('flights') // Nombre de tu colección existente
          .orderBy('schedule_time',
              descending: false) // Ordenar por hora de salida ascendente
          .where('schedule_time',
              isGreaterThanOrEqualTo:
                  cutoffTimeString) // Solo vuelos desde 3 horas antes
          .get();

      print(
          'LOG: Consulta a Firestore completada. Documentos encontrados: ${snapshot.docs.length}');

      // Verificar si el widget sigue montado después de la consulta asíncrona
      if (!mounted) {
        print(
            'LOG: Widget no montado después de consulta, cancelando actualización');
        return;
      }

      if (snapshot.docs.isEmpty) {
        print('LOG: No se encontraron documentos en la colección');
        setState(() {
          _errorMessage = 'No se encontraron vuelos disponibles';
          _isLoading = false;
        });
        return;
      }

      // Para depuración: imprimir la estructura del primer documento
      if (snapshot.docs.isNotEmpty) {
        final firstDoc = snapshot.docs.first.data() as Map<String, dynamic>;
        print(
            'LOG: Estructura del primer documento: ${firstDoc.keys.join(', ')}');
      }

      // Convertir los datos de Firestore a la estructura que espera nuestra UI
      final List<Map<String, dynamic>> loadedFlights = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;

        // Imprimir datos del documento para depuración
        print(
            'LOG: Procesando documento ${doc.id}: ${data.toString().substring(0, min(data.toString().length, 100))}...');

        // Manejar el color (convertir de string o valor numérico a Color)
        Color flightColor;
        if (data['color'] is int) {
          flightColor = Color(data['color']);
        } else {
          // Usar el helper para obtener el color de la aerolínea
          final airline = data['airline'] ?? '';
          flightColor = AirlineHelper.getAirlineColor(airline);
        }

        // Mapear los campos según la estructura existente
        return {
          'id': doc.id,
          'airline': data['airline'] ?? '',
          'flight_id': data['flight_id'] ?? '',
          'schedule_time': data['schedule_time'] ?? '',
          'status_time': data['status_time'] ?? '',
          'airport': data['airport'] ?? '',
          'gate': data['gate'] ?? '',
          'status_code': data['status_code'] ?? '',
          'color': flightColor,
        };
      }).toList();

      print('LOG: Se cargaron ${loadedFlights.length} vuelos desde Firestore');

      // Ordenar los vuelos por hora de salida (ascendente)
      loadedFlights.sort((a, b) {
        final timeA = a['schedule_time'] as String;
        final timeB = b['schedule_time'] as String;
        return timeA.compareTo(timeB); // Orden ascendente
      });

      print('LOG: Flights sorted by departure time (ascending)');

      // Verificar si el widget sigue montado antes de la actualización final
      if (!mounted) {
        print(
            'LOG: Widget no montado después de procesar datos, cancelando actualización final');
        return;
      }

      setState(() {
        _flights = loadedFlights;
        _isLoading = false;
        _usingCachedData = false;
        _lastUpdated = DateTime.now();
      });

      // Guardar en caché los nuevos datos
      await CacheService.saveFlights(_flights);
    } catch (e) {
      print('LOG: ERROR al cargar vuelos desde Firestore: $e');
      // Verificar si el widget sigue montado antes de actualizar el estado de error
      if (!mounted) {
        print(
            'LOG: Widget no montado después de error, cancelando actualización');
        return;
      }

      setState(() {
        _errorMessage = 'Error al cargar vuelos: $e';
        _isLoading = false;
      });
    }
  }

  // En AllDeparturesScreen, añadir el método para cargar con rango personalizado
  Future<void> _loadFlightsWithCustomRange(
      DateTime startDateTime, DateTime endDateTime) async {
    print('LOG: Cargando vuelos con rango personalizado desde Firestore');
    try {
      if (!mounted) return;

      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // Convertir fechas a formato ISO para la consulta
      final String startTimeString = startDateTime.toIso8601String();
      final String endTimeString = endDateTime.toIso8601String();

      print(
          'LOG: Filtrando vuelos desde: ${DateFormat('yyyy-MM-dd HH:mm').format(startDateTime)} '
          'hasta: ${DateFormat('yyyy-MM-dd HH:mm').format(endDateTime)}');

      // Realizar la consulta con el rango personalizado
      final QuerySnapshot snapshot = await _firestore
          .collection('flights')
          .orderBy('schedule_time', descending: false)
          .where('schedule_time', isGreaterThanOrEqualTo: startTimeString)
          .where('schedule_time', isLessThanOrEqualTo: endTimeString)
          .get();

      print(
          'LOG: Consulta a Firestore completada. Documentos encontrados: ${snapshot.docs.length}');

      if (!mounted) return;

      if (snapshot.docs.isEmpty) {
        print(
            'LOG: No se encontraron documentos en la colección para el rango personalizado');
        setState(() {
          _errorMessage = 'No se encontraron vuelos en el rango seleccionado';
          _isLoading = false;
        });
        return;
      }

      // Convertir los datos de Firestore a la estructura que espera nuestra UI
      final List<Map<String, dynamic>> loadedFlights = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;

        // Manejar el color (convertir de string o valor numérico a Color)
        Color flightColor;
        if (data['color'] is int) {
          flightColor = Color(data['color']);
        } else {
          // Usar el helper para obtener el color de la aerolínea
          final airline = data['airline'] ?? '';
          flightColor = AirlineHelper.getAirlineColor(airline);
        }

        // Mapear los campos según la estructura existente
        return {
          'id': doc.id,
          'airline': data['airline'] ?? '',
          'flight_id': data['flight_id'] ?? '',
          'schedule_time': data['schedule_time'] ?? '',
          'status_time': data['status_time'] ?? '',
          'airport': data['airport'] ?? '',
          'gate': data['gate'] ?? '',
          'status_code': data['status_code'] ?? '',
          'color': flightColor,
        };
      }).toList();

      print(
          'LOG: Se cargaron ${loadedFlights.length} vuelos históricos desde Firestore');

      // Ordenar los vuelos por hora de salida (ascendente)
      loadedFlights.sort((a, b) {
        final timeA = a['schedule_time'] as String;
        final timeB = b['schedule_time'] as String;
        return timeA.compareTo(timeB); // Orden ascendente
      });

      setState(() {
        _flights = loadedFlights;
        _isLoading = false;
        _usingCachedData = false;
        _lastUpdated = DateTime.now();
      });

      // Guardar en caché los nuevos datos
      await CacheService.saveFlights(_flights);
    } catch (e) {
      print('LOG: ERROR al cargar vuelos históricos desde Firestore: $e');
      if (!mounted) return;

      setState(() {
        _errorMessage = 'Error al cargar vuelos históricos: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _flights.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    // Si hay un error, mostrar mensaje de error
    if (_errorMessage != null && _flights.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadFlights,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    // Si estamos usando datos en caché, mostrar un indicador sutil
    if (_usingCachedData && !_isLoading) {
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
            color: Colors.blue.shade50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.access_time, color: Colors.blue, size: 16),
                const SizedBox(width: 8),
                Text(
                  _lastUpdated != null
                      ? 'Última actualización: ${_formatLastUpdated(_lastUpdated!)}'
                      : 'Usando datos almacenados',
                  style: TextStyle(color: Colors.blue.shade900, fontSize: 13),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 16),
                  onPressed: _loadFlights,
                  tooltip: 'Actualizar datos ahora',
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          Expanded(
            child: AllDeparturesUI(
              flights: _flights,
              onRefresh: _loadFlights,
              onCustomRangeLoad: _loadFlightsWithCustomRange,
              isRefreshing: _isLoading,
              lastUpdated: _lastUpdated,
            ),
          ),
        ],
      );
    }

    return AllDeparturesUI(
      flights: _flights,
      onRefresh: _loadFlights,
      onCustomRangeLoad: _loadFlightsWithCustomRange,
      isRefreshing: _isLoading,
      lastUpdated: _lastUpdated,
    );
  }

  // Formatea la fecha de última actualización en formato legible
  String _formatLastUpdated(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inSeconds < 60) {
      return 'hace unos segundos';
    } else if (difference.inMinutes < 60) {
      final minutes = difference.inMinutes;
      return 'hace $minutes ${minutes == 1 ? 'minuto' : 'minutos'}';
    } else if (difference.inHours < 24) {
      final hours = difference.inHours;
      return 'hace $hours ${hours == 1 ? 'hora' : 'horas'}';
    } else {
      final formatter = DateFormat('dd/MM HH:mm');
      return formatter.format(timestamp);
    }
  }

  @override
  void dispose() {
    // Cancelar el timer cuando se destruye el widget para evitar memory leaks
    _refreshTimer?.cancel();
    print('LOG: Disposing AllDeparturesScreen and cancelling refresh timer');
    super.dispose();
  }
}
