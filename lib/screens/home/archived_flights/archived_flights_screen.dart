import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'archived_flights_ui.dart';
import '../../../utils/airline_helper.dart';
import '../../../services/user/user_flights_service.dart';
import '../../../utils/progress_dialog.dart';

/// Componente que maneja la lógica y los datos para la pantalla de vuelos archivados
class ArchivedFlightsScreen extends StatefulWidget {
  const ArchivedFlightsScreen({super.key});

  @override
  State<ArchivedFlightsScreen> createState() => _ArchivedFlightsScreenState();
}

class _ArchivedFlightsScreenState extends State<ArchivedFlightsScreen> {
  // Lista de fechas de archivado disponibles
  List<ArchivedFlightDate> _archivedDates = [];

  // Vuelos archivados para la fecha seleccionada
  List<Map<String, dynamic>> _archivedFlights = [];

  bool _isLoading = true;
  String? _errorMessage;

  // Fecha seleccionada actualmente
  String? _selectedDate;

  // Formateador para mostrar fechas de forma amigable
  final DateFormat _dateFormatter = DateFormat('dd MMM yyyy');

  @override
  void initState() {
    super.initState();
    _loadArchivedDates();
  }

  /// Cargar las fechas de vuelos archivados
  Future<void> _loadArchivedDates() async {
    print('LOG: Cargando fechas de vuelos archivados');

    try {
      // Verificar si el widget está montado antes de actualizar estado
      if (!mounted) return;

      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // Obtener fechas de archivado desde el servicio
      final archivedDates =
          await UserFlightsService.getUserArchivedFlightDates();

      // Verificar nuevamente si el widget sigue montado
      if (!mounted) return;

      setState(() {
        _archivedDates = archivedDates;
        _isLoading = false;
      });

      print(
          'LOG: Se cargaron ${_archivedDates.length} fechas de vuelos archivados');

      // Ya no seleccionamos automáticamente la fecha más reciente
      // Dejamos que el usuario seleccione una fecha de la lista
    } catch (e) {
      print('LOG: Error al cargar fechas de vuelos archivados: $e');

      // Verificar si el widget sigue montado antes de actualizar estado de error
      if (!mounted) return;

      setState(() {
        _errorMessage = 'Error loading archived flight dates: $e';
        _isLoading = false;
      });
    }
  }

  /// Seleccionar una fecha y cargar sus vuelos
  Future<void> _selectDate(String date) async {
    print('LOG: Seleccionando fecha $date');

    setState(() {
      _selectedDate = date;
      _isLoading = true;
    });

    try {
      // Cargar vuelos para la fecha seleccionada
      final flights =
          await UserFlightsService.getUserArchivedFlightsByDate(date);

      if (!mounted) return;

      setState(() {
        _archivedFlights = flights;
        _isLoading = false;
      });

      print(
          'LOG: Se cargaron ${_archivedFlights.length} vuelos para la fecha $date');
    } catch (e) {
      print('LOG: Error al cargar vuelos para la fecha $date: $e');

      if (!mounted) return;

      setState(() {
        _errorMessage = 'Error loading flights for selected date: $e';
        _isLoading = false;
      });
    }
  }

  /// Restaurar un vuelo archivado
  Future<void> _restoreFlight(String docId) async {
    try {
      // Verificar si el widget está montado
      if (!mounted) return;

      // Mostrar indicador de progreso
      final progressDialog = ProgressDialog(
        context,
        type: ProgressDialogType.normal,
        isDismissible: false,
      );

      progressDialog.style(
        message: 'Restaurando vuelo...',
        borderRadius: 10.0,
        backgroundColor: Colors.white,
        progressWidget: const CircularProgressIndicator(),
        elevation: 10.0,
        insetAnimCurve: Curves.easeInOut,
      );

      progressDialog.show();

      print('LOG: Intentando restaurar vuelo con ID de documento: $docId');

      // Restaurar el vuelo archivado usando el ID del documento
      final wasRestored = await UserFlightsService.restoreArchivedFlight(docId);

      // Cerrar el diálogo de progreso
      if (progressDialog.isShowing) {
        await progressDialog.hide();
      }

      // Verificar si el widget sigue montado
      if (!mounted) return;

      // Mostrar mensaje de éxito o error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            wasRestored
                ? 'Flight restored successfully'
                : 'Could not restore flight',
          ),
          backgroundColor:
              wasRestored ? Colors.blue.shade700 : Colors.orange.shade700,
          duration: const Duration(seconds: 2),
        ),
      );

      // Si hay una fecha seleccionada, recargar los vuelos para esa fecha
      if (_selectedDate != null) {
        await _selectDate(_selectedDate!);

        // También actualizamos la lista de fechas en caso de que esta fecha ya no tenga vuelos
        await _loadArchivedDates();
      }
    } catch (e) {
      print('LOG: Error restoring flight with document ID $docId: $e');

      // Verificar si el widget sigue montado
      if (!mounted) return;

      // Mostrar mensaje de error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error restoring flight: $e'),
          backgroundColor: Colors.red.shade700,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  /// Eliminar permanentemente un vuelo archivado
  Future<void> _permanentlyDeleteFlight(String docId) async {
    try {
      // Verificar si el widget está montado
      if (!mounted) return;

      // Mostrar indicador de progreso
      final progressDialog = ProgressDialog(
        context,
        type: ProgressDialogType.normal,
        isDismissible: false,
      );

      progressDialog.style(
        message: 'Eliminando vuelo...',
        borderRadius: 10.0,
        backgroundColor: Colors.white,
        progressWidget: const CircularProgressIndicator(),
        elevation: 10.0,
        insetAnimCurve: Curves.easeInOut,
      );

      progressDialog.show();

      print('LOG: Intentando eliminar permanentemente vuelo con ID: $docId');

      // Eliminar permanentemente el vuelo usando el ID del documento
      final wasDeleted =
          await UserFlightsService.permanentlyDeleteFlight(docId);

      // Cerrar el diálogo de progreso
      if (progressDialog.isShowing) {
        await progressDialog.hide();
      }

      // Verificar si el widget sigue montado
      if (!mounted) return;

      // Mostrar mensaje de éxito o error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            wasDeleted
                ? 'Flight permanently deleted'
                : 'Could not delete flight',
          ),
          backgroundColor:
              wasDeleted ? Colors.red.shade700 : Colors.orange.shade700,
          duration: const Duration(seconds: 2),
        ),
      );

      // Si hay una fecha seleccionada, recargar los vuelos para esa fecha
      if (_selectedDate != null) {
        await _selectDate(_selectedDate!);

        // También actualizamos la lista de fechas en caso de que esta fecha ya no tenga vuelos
        await _loadArchivedDates();
      }
    } catch (e) {
      print('LOG: Error deleting flight with document ID $docId: $e');

      // Verificar si el widget sigue montado
      if (!mounted) return;

      // Mostrar mensaje de error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting flight: $e'),
          backgroundColor: Colors.red.shade700,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // Formatear fecha para mostrar en la UI
  String _formatDate(String isoDate) {
    try {
      final date = DateTime.parse(isoDate);
      return _dateFormatter.format(date);
    } catch (e) {
      return isoDate;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Archived Flights'),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadArchivedDates,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _selectedDate == null
                  ? _buildDatesList()
                  : _buildFlightsList(),
    );
  }

  // Construir lista de fechas disponibles
  Widget _buildDatesList() {
    if (_archivedDates.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.archive_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'No archived flights found',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Contador de fechas
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${_archivedDates.length} dates with archived flights',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
              ),
            ),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadArchivedDates,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              itemCount: _archivedDates.length,
              itemBuilder: (context, index) {
                final date = _archivedDates[index];
                return ListTile(
                  title: Text(_formatDate(date.date)),
                  subtitle: Text('${date.count} flights'),
                  leading: const Icon(Icons.calendar_month, color: Colors.blue),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => _selectDate(date.date),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  // Construir lista de vuelos para la fecha seleccionada
  Widget _buildFlightsList() {
    return Column(
      children: [
        // Header con información de la fecha seleccionada
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          color: Colors.blue.shade50,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () {
                      setState(() {
                        _selectedDate = null;
                      });
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    iconSize: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Archived on ${_formatDate(_selectedDate!)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${_archivedFlights.length} flights found',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),

        // Lista de vuelos
        Expanded(
          child: _archivedFlights.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.flight_outlined,
                          size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(
                        'No flights found for this date',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _selectedDate = null;
                          });
                        },
                        child: const Text('Back to dates'),
                      ),
                    ],
                  ),
                )
              : ArchivedFlightsUI(
                  flights: _archivedFlights,
                  onRefresh: () => _selectDate(_selectedDate!),
                  onRestoreFlight: _restoreFlight,
                  onDeleteFlight: _permanentlyDeleteFlight,
                ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    // Agregar limpieza o cancelación de operaciones pendientes si es necesario
    print('LOG: Disposing ArchivedFlightsScreen');
    super.dispose();
  }
}
