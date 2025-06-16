import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../utils/airline_helper.dart';
import '../../../../utils/flight_filter_util.dart';
import '../../../../l10n/app_localizations.dart';
import 'common_widgets.dart';
import '../../../../utils/logger.dart';

/// Widget que muestra el encabezado con información básica del vuelo
class FlightHeader extends StatefulWidget {
  final Map<String, dynamic> flightDetails;
  final String formattedScheduleTime;
  final String? formattedStatusTime;
  final bool isDelayed;
  final bool isDeparted;
  final bool isCancelled;
  final Color airlineColor;
  final String documentId;

  const FlightHeader({
    required this.flightDetails,
    required this.formattedScheduleTime,
    required this.formattedStatusTime,
    required this.isDelayed,
    required this.isDeparted,
    required this.isCancelled,
    required this.airlineColor,
    required this.documentId,
    Key? key,
  }) : super(key: key);

  @override
  State<FlightHeader> createState() => _FlightHeaderState();
}

class _FlightHeaderState extends State<FlightHeader> {
  int? _totalTrolleys;
  bool _isLoadingTrolleys = false;
  String? _errorMessage;
  String _selectedLocation = 'Bins'; // Valor por defecto
  bool _isLocationLoaded = false; // Flag para evitar parpadeo

  @override
  void initState() {
    super.initState();
    // Iniciamos con valor por defecto
    _totalTrolleys = 0;
    _loadSelectedLocation();
    _loadTotalTrolleys();
  }

  /// Carga la ubicación seleccionada desde SharedPreferences
  Future<void> _loadSelectedLocation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final location = prefs.getString('selected_location') ?? 'Bins';
      setState(() {
        _selectedLocation = location;
        _isLocationLoaded = true; // Marcamos como cargado
      });
    } catch (e) {
      AppLogger.error('FlightHeader - Error al cargar la ubicación', e);
      setState(() {
        _isLocationLoaded = true; // Marcamos como cargado incluso con error
      });
    }
  }

  /// Obtiene el color de fondo según la ubicación
  Color _getBackgroundColor() {
    return _selectedLocation == 'Bins'
        ? Colors.blue.shade50 // Azul claro para Bins
        : Colors.amber.shade50; // Amarillo claro para Oversize
  }

  /// Carga el total acumulado de trolleys
  Future<void> _loadTotalTrolleys() async {
    // Mostrar todos los campos disponibles en flightDetails para depuración
    AppLogger.debug(
        'FlightDetails disponibles: ${widget.flightDetails.keys.join(', ')}');

    // Usamos directamente el documentId del widget, como en GateTrolleys
    final String documentId = widget.documentId;
    AppLogger.debug('DocumentId usado: $documentId');

    if (documentId.isEmpty) {
      setState(() {
        _errorMessage = 'DocumentId vacío';
        _isLoadingTrolleys = false;
      });
      AppLogger.debug('Error: DocumentId vacío');
      return;
    }

    setState(() {
      _isLoadingTrolleys = true;
    });

    try {
      // Verificamos la colección
      final flightDoc =
          FirebaseFirestore.instance.collection('flights').doc(documentId);
      AppLogger.debug('Ruta del documento de vuelo: ${flightDoc.path}');

      // Primero verificamos si el documento existe
      final docSnapshot = await flightDoc.get();
      if (!docSnapshot.exists) {
        AppLogger.warning(
            'ALERTA: El documento de vuelo no existe en la ruta: ${flightDoc.path}');
        setState(() {
          _errorMessage = 'Documento de vuelo no encontrado';
          _isLoadingTrolleys = false;
        });
        return;
      }

      AppLogger.debug('Documento de vuelo encontrado, buscando trolleys...');

      // Ahora obtenemos la colección trolleys
      final trolleysCollection = flightDoc.collection('trolleys');
      AppLogger.debug('Ruta de colección trolleys: ${trolleysCollection.path}');

      final QuerySnapshot snapshot = await trolleysCollection.get();

      if (!mounted) return;

      AppLogger.debug(
          'Documentos encontrados en trolleys: ${snapshot.docs.length}');

      // Si no hay documentos, mostramos un mensaje claro
      if (snapshot.docs.isEmpty) {
        AppLogger.warning(
            'IMPORTANTE: No se encontraron documentos en la colección trolleys');
        setState(() {
          _totalTrolleys = 0;
          _isLoadingTrolleys = false;
        });
        return;
      }

      int totalCount = 0;
      // Imprimimos cada documento para verificar
      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        AppLogger.debug('Documento completo: $data');

        // Verificar si contiene el campo count
        if (!data.containsKey('count')) {
          AppLogger.warning(
              'ALERTA: Documento ${doc.id} no contiene campo count');
          continue;
        }

        // Solo sumamos si no está eliminado
        if (!(data['deleted'] ?? false)) {
          final int countValue = data['count'] as int? ?? 0;
          AppLogger.debug('Documento trolley: ID=${doc.id}, count=$countValue');
          totalCount += countValue;
        }
      }

      AppLogger.debug('Total de trolleys calculado: $totalCount');

      setState(() {
        _totalTrolleys = totalCount;
        _errorMessage = null;
        _isLoadingTrolleys = false;
      });
    } catch (e) {
      AppLogger.error('Error cargando total de trolleys', e);
      if (mounted) {
        setState(() {
          _errorMessage = 'Error: $e';
          _isLoadingTrolleys = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    // Mostrar un contenedor mínimo hasta cargar la ubicación
    if (!_isLocationLoaded) {
      return Container(
        width: double.infinity,
        height: 120, // Altura mínima para evitar saltos
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade100, // Color neutro mientras carga
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
        ),
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _getBackgroundColor(),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row with flight number, airline and status
          Row(
            children: [
              CircleAvatar(
                backgroundColor: widget.airlineColor,
                radius: 24,
                child: Text(
                  widget.flightDetails['airline'] ?? '',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AirlineHelper.getTextColorForAirline(
                        widget.flightDetails['airline'] ?? ''),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${widget.flightDetails['flight_id'] ?? ''} ${FlightFilterUtil.extractDateFromSchedule(widget.flightDetails['schedule_time'] ?? DateTime.now().toIso8601String())}',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${localizations.destinationLabel}: ${widget.flightDetails['airport'] ?? ''}',
                    style: const TextStyle(
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              if (widget.isDeparted)
                StatusChip(
                    text: localizations.departedUpper, color: Colors.red),
              if (widget.isCancelled)
                StatusChip(
                    text: localizations.cancelledUpper, color: Colors.black),
              if (widget.isDelayed && !widget.isDeparted && !widget.isCancelled)
                StatusChip(
                    text: localizations.delayedUpper,
                    color: Colors.amber.shade700),
            ],
          ),

          const SizedBox(height: 16),

          // Flight details section - Gate, scheduled time, etc.
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              InfoColumn(
                icon: Icons.schedule,
                title: localizations.scheduledTime,
                value: widget.formattedScheduleTime,
                valueColor: widget.isDelayed ? Colors.grey : null,
                valueDecoration:
                    widget.isDelayed ? TextDecoration.lineThrough : null,
              ),
              InfoColumn(
                icon: Icons.door_front_door,
                title: localizations.gate,
                value: widget.flightDetails['gate'] ?? '-',
              ),
              if (_isLoadingTrolleys)
                InfoColumn(
                  icon: Icons.shopping_cart,
                  title: localizations.trolleysAtGate,
                  value: '...',
                ),
              if (!_isLoadingTrolleys)
                InfoColumn(
                  icon: Icons.shopping_cart,
                  title: localizations.trolleysAtGate,
                  value: _totalTrolleys?.toString() ?? '0',
                  valueColor: _errorMessage != null
                      ? Colors.red.shade300
                      : (_totalTrolleys != null && _totalTrolleys! > 0
                          ? Colors.blue.shade700
                          : Colors.grey),
                  valueFontWeight: FontWeight.bold,
                ),
              if (widget.isDelayed && widget.formattedStatusTime != null)
                InfoColumn(
                  icon: Icons.update,
                  title: localizations.newTime,
                  value: widget.formattedStatusTime!,
                  valueColor: Colors.amber.shade700,
                  valueFontWeight: FontWeight.bold,
                ),
            ],
          ),

          // Mensaje de error si existe
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                _errorMessage!,
                style: TextStyle(
                  color: Colors.red.shade700,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Widget that displays information in a column format with icon
class InfoColumn extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color? valueColor;
  final FontWeight? valueFontWeight;
  final TextDecoration? valueDecoration;

  const InfoColumn({
    required this.icon,
    required this.title,
    required this.value,
    this.valueColor,
    this.valueFontWeight,
    this.valueDecoration,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Colors.blue.shade800),
        const SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: valueFontWeight ?? FontWeight.w500,
            color: valueColor,
            decoration: valueDecoration,
          ),
        ),
      ],
    );
  }
}
