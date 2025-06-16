import 'package:flutter/material.dart';
import '../../../utils/progress_dialog.dart';
import '../../../common/widgets/flight_search_bar.dart';
import '../../../common/widgets/flights_counter_display.dart';
import '../../../common/widgets/time_ago_widget.dart';
import 'all_departures_filters.dart';
import 'all_departures_selection.dart';
import 'all_departures_utils.dart';
import '../base_departures_ui.dart';
import '../../../utils/logger.dart';
import '../../../l10n/app_localizations.dart';

/// Widget que muestra la interfaz de usuario para la lista de todos los vuelos de salida
class AllDeparturesUI extends BaseDeparturesUI {
  final Future<void> Function(DateTime startDateTime, DateTime endDateTime)?
      onCustomRangeLoad;
  final bool isRefreshing;

  const AllDeparturesUI({
    required super.flights,
    super.onRefresh,
    this.onCustomRangeLoad,
    this.isRefreshing = false,
    super.lastUpdated,
    super.usingCachedData,
    super.key,
  });

  @override
  State<AllDeparturesUI> createState() => _AllDeparturesUIState();
}

class _AllDeparturesUIState extends BaseDeparturesUIState<AllDeparturesUI> {
  // Gestión de filtros
  late DeparturesFilters _filters;

  @override
  void initState() {
    _filters = DeparturesFilters();
    super.initState();
    _loadFiltersFromCache();
  }

  // Cargar filtros guardados
  Future<void> _loadFiltersFromCache() async {
    _filters = await DeparturesFilters.loadFiltersFromCache();
    setState(() {});
    _applyFilters();
  }

  // Aplicar todos los filtros
  void _applyFilters() {
    setState(() {
      filteredFlights = _filters.applyAllFilters(widget.flights);
      // Ordenar después de filtrar
      filteredFlights =
          AllDeparturesUtils.sortFlightsByDepartureTime(filteredFlights);
      // Desplazarse al primer vuelo no departed
      _scrollToFirstNonDepartedFlight();
    });
  }

  // Reset to default filters
  void _resetToDefaultFilters() {
    setState(() {
      _filters.resetToDefaultFilters();
      filteredFlights = List.from(widget.flights);
      _applyFilters();
      _filters.saveFiltersToCache();
    });
  }

  // Mostrar selector de rango de fecha y hora
  Future<void> _showDateTimeRangePicker(BuildContext context) async {
    final filtersChanged = await _filters.showDateTimeRangePicker(context);

    if (!mounted || !context.mounted) {
      return; // Evita usar context/estado o un BuildContext desmontado tras el picker
    }

    if (filtersChanged) {
      // Determinar si necesitamos cargar datos históricos
      final startDateTime =
          _filters.timeOfDayToDateTime(_filters.startDate, _filters.startTime);
      final threePastHours = DateTime.now().subtract(const Duration(hours: 3));
      final needsHistoricalData = startDateTime.isBefore(threePastHours);

      AppLogger.debug('startDateTime: $startDateTime');
      AppLogger.debug('threePastHours: $threePastHours');
      AppLogger.debug('needsHistoricalData: $needsHistoricalData');
      AppLogger.debug(
          'onCustomRangeLoad is null: ${widget.onCustomRangeLoad == null}');

      if (needsHistoricalData && widget.onCustomRangeLoad != null) {
        // Crear y configurar el diálogo de progreso
        final ProgressDialog progressDialog = ProgressDialog(
          context,
          isDismissible: false,
        );

        // Configurar el estilo del diálogo
        progressDialog.style(
          message: 'Cargando datos históricos...',
          progressWidget: const CircularProgressIndicator(),
          elevation: 8.0,
          backgroundColor: Colors.white,
          insetAnimCurve: Curves.easeInOut,
          padding: const EdgeInsets.all(16.0),
          borderRadius: 10.0,
        );

        // Mostrar el diálogo de progreso
        await progressDialog.show();

        try {
          // Cargar datos históricos desde la base de datos
          final endDateTime =
              _filters.timeOfDayToDateTime(_filters.endDate, _filters.endTime);
          await widget.onCustomRangeLoad!(startDateTime, endDateTime);

          if (!mounted) return; // Evitar uso de context después de dispose
        } finally {
          // Asegurarse de ocultar el diálogo cuando termine la carga
          if (progressDialog.isShowing) {
            await progressDialog.hide();
          }
        }
      } else {
        // Solo filtrar los datos actuales
        _applyFilters();
      }

      _filters.saveFiltersToCache();
    }
  }

  // Desplazarse al primer vuelo activo
  void _scrollToFirstNonDepartedFlight() {
    // Esperar a que la interfaz se actualice antes de desplazarse
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (filteredFlights.isEmpty) {
        return; // No hay vuelos para desplazar
      }

      // Verificar si el scrollController está adjunto a alguna vista
      if (!scrollController.hasClients) {
        AppLogger.debug('ScrollController aún no está adjunto a ninguna vista');
        return; // Salir si el controlador no está adjunto
      }

      // Encontrar el índice del primer vuelo activo
      int index =
          AllDeparturesUtils.findFirstActiveFlightIndex(filteredFlights);

      // Si encontramos un vuelo activo, desplazarse a él
      if (index != -1) {
        // Calcular la posición aproximada
        const double itemHeight = 70.0; // Altura aproximada de un Card
        final double offset = index * itemHeight;

        // Verificar que el offset no sea mayor que el máximo scroll
        if (offset > scrollController.position.maxScrollExtent) {
          AppLogger.debug(
              'Offset calculado excede el máximo desplazamiento disponible');
          scrollController.jumpTo(scrollController.position.maxScrollExtent);
          return;
        }

        // Desplazarse a la posición
        try {
          scrollController.animateTo(
            offset,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
          );
          AppLogger.debug('Scrolled to first active flight at index $index');
        } catch (e) {
          AppLogger.error('Error al desplazarse', e);
        }
      } else {
        AppLogger.debug('No active flights found to scroll to');
      }
    });
  }

  @override
  Widget buildFlightsList() {
    return Scaffold(
      backgroundColor: Colors.white,
      floatingActionButton: buildSelectionControls(
        actionLabel: AppLocalizations.of(context)!.addToMyDepartures,
        actionIcon: Icons.save,
      ),
      body: Column(
        children: [
          // Añadir un pequeño espacio en la parte superior
          const SizedBox(height: 8),

          // Date and time range selector
          Padding(
            padding: const EdgeInsets.only(
                left: 16.0, right: 16.0, top: 4.0, bottom: 4.0),
            child: InkWell(
              onTap: () => _showDateTimeRangePicker(context),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.date_range, color: Colors.blue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Show departures from ${_filters.formatDateTimeRange()}',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                    Icon(Icons.arrow_drop_down, color: Colors.grey.shade600),
                  ],
                ),
              ),
            ),
          ),

          // Barra de búsqueda
          FlightSearchBar(
            controller: searchController,
            onSearch: (query) {
              _filters.searchQuery = query;
              _applyFilters();
              _filters.saveFiltersToCache();
            },
            onClear: () {
              _filters.searchQuery = '';
              _applyFilters();
              _filters.saveFiltersToCache();
            },
          ),

          // Indicador de actualizado
          TimeAgoWidget(lastUpdated: widget.lastUpdated),

          // Contador de vuelos
          FlightsCounterDisplay(
            flightCount: filteredFlights.length,
            searchQuery: _filters.searchQuery,
            norwegianEquivalenceEnabled: _filters.norwegianEquivalenceEnabled,
            onSelectMode: null,
            onResetFilters: (_filters.searchQuery.isNotEmpty ||
                    widget.flights.length != filteredFlights.length)
                ? _resetToDefaultFilters
                : null,
            showResetButton: _filters.searchQuery.isNotEmpty ||
                widget.flights.length != filteredFlights.length,
          ),

          // Lista de vuelos
          Expanded(
            child: filteredFlights.isEmpty
                ? _buildEmptyListMessage()
                : ListView.builder(
                    controller: scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: filteredFlights.length,
                    itemBuilder: (context, index) {
                      return buildFlightItem(filteredFlights[index], index);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // Widget para mostrar cuando no hay vuelos
  Widget _buildEmptyListMessage() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.search_off,
            size: 48,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          Text(
            _filters.searchQuery.isNotEmpty
                ? 'No flights found for "${_filters.searchQuery}"'
                : 'No flights in selected date range',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _resetToDefaultFilters,
            child: const Text('Show all flights'),
          ),
        ],
      ),
    );
  }

  @override
  void onFlightTap(BuildContext context, Map<String, dynamic> flight) {
    AppLogger.debug(
        'User selected flight ${flight['flight_id']} to ${flight['airport']}');

    // Navegar a la pantalla de detalles
    AllDeparturesUtils.navigateToFlightDetails(context, flight, widget.flights);
  }

  @override
  Future<void> performActionOnSelectedFlights() async {
    try {
      final selection = DeparturesSelection();

      // Añadir los vuelos seleccionados a la selección
      for (var index in selectedFlightIndices) {
        selection.toggleFlightSelection(index);
      }

      final result =
          await selection.saveSelectedFlights(context, filteredFlights);

      if (!mounted) return;

      // Build the message based on counters
      String message = '';
      if (result['saved']! > 0) {
        message = 'Added ${result['saved']} flights';
      }

      if (result['restored']! > 0) {
        if (message.isNotEmpty) message += ', ';
        message += 'Restored ${result['restored']} previously archived flights';
      }

      if (result['alreadySaved']! > 0) {
        if (message.isNotEmpty) message += ', ';
        message += '${result['alreadySaved']} already in your list';
      }

      // Mostrar mensaje de éxito
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green.shade700,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );

      setState(() {
        isSelectionMode = false;
        selectedFlightIndices.clear();
      });
    } catch (e) {
      if (!mounted) return;

      // Mostrar mensaje de error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving flights: $e'),
          backgroundColor: Colors.red.shade700,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  void didUpdateWidget(AllDeparturesUI oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.flights != oldWidget.flights) {
      _filters.updateEndDateBasedOnLatestFlight(widget.flights);
      setState(() {});
    }
  }
}
