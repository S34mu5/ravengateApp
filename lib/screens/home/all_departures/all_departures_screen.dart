import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import 'package:intl/intl.dart';
import 'dart:async'; // Importar para usar Timer
import 'all_departures_ui.dart';
import '../../../services/cache/cache_service.dart';
import '../../../utils/airline_helper.dart'; // Importar la nueva clase utilitaria
import '../base_departures_screen.dart';
import '../../../utils/flight_sort_util.dart';

/// Componente que maneja la lógica y los datos para la pantalla de todos los vuelos de salida
/// Obtiene los datos desde Firestore en la colección 'flights'
class AllDeparturesScreen extends BaseDeparturesScreen {
  const AllDeparturesScreen({super.key});

  @override
  State<AllDeparturesScreen> createState() => _AllDeparturesScreenState();
}

class _AllDeparturesScreenState
    extends BaseDeparturesScreenState<AllDeparturesScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> _flights = [];
  Timer? _refreshTimer; // Timer para actualización periódica

  @override
  void initState() {
    super.initState();
    loadFlights();
    // Configurar actualización automática cada 3 minutos (180000 ms)
    _refreshTimer = Timer.periodic(const Duration(minutes: 3), (timer) {
      print('LOG: Actualizando datos automáticamente cada 3 minutos');
      loadFlights(forceRefresh: true);
    });
  }

  @override
  Future<void> loadFlights({bool forceRefresh = false}) async {
    print('LOG: Cargando vuelos desde Firestore - usando colección existente');
    try {
      if (!mounted) {
        print('LOG: Widget no montado, cancelando carga de vuelos');
        return;
      }

      setLoading(true);
      setError(null);

      // Calcular la hora de corte (3 horas antes de la hora actual)
      final DateTime now = DateTime.now();
      final DateTime cutoffTime = now.subtract(const Duration(hours: 3));
      final String cutoffTimeString = cutoffTime.toIso8601String();

      print(
          'LOG: Filtrando vuelos a partir de: ${DateFormat('yyyy-MM-dd HH:mm').format(cutoffTime)}');

      // Realizar la consulta a Firestore
      final QuerySnapshot snapshot = await _firestore
          .collection('flights')
          .orderBy('schedule_time', descending: false)
          .where('schedule_time', isGreaterThanOrEqualTo: cutoffTimeString)
          .get();

      if (!mounted) return;

      if (snapshot.docs.isEmpty) {
        setError('No se encontraron vuelos disponibles');
        setLoading(false);
        return;
      }

      // Convertir los datos de Firestore
      final List<Map<String, dynamic>> loadedFlights = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        Color flightColor = data['color'] is int
            ? Color(data['color'])
            : AirlineHelper.getAirlineColor(data['airline'] ?? '');

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

      // Ordenar los vuelos usando el utilitario compartido
      final sortedFlights = FlightSortUtil.sortFlightsByTime(loadedFlights);

      if (!mounted) return;

      setState(() {
        _flights = sortedFlights;
      });
      setLoading(false);
      setUsingCachedData(false);
      setLastUpdated(DateTime.now());

      // Guardar en caché
      await CacheService.saveFlights(_flights);
    } catch (e) {
      print('LOG: ERROR al cargar vuelos desde Firestore: $e');
      if (!mounted) return;
      setError('Error al cargar vuelos: $e');
      setLoading(false);
    }
  }

  @override
  Widget buildUI() {
    return AllDeparturesUI(
      flights: _flights,
      onRefresh: () => loadFlights(forceRefresh: true),
      lastUpdated: lastUpdated,
      usingCachedData: usingCachedData,
    );
  }

  @override
  void dispose() {
    // Cancelar el timer cuando se destruye el widget para evitar memory leaks
    _refreshTimer?.cancel();
    print('LOG: Disposing AllDeparturesScreen and cancelling refresh timer');
    super.dispose();
  }
}
