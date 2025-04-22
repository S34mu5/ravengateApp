import 'package:flutter/material.dart';
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
  List<Map<String, dynamic>> _archivedFlights = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadArchivedFlights();
  }

  /// Cargar los vuelos archivados por el usuario
  Future<void> _loadArchivedFlights() async {
    print('LOG: Cargando datos de vuelos archivados en ArchivedFlightsScreen');

    try {
      // Verificar si el widget está montado antes de actualizar estado
      if (!mounted) return;

      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // Obtener vuelos archivados desde el servicio
      final archivedFlights = await UserFlightsService.getUserArchivedFlights();

      // Verificar nuevamente si el widget sigue montado
      if (!mounted) return;

      setState(() {
        _archivedFlights = archivedFlights;
        _isLoading = false;
      });

      print('LOG: Se cargaron ${_archivedFlights.length} vuelos archivados');
    } catch (e) {
      print('LOG: Error al cargar vuelos archivados: $e');

      // Verificar si el widget sigue montado antes de actualizar estado de error
      if (!mounted) return;

      setState(() {
        _errorMessage = 'Error loading archived flights: $e';
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

      // Recargar la lista de vuelos archivados
      await _loadArchivedFlights();
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

      // Recargar la lista de todos modos
      _loadArchivedFlights();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Archived Flights'),
        backgroundColor: Colors.blue.shade100,
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
                        onPressed: _loadArchivedFlights,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadArchivedFlights,
                  child: ArchivedFlightsUI(
                    flights: _archivedFlights,
                    onRefresh: _loadArchivedFlights,
                    onRestoreFlight: _restoreFlight,
                  ),
                ),
    );
  }

  @override
  void dispose() {
    // Agregar limpieza o cancelación de operaciones pendientes si es necesario
    print('LOG: Disposing ArchivedFlightsScreen');
    super.dispose();
  }
}
