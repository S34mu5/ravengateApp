import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../utils/flight_search_helper.dart';
import '../flight_details/flight_details_screen.dart';
import '../flight_details/oz_flight_details_screen.dart';
import '../../../services/cache/cache_service.dart';
import '../../../common/widgets/flight_card.dart';
import '../../../services/location/location_service.dart';
import '../../../utils/progress_dialog.dart';
import '../../../utils/logger.dart';

/// Widget que muestra la interfaz de usuario para la lista de vuelos archivados
class ArchivedFlightsUI extends StatefulWidget {
  final List<Map<String, dynamic>> flights;
  final Future<void> Function()? onRefresh;
  final Future<void> Function(String flightId)? onRestoreFlight;
  final Future<void> Function(String flightId)? onDeleteFlight;
  final DateTime? lastUpdated;
  final bool usingCachedData;

  const ArchivedFlightsUI({
    required this.flights,
    this.onRefresh,
    this.onRestoreFlight,
    this.onDeleteFlight,
    this.lastUpdated,
    this.usingCachedData = false,
    super.key,
  });

  @override
  State<ArchivedFlightsUI> createState() => _ArchivedFlightsUIState();
}

class _ArchivedFlightsUIState extends State<ArchivedFlightsUI> {
  // Variables para búsqueda y filtrado
  List<Map<String, dynamic>> _filteredFlights = [];
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  bool _norwegianEquivalenceEnabled = true; // Habilitado por defecto

  // Variables para el modo de selección
  bool _isSelectionMode = false;
  Set<int> _selectedFlightIndices = {};

  // Formatters for date and time

  @override
  void initState() {
    super.initState();
    _updateFilteredFlights();
    _loadNorwegianPreference();
  }

  @override
  void didUpdateWidget(ArchivedFlightsUI oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.flights != oldWidget.flights) {
      _updateFilteredFlights();
    }
  }

  // Actualizar la lista filtrada cuando cambian los datos
  void _updateFilteredFlights() {
    setState(() {
      _filteredFlights = FlightSearchHelper.filterFlights(
        flights: widget.flights,
        searchQuery: _searchQuery,
        norwegianEquivalenceEnabled: _norwegianEquivalenceEnabled,
      );
    });
  }

  // Filtrar vuelos por texto de búsqueda
  void _filterFlights(String query) {
    setState(() {
      _searchQuery = query;
      _filteredFlights = FlightSearchHelper.filterFlights(
        flights: widget.flights,
        searchQuery: query,
        norwegianEquivalenceEnabled: _norwegianEquivalenceEnabled,
      );
    });
  }

  // Cargar preferencia de equivalencia Norwegian
  Future<void> _loadNorwegianPreference() async {
    final isEnabled = await CacheService.getNorwegianEquivalencePreference();

    if (!mounted)
      return; // Evitar usar context/setState si el widget ya no está

    setState(() {
      _norwegianEquivalenceEnabled = isEnabled;
    });
    AppLogger.info(
        'Norwegian equivalence preference loaded: $_norwegianEquivalenceEnabled');
  }

  /// Activar o desactivar el modo de selección múltiple
  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      // Si desactivamos el modo selección, limpiar las selecciones
      if (!_isSelectionMode) {
        _selectedFlightIndices.clear();
      }
    });
  }

  /// Seleccionar o deseleccionar un vuelo por su índice
  void _toggleFlightSelection(int index) {
    setState(() {
      if (_selectedFlightIndices.contains(index)) {
        _selectedFlightIndices.remove(index);
      } else {
        _selectedFlightIndices.add(index);
      }

      // Si no quedan vuelos seleccionados, desactivar el modo selección
      if (_selectedFlightIndices.isEmpty && _isSelectionMode) {
        _isSelectionMode = false;
      }
    });
  }

  /// Seleccionar todos los vuelos filtrados
  void _selectAllFlights() {
    setState(() {
      _selectedFlightIndices = Set<int>.from(
          List<int>.generate(_filteredFlights.length, (index) => index));
    });
  }

  /// Deseleccionar todos los vuelos
  void _deselectAllFlights() {
    setState(() {
      _selectedFlightIndices.clear();
    });
  }

  /// Restaurar los vuelos seleccionados
  Future<void> _restoreSelectedFlights() async {
    if (_selectedFlightIndices.isEmpty || widget.onRestoreFlight == null) {
      return;
    }

    // Mostrar diálogo de progreso
    final progressDialog = ProgressDialog(
      context,
      type: ProgressDialogType.normal,
      isDismissible: false,
    );

    progressDialog.style(
      message: 'Restaurando vuelos...',
      borderRadius: 10.0,
      backgroundColor: Colors.white,
      progressWidget: const CircularProgressIndicator(),
      elevation: 10.0,
      insetAnimCurve: Curves.easeInOut,
    );

    await progressDialog.show();

    try {
      // Restaurar cada vuelo seleccionado
      int restoredCount = 0;
      for (final index in _selectedFlightIndices) {
        if (index < _filteredFlights.length) {
          final flight = _filteredFlights[index];
          final docId = flight['doc_id'];

          if (docId != null && docId.isNotEmpty) {
            // Llamar a la función para restaurar usando el doc_id
            await widget.onRestoreFlight!(docId);
            restoredCount++;
            AppLogger.info('Vuelo restaurado: $docId');
          }
        }
      }

      // Cerrar el diálogo de progreso
      if (progressDialog.isShowing) {
        await progressDialog.hide();
      }

      if (!mounted) return;

      // Mostrar mensaje de éxito
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Restaurados $restoredCount vuelos'),
          backgroundColor: Colors.green.shade700,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Desactivar el modo selección y limpiar selecciones
      setState(() {
        _isSelectionMode = false;
        _selectedFlightIndices.clear();
      });

      // Actualizar la lista de vuelos
      if (widget.onRefresh != null) {
        await widget.onRefresh!();
      }
    } catch (e) {
      // Cerrar el diálogo de progreso
      if (progressDialog.isShowing) {
        await progressDialog.hide();
      }

      if (!mounted) return;

      // Mostrar mensaje de error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al restaurar vuelos: $e'),
          backgroundColor: Colors.red.shade700,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Eliminar permanentemente los vuelos seleccionados
  Future<void> _deleteSelectedFlights() async {
    if (_selectedFlightIndices.isEmpty || widget.onDeleteFlight == null) {
      return;
    }

    // Mostrar diálogo de confirmación
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Eliminar permanentemente"),
        content: Text(
            "¿Estás seguro que deseas eliminar permanentemente ${_selectedFlightIndices.length} vuelos? Esta acción no se puede deshacer."),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("Cancelar"),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text("Eliminar permanentemente"),
          ),
        ],
      ),
    );

    if (!mounted)
      return; // El widget pudo haber sido removido mientras el diálogo estaba abierto

    if (shouldDelete != true) {
      return;
    }

    // Mostrar diálogo de progreso
    final progressDialog = ProgressDialog(
      context,
      type: ProgressDialogType.normal,
      isDismissible: false,
    );

    progressDialog.style(
      message: 'Eliminando vuelos...',
      borderRadius: 10.0,
      backgroundColor: Colors.white,
      progressWidget: const CircularProgressIndicator(),
      elevation: 10.0,
      insetAnimCurve: Curves.easeInOut,
    );

    await progressDialog.show();

    try {
      // Eliminar cada vuelo seleccionado
      int deletedCount = 0;
      for (final index in _selectedFlightIndices) {
        if (index < _filteredFlights.length) {
          final flight = _filteredFlights[index];
          final docId = flight['doc_id'];

          if (docId != null && docId.isNotEmpty) {
            // Llamar a la función para eliminar usando el doc_id
            await widget.onDeleteFlight!(docId);
            deletedCount++;
            AppLogger.info('Vuelo eliminado: $docId');
          }
        }
      }

      // Cerrar el diálogo de progreso
      if (progressDialog.isShowing) {
        await progressDialog.hide();
      }

      if (!mounted) return;

      // Mostrar mensaje de éxito
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Eliminados $deletedCount vuelos permanentemente'),
          backgroundColor: Colors.red.shade700,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Desactivar el modo selección y limpiar selecciones
      setState(() {
        _isSelectionMode = false;
        _selectedFlightIndices.clear();
      });

      // Actualizar la lista de vuelos
      if (widget.onRefresh != null) {
        await widget.onRefresh!();
      }
    } catch (e) {
      // Cerrar el diálogo de progreso
      if (progressDialog.isShowing) {
        await progressDialog.hide();
      }

      if (!mounted) return;

      // Mostrar mensaje de error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al eliminar vuelos: $e'),
          backgroundColor: Colors.red.shade700,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: widget.onRefresh ?? () async {},
      child: Column(
        children: [
          // Controles de búsqueda y selección
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                // Icono de búsqueda
                const Icon(Icons.search, color: Colors.blueGrey),
                const SizedBox(width: 8),
                // Campo de búsqueda
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: 'Search flights (airline, flight id...)',
                      border: InputBorder.none,
                    ),
                    onChanged: _filterFlights,
                  ),
                ),
                // Botón para limpiar búsqueda
                if (_searchQuery.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      _filterFlights('');
                    },
                    tooltip: 'Clear search',
                  ),
                // Botón para activar/desactivar selección múltiple
                IconButton(
                  icon: Icon(_isSelectionMode
                      ? Icons.check_circle
                      : Icons.check_circle_outline),
                  onPressed: _toggleSelectionMode,
                  tooltip: 'Toggle selection mode',
                ),
              ],
            ),
          ),

          // Información sobre la cantidad de vuelos y estado de la caché
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Contador de vuelos filtrados
                Text(
                  '${_filteredFlights.length} flights found',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.blueGrey.shade600,
                  ),
                ),
                // Indicador de caché
                if (widget.usingCachedData && widget.lastUpdated != null)
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 14,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Cached data from ${_formatTimestamp(widget.lastUpdated!)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),

          // Controles de selección (mostrar solo en modo selección)
          if (_isSelectionMode && _filteredFlights.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Texto de selección
                  Text(
                    'Selected: ${_selectedFlightIndices.length} of ${_filteredFlights.length}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  // Botones de acción
                  Row(
                    children: [
                      // Botón para seleccionar/deseleccionar todos
                      IconButton(
                        icon: Icon(
                          _selectedFlightIndices.length ==
                                  _filteredFlights.length
                              ? Icons.deselect
                              : Icons.select_all,
                          color: Colors.blue,
                        ),
                        onPressed: _selectedFlightIndices.length ==
                                _filteredFlights.length
                            ? _deselectAllFlights
                            : _selectAllFlights,
                        tooltip: _selectedFlightIndices.length ==
                                _filteredFlights.length
                            ? 'Deselect all'
                            : 'Select all',
                      ),
                      // Botón para restaurar seleccionados
                      IconButton(
                        icon: const Icon(Icons.restore, color: Colors.green),
                        onPressed: _selectedFlightIndices.isNotEmpty
                            ? _restoreSelectedFlights
                            : null,
                        tooltip: 'Restore selected',
                      ),
                      // Botón para eliminar seleccionados
                      IconButton(
                        icon:
                            const Icon(Icons.delete_forever, color: Colors.red),
                        onPressed: _selectedFlightIndices.isNotEmpty
                            ? _deleteSelectedFlights
                            : null,
                        tooltip: 'Delete selected',
                      ),
                      // Botón para salir del modo selección
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: _toggleSelectionMode,
                        tooltip: 'Exit selection mode',
                      ),
                    ],
                  ),
                ],
              ),
            ),

          // Lista de vuelos
          Expanded(
            child: _buildFlightsList(),
          ),
        ],
      ),
    );
  }

  /// Formatear timestamp para mostrar cuándo se actualizaron los datos
  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return DateFormat('dd MMM, HH:mm').format(timestamp);
    }
  }

  Widget _buildFlightsList() {
    AppLogger.debug(
        'Construyendo UI de archived flights (${widget.flights.length} total, ${_filteredFlights.length} filtrados)');
    return Expanded(
      child: _filteredFlights.isEmpty
          ? _buildEmptyState(context)
          : ListView.builder(
              itemCount: _filteredFlights.length,
              itemBuilder: (context, index) {
                final flight = _filteredFlights[index];

                return FlightCard(
                  flight: flight,
                  isSelectionMode: _isSelectionMode,
                  isSelected: _selectedFlightIndices.contains(index),
                  isDismissible: false,
                  showStatusBadges: false,
                  onSelectionToggle: (bool? value) {
                    _toggleFlightSelection(index);
                  },
                  onTap: () {
                    if (_isSelectionMode) {
                      // En modo selección, seleccionar/deseleccionar
                      _toggleFlightSelection(index);
                    } else {
                      // En modo normal, navegar a detalles
                      _navigateToFlightDetails(context, flight);
                    }
                  },
                  onLongPress: _isSelectionMode
                      ? null
                      : () {
                          // Si no estamos en modo selección, activarlo y seleccionar este vuelo
                          if (!_isSelectionMode) {
                            setState(() {
                              _isSelectionMode = true;
                              _selectedFlightIndices.add(index);
                            });
                          }
                        },
                );
              },
            ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    // Si hay búsqueda pero no resultados, mostrar mensaje específico
    if (_searchQuery.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.search_off,
              size: 72,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              'No archived flights found for "$_searchQuery"',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                _searchController.clear();
                _filterFlights('');
              },
              child: const Text('Clear search'),
            ),
          ],
        ),
      );
    }

    // Estado vacío normal si no hay vuelos archivados
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.archive_outlined,
            size: 72,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No archived flights',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'When you archive flights, they will appear here',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  /// Navega a la pantalla de detalles del vuelo seleccionado
  void _navigateToFlightDetails(
      BuildContext context, Map<String, dynamic> flight) async {
    // Verificar la ubicación actual
    final bool isOversize = await LocationService.isOversizeLocation();

    if (!mounted) return; // Evitar usar context después del await

    AppLogger.debug('Ubicación actual: ${isOversize ? "Oversize" : "Bins"}');

    // Registrar información de depuración
    AppLogger.debug('Navegando a detalles de vuelo archivado');
    AppLogger.debug('Flight ID: ${flight['flight_id']}');
    AppLogger.debug('Doc ID en archived_flights: ${flight['doc_id']}');
    AppLogger.debug(
        'Original Doc ID: ${flight['original_doc_id'] ?? "No disponible"}');
    AppLogger.debug('Campo id original: ${flight['id'] ?? "No disponible"}');
    AppLogger.debug('Archived at: ${flight['archived_at']}');
    AppLogger.debug('Status code: ${flight['status_code'] ?? "No disponible"}');

    // IMPORTANTE: En vuelos archivados, necesitamos usar el ID del documento original en flights
    // Buscar en este orden de prioridad para encontrar el ID correcto:
    String documentIdToUse = '';

    // 1. Primero intentar con el campo 'original_doc_id' (referencia explícita al documento original)
    if (flight.containsKey('original_doc_id') &&
        flight['original_doc_id'] != null &&
        flight['original_doc_id'].toString().isNotEmpty) {
      documentIdToUse = flight['original_doc_id'];
    }
    // 2. Luego intentar con el campo 'id' (a veces contiene el ID original)
    else if (flight.containsKey('id') &&
        flight['id'] != null &&
        flight['id'].toString().isNotEmpty) {
      documentIdToUse = flight['id'];
    }
    // 3. Como último recurso, usar el 'doc_id' actual
    else {
      documentIdToUse = flight['doc_id'] ?? '';
    }

    AppLogger.debug('Document ID para detalles: $documentIdToUse');

    // Para diagnóstico, imprimir todas las claves del objeto vuelo
    AppLogger.debug('Campos en flight: ${flight.keys.toList()}');
    AppLogger.debug('Total vuelos enviados: ${widget.flights.length}');

    // Variable para almacenar el resultado (si se debe actualizar)
    bool? shouldRefresh;

    // Verificar el status_code del vuelo para decidir si forzar actualización
    final String statusCode = flight['status_code']?.toString() ?? '';
    final bool forceRefresh = !(statusCode == 'D' || statusCode == 'C');

    if (forceRefresh) {
      AppLogger.debug(
          'El vuelo tiene status $statusCode, se forzará actualización al regresar');
    } else {
      AppLogger.debug(
          'El vuelo tiene status $statusCode (departed o cancelled), no se forzará actualización');
    }

    if (isOversize) {
      // Si la ubicación es Oversize, mostrar la pantalla de detalles de Oversize
      shouldRefresh = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) => OzFlightDetailsScreen(
            flightId: flight['flight_id'],
            documentId: documentIdToUse,
            flightsList: widget.flights, // Pasar toda la lista de vuelos
            flightsSource: 'archived', // Indicar que viene de vuelos archivados
            forceRefreshOnReturn:
                forceRefresh, // Condicional según status del vuelo
          ),
        ),
      );
    } else {
      // Si la ubicación es Bins, mostrar la pantalla de detalles normal
      shouldRefresh = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) => FlightDetailsScreen(
            flightId: flight['flight_id'],
            documentId: documentIdToUse,
            flightsList: widget.flights, // Pasar toda la lista de vuelos
            flightsSource: 'archived', // Indicar que viene de vuelos archivados
            forceRefreshOnReturn:
                forceRefresh, // Condicional según status del vuelo
          ),
        ),
      );
    }

    // Si se recibió true como resultado, actualizar la lista de vuelos
    if (shouldRefresh == true && widget.onRefresh != null) {
      AppLogger.debug(
          'Forzando actualización tras regresar de detalles de vuelo');
      await widget.onRefresh!();
    }
  }
}
