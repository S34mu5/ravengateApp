import 'package:flutter/material.dart';
import '../../../utils/airline_helper.dart';
import '../../../services/developer/developer_mode_service.dart';
import 'utils/flight_formatters.dart';
import '../../../../utils/logger.dart';

/// Clase base abstracta que contiene la lógica común para las pantallas de detalles de vuelo
abstract class BaseFlightDetailsUI extends StatefulWidget {
  final Map<String, dynamic> flightDetails;
  final List<Map<String, dynamic>> gateHistory;
  final List<Map<String, dynamic>> fullHistory;
  final Future<void> Function() onRefresh;
  final String documentId;
  final bool canSwipe;
  final Function(DragEndDetails)? onSwipe;
  final Function(bool)? onSwipeDirectionChanged;
  final Map<String, dynamic>? adjacentFlightDetails;

  const BaseFlightDetailsUI({
    required this.flightDetails,
    required this.gateHistory,
    required this.fullHistory,
    required this.onRefresh,
    required this.documentId,
    this.canSwipe = false,
    this.onSwipe,
    this.onSwipeDirectionChanged,
    this.adjacentFlightDetails,
    super.key,
  });
}

/// Estado base abstracto que contiene la lógica común para las pantallas de detalles de vuelo
abstract class BaseFlightDetailsUIState<T extends BaseFlightDetailsUI>
    extends State<T> with SingleTickerProviderStateMixin {
  // Variable para controlar la visibilidad de la sección de depuración
  bool _developerModeEnabled = false;

  // Controlador para la animación de swipe
  late AnimationController _swipeController;
  bool _isSwipingHorizontally = false;
  ScrollController? _scrollController;

  @override
  void initState() {
    super.initState();
    _checkDeveloperMode();

    // Inicializar el controlador de animación
    _swipeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _swipeController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        // Reiniciar la animación cuando termine
        setState(() {
          _isSwipingHorizontally = false;
        });
        _swipeController.reset();
      }
    });
  }

  @override
  void dispose() {
    _swipeController.dispose();
    _scrollController?.dispose();
    super.dispose();
  }

  /// Verifica si el modo desarrollador está activado
  Future<void> _checkDeveloperMode() async {
    final isEnabled = await DeveloperModeService.isDeveloperModeEnabled();
    if (mounted) {
      setState(() {
        _developerModeEnabled = isEnabled;
      });
    }
  }

  /// Construye un detector de gestos para detectar swipes horizontales
  Widget buildSwipeDetector(Widget child) {
    if (!widget.canSwipe) {
      return child;
    }

    return GestureDetector(
      onHorizontalDragEnd: (details) {
        if (_isSwipingHorizontally && widget.onSwipe != null) {
          widget.onSwipe!(details);
        }
        setState(() {
          _isSwipingHorizontally = false;
        });
      },
      onHorizontalDragUpdate: (details) {
        // Si el gesto es lo suficientemente horizontal
        if (details.delta.dx.abs() > details.delta.dy.abs() * 2) {
          if (!_isSwipingHorizontally) {
            setState(() {
              _isSwipingHorizontally = true;
            });

            // Notificar la dirección del swipe
            if (widget.onSwipeDirectionChanged != null) {
              final bool isNext = details.delta.dx < 0;
              widget.onSwipeDirectionChanged!(isNext);
            }
          }
        }
      },
      child: child,
    );
  }

  /// Método abstracto para construir el contenido principal
  /// Cada subclase debe implementar este método
  Widget buildMainContent(
    Map<String, dynamic> flightDetails,
    List<Map<String, dynamic>> gateHistory,
    String formattedScheduleTime,
    String? formattedStatusTime,
    bool isDelayed,
    bool isDeparted,
    bool isCancelled,
    Color airlineColor,
    String currentGate,
    String documentId,
    bool developerModeEnabled,
    Future<void> Function() onRefresh,
  );

  /// Método base para mostrar un modal con información adicional del vuelo
  void showAdditionalInfoModal(BuildContext context,
      {List<Widget>? additionalSections}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(
                  child: SelectableText(
                    'Additional Flight Information',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const SelectableText(
                  'Raw Flight Data:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: SelectableText(
                    FlightFormatters.formatJsonString(widget.flightDetails),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const SelectableText(
                  'Gate History Data:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                if (widget.fullHistory.isEmpty)
                  const SelectableText(
                    'No gate history data available',
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: Colors.grey,
                    ),
                  )
                else
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: SelectableText(
                      FlightFormatters.formatJsonList(widget.fullHistory),
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),

                // Secciones adicionales que pueden ser proporcionadas por las subclases
                if (additionalSections != null) ...additionalSections,
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> flightDetails = widget.flightDetails;
    final List<Map<String, dynamic>> gateHistory = widget.gateHistory;
    final Future<void> Function() onRefresh = widget.onRefresh;

    // Imprimir logs de diagnóstico
    AppLogger.debug(
        '${widget.runtimeType}.build - canSwipe: ${widget.canSwipe}');
    AppLogger.debug(
        '${widget.runtimeType}.build - developerMode: $_developerModeEnabled');
    AppLogger.debug(
        '${widget.runtimeType}.build - adjacentFlightDetails: ${widget.adjacentFlightDetails != null}');

    // Format scheduled time
    final String formattedScheduleTime =
        FlightFormatters.formatTime(flightDetails['schedule_time'] ?? '');

    // Format status time (if exists)
    final String? formattedStatusTime = flightDetails['status_time'] != null &&
            flightDetails['status_time'].toString().isNotEmpty
        ? FlightFormatters.formatTime(flightDetails['status_time'])
        : null;

    // Check if flight is delayed
    final bool isDelayed = formattedStatusTime != null &&
        formattedStatusTime != formattedScheduleTime &&
        FlightFormatters.isLaterTime(
            formattedStatusTime, formattedScheduleTime);

    // Check if flight has departed
    final bool isDeparted = flightDetails['status_code'] == 'D';

    // Check if flight is cancelled
    final bool isCancelled = flightDetails['status_code'] == 'C';

    // Color based on airline
    final Color airlineColor =
        AirlineHelper.getAirlineColor(flightDetails['airline'] ?? '');

    // Get current gate
    final String currentGate = flightDetails['gate'] ?? '-';

    // Contenido principal - construido por la subclase
    final Widget mainContent = SingleChildScrollView(
      controller: _scrollController ??= ScrollController(),
      physics: const AlwaysScrollableScrollPhysics(),
      child: buildMainContent(
        flightDetails,
        gateHistory,
        formattedScheduleTime,
        formattedStatusTime,
        isDelayed,
        isDeparted,
        isCancelled,
        airlineColor,
        currentGate,
        widget.documentId,
        _developerModeEnabled,
        onRefresh,
      ),
    );

    // Envolver en RefreshIndicator
    Widget content = RefreshIndicator(
      onRefresh: onRefresh,
      child: mainContent,
    );

    // Si se puede hacer swipe, añadir el detector de gestos
    if (widget.canSwipe) {
      content = buildSwipeDetector(content);
    }

    return content;
  }
}
