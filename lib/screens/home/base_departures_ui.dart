import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../common/widgets/flight_card.dart';
import '../../common/widgets/flight_search_bar.dart';
import '../../common/widgets/flights_counter_display.dart';
import '../../common/widgets/flight_selection_controls.dart';
import '../../common/widgets/time_ago_widget.dart';
import '../../utils/flight_filter_util.dart';
import '../../utils/flight_sort_util.dart';

/// Widget base para la interfaz de usuario de pantallas de vuelos
abstract class BaseDeparturesUI extends StatefulWidget {
  final List<Map<String, dynamic>> flights;
  final Future<void> Function()? onRefresh;
  final DateTime? lastUpdated;
  final bool usingCachedData;

  const BaseDeparturesUI({
    required this.flights,
    this.onRefresh,
    this.lastUpdated,
    this.usingCachedData = false,
    super.key,
  });
}

/// Estado base para UI de pantallas de vuelos
abstract class BaseDeparturesUIState<T extends BaseDeparturesUI>
    extends State<T> {
  // Listas de vuelos
  List<Map<String, dynamic>> filteredFlights = [];

  // Variables para búsqueda y filtrado
  String searchQuery = '';
  final TextEditingController searchController = TextEditingController();
  bool norwegianEquivalenceEnabled = true;

  // Variables para el modo de selección
  bool isSelectionMode = false;
  Set<int> selectedFlightIndices = {};

  // Scroll controller
  final ScrollController scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    updateFilteredFlights();
    loadNorwegianPreference();
  }

  @override
  void didUpdateWidget(T oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.flights != oldWidget.flights) {
      updateFilteredFlights();
    }
  }

  @override
  void dispose() {
    searchController.dispose();
    scrollController.dispose();
    super.dispose();
  }

  // Métodos a implementar por las clases derivadas

  /// Construye el widget principal para la lista de vuelos
  Widget buildFlightsList();

  /// Define la acción a realizar cuando se pulsa un vuelo (navegar a detalles)
  void onFlightTap(BuildContext context, Map<String, dynamic> flight);

  /// Define la acción a realizar con los vuelos seleccionados
  Future<void> performActionOnSelectedFlights();

  // Métodos compartidos

  /// Actualizar la lista filtrada cuando cambian los datos
  void updateFilteredFlights() {
    // Filtrar según criterio de búsqueda
    final filteredList = FlightFilterUtil.filterFlights(
      flights: widget.flights,
      searchQuery: searchQuery,
      norwegianEquivalenceEnabled: norwegianEquivalenceEnabled,
    );

    // Ordenar
    final sortedList = FlightSortUtil.sortFlightsByTime(filteredList);

    setState(() {
      filteredFlights = sortedList;
    });
  }

  /// Filtrar vuelos por texto de búsqueda
  void filterFlights(String query) {
    setState(() {
      searchQuery = query;
      updateFilteredFlights();
    });
  }

  /// Cargar preferencia de equivalencia Norwegian
  Future<void> loadNorwegianPreference() async {
    final isEnabled = await FlightFilterUtil.loadNorwegianPreference();
    setState(() {
      norwegianEquivalenceEnabled = isEnabled;
    });
    print(
        'LOG: Norwegian equivalence preference loaded: $norwegianEquivalenceEnabled');
  }

  /// Activar o desactivar el modo de selección múltiple
  void toggleSelectionMode() {
    setState(() {
      isSelectionMode = !isSelectionMode;
      // Si desactivamos el modo selección, limpiar las selecciones
      if (!isSelectionMode) {
        selectedFlightIndices.clear();
      }
    });
  }

  /// Seleccionar o deseleccionar un vuelo por su índice
  void toggleFlightSelection(int index) {
    setState(() {
      if (selectedFlightIndices.contains(index)) {
        selectedFlightIndices.remove(index);
      } else {
        selectedFlightIndices.add(index);
      }

      // Si no quedan vuelos seleccionados, desactivar el modo selección
      if (selectedFlightIndices.isEmpty && isSelectionMode) {
        isSelectionMode = false;
      }
    });
  }

  /// Seleccionar todos los vuelos filtrados
  void selectAllFlights() {
    setState(() {
      selectedFlightIndices = Set<int>.from(
          List<int>.generate(filteredFlights.length, (index) => index));
    });
  }

  /// Deseleccionar todos los vuelos
  void deselectAllFlights() {
    setState(() {
      selectedFlightIndices.clear();
    });
  }

  /// Formatear timestamp de última actualización
  String formatLastUpdated(DateTime timestamp) {
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

  /// Construir el encabezado con indicador de datos en caché
  Widget buildCachedDataHeader() {
    if (!widget.usingCachedData) {
      return buildFlightsList();
    }

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
                widget.lastUpdated != null
                    ? 'Última actualización: ${formatLastUpdated(widget.lastUpdated!)}'
                    : 'Usando datos almacenados',
                style: TextStyle(color: Colors.blue.shade900, fontSize: 13),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh, size: 16),
                onPressed: widget.onRefresh ?? () async {},
                tooltip: 'Actualizar datos ahora',
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
        Expanded(
          child: buildFlightsList(),
        ),
      ],
    );
  }

  /// Estructura base para construir un item de vuelo
  Widget buildFlightItem(Map<String, dynamic> flight, int index,
      {bool isDismissible = false}) {
    return FlightCard(
      flight: flight,
      isSelectionMode: isSelectionMode,
      isSelected: selectedFlightIndices.contains(index),
      isDismissible: isDismissible && !isSelectionMode,
      selectionColor: const Color(0xFF4285F4), // Google Blue
      onSelectionToggle: (value) {
        toggleFlightSelection(index);
      },
      onTap: () {
        if (isSelectionMode) {
          toggleFlightSelection(index);
        } else {
          onFlightTap(context, flight);
        }
      },
      onLongPress: isSelectionMode
          ? null
          : () {
              // Si no estamos en modo selección, activarlo y seleccionar este vuelo
              if (!isSelectionMode) {
                setState(() {
                  isSelectionMode = true;
                  selectedFlightIndices.add(index);
                });
              }
            },
    );
  }

  /// Construcción base para el botón flotante de selección
  Widget? buildSelectionControls({
    required String actionLabel,
    required IconData actionIcon,
    Color actionColor = Colors.white,
    Color actionTextColor = Colors.black87,
  }) {
    if (!isSelectionMode) return null;

    return FlightSelectionControls(
      selectedCount: selectedFlightIndices.length,
      totalFlights: filteredFlights.length,
      onSelectAll: selectAllFlights,
      onDeselectAll: deselectAllFlights,
      onExit: toggleSelectionMode,
      onAction: performActionOnSelectedFlights,
      actionLabel: actionLabel,
      actionColor: actionColor,
      actionTextColor: actionTextColor,
      actionIcon: actionIcon,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Implementación común para todas las UI de vuelos
    return buildCachedDataHeader();
  }
}
