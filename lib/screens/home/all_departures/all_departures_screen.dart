import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import 'package:intl/intl.dart';
import 'all_departures_ui.dart';
import '../../../services/cache/cache_service.dart';

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
  bool _usingFallbackData = false;
  bool _usingCachedData = false;
  DateTime? _lastUpdated;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  /// Método principal para cargar datos. Primero intenta cargar desde caché,
  /// luego actualiza desde Firestore
  Future<void> _loadData() async {
    print('LOG: Iniciando carga de datos...');

    // Intentar cargar datos desde la caché
    await _loadFromCache();

    // Luego intentar cargar datos desde Firestore (excepto si estamos usando datos de respaldo)
    if (!_usingFallbackData) {
      await _loadFlights();
    }
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
        _usingFallbackData = false;
      });

      // Realizar la consulta a Firestore usando la colección existente
      final QuerySnapshot snapshot = await _firestore
          .collection('flights') // Nombre de tu colección existente
          .orderBy('schedule_time',
              descending: true) // Ordenar por hora de salida descendente
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
          _usingFallbackData = true;
          _flights = _getFallbackFlights();
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
          // Color por defecto según aerolínea
          final airline = data['airline'] ?? '';
          switch (airline) {
            case 'SK':
              flightColor = const Color.fromARGB(255, 33, 150, 243); // Azul
              break;
            case 'DY':
              flightColor = const Color.fromARGB(255, 255, 68, 68); // Rojo
              break;
            case 'DX':
              flightColor = const Color.fromARGB(255, 76, 175, 80); // Verde
              break;
            case 'AY':
              flightColor = Colors.white; // Blanco
              break;
            default:
              flightColor = Colors.grey; // Gris por defecto
          }
        }

        // Mapear los campos según la estructura existente
        return {
          'id': doc.id,
          'airline': data['airline'] ?? '',
          'flight_id': data['flight_id'] ?? '',
          'schedule_time': data['schedule_time'] ?? '',
          'airport': data['airport'] ?? '',
          'gate': data['gate'] ?? '',
          'color': flightColor,
        };
      }).toList();

      print('LOG: Se cargaron ${loadedFlights.length} vuelos desde Firestore');

      // Ordenar los vuelos por hora de salida (descendente)
      loadedFlights.sort((a, b) {
        final timeA = a['schedule_time'] as String;
        final timeB = b['schedule_time'] as String;
        return timeB.compareTo(timeA); // Orden invertido para descendente
      });

      print('LOG: Vuelos ordenados por hora de salida (descendente)');

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

        // Si no tenemos datos en caché, usar datos de respaldo
        if (_flights.isEmpty) {
          _usingFallbackData = true;
          _flights = _getFallbackFlights();
        }
      });
    }
  }

  // Método para obtener datos ficticios más completos
  List<Map<String, dynamic>> _getFallbackFlights() {
    print('LOG: Cargando datos ficticios como respaldo');
    return [
      {
        'airline': 'SK',
        'flight_id': 'SK1475',
        'schedule_time': '18:55',
        'airport': 'CPH',
        'gate': 'D5',
        'color': const Color.fromARGB(255, 33, 150, 243),
      },
      {
        'airline': 'DY',
        'flight_id': 'DY328',
        'schedule_time': '17:50',
        'airport': 'TOS',
        'gate': 'A8',
        'color': const Color.fromARGB(255, 255, 68, 68),
      },
      {
        'airline': 'DY',
        'flight_id': 'DY1054',
        'schedule_time': '17:55',
        'airport': 'GDN',
        'gate': 'D4',
        'color': const Color.fromARGB(255, 255, 68, 68),
      },
      {
        'airline': 'SK',
        'flight_id': 'SK1330',
        'schedule_time': '18:10',
        'airport': 'AES',
        'gate': 'A2',
        'color': const Color.fromARGB(255, 33, 150, 243),
      },
      {
        'airline': 'DX',
        'flight_id': 'DX578',
        'schedule_time': '18:15',
        'airport': 'FRO',
        'gate': 'A27',
        'color': const Color.fromARGB(255, 76, 175, 80),
      },
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _flights.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    // Si hay un error pero estamos usando datos de respaldo,
    // mostrar los datos con un banner de advertencia
    if (_usingFallbackData) {
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            color: Colors.amber.shade100,
            child: Row(
              children: [
                const Icon(Icons.warning, color: Colors.amber),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _errorMessage ??
                        'Usando datos de ejemplo mientras se configura la conexión',
                    style: TextStyle(color: Colors.amber.shade900),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadFlights,
                  tooltip: 'Reintentar conexión con Firestore',
                ),
              ],
            ),
          ),
          Expanded(
            child: AllDeparturesUI(
              flights: _flights,
              onRefresh: _loadFlights,
              isRefreshing: _isLoading,
              lastUpdated: _lastUpdated,
            ),
          ),
        ],
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
    // Limpiar recursos si es necesario
    print('LOG: Disposing AllDeparturesScreen');
    super.dispose();
  }
}
