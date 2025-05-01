import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import '../../../utils/airline_helper.dart';
import '../../../services/developer/developer_mode_service.dart';
import 'widgets/flight_header.dart';
import 'widgets/flight_status.dart';
import 'widgets/gate_history.dart';
import 'widgets/gate_trolleys.dart';
import 'utils/flight_formatters.dart';

/// Widget that displays the user interface for a specific flight details
class FlightDetailsUI extends StatefulWidget {
  final Map<String, dynamic> flightDetails;
  final List<Map<String, dynamic>> gateHistory;
  final List<Map<String, dynamic>> fullHistory;
  final Future<void> Function() onRefresh;
  final String documentId;
  final bool canSwipe; // Flag para saber si se puede hacer swipe
  final Function(DragEndDetails)? onSwipe; // Callback para el swipe
  final Function(bool)?
      onSwipeDirectionChanged; // Callback para indicar dirección del swipe
  final Map<String, dynamic>?
      adjacentFlightDetails; // Detalles del vuelo adyacente

  const FlightDetailsUI({
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

  @override
  _FlightDetailsUIState createState() => _FlightDetailsUIState();
}

class _FlightDetailsUIState extends State<FlightDetailsUI>
    with SingleTickerProviderStateMixin {
  // Añadir una variable para controlar la visibilidad de la sección de depuración
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

  // Construye un detector de gestos para detectar swipes horizontales
  Widget _buildSwipeDetector(Widget child) {
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

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> flightDetails = widget.flightDetails;
    final List<Map<String, dynamic>> gateHistory = widget.gateHistory;
    final List<Map<String, dynamic>> fullHistory = widget.fullHistory;
    final Future<void> Function() onRefresh = widget.onRefresh;
    final String documentId = widget.documentId;

    // Imprimir logs de diagnóstico
    print('LOG: FlightDetailsUI.build - canSwipe: ${widget.canSwipe}');
    print('LOG: FlightDetailsUI.build - developerMode: $_developerModeEnabled');
    print(
        'LOG: FlightDetailsUI.build - adjacentFlightDetails: ${widget.adjacentFlightDetails != null}');

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

    // Get current gate and trolley count
    final String currentGate = flightDetails['gate'] ?? '-';
    int? currentTrolleyCount;

    // Extract trolley count from flight details if available
    if (flightDetails.containsKey('trolleys_at_gate') &&
        flightDetails['trolleys_at_gate'] is Map<String, dynamic>) {
      final trolleyInfo =
          flightDetails['trolleys_at_gate'] as Map<String, dynamic>;
      if (trolleyInfo.containsKey('count')) {
        currentTrolleyCount = trolleyInfo['count'] as int?;
      }
    }

    // Contenido principal
    final Widget mainContent = SingleChildScrollView(
      controller: _scrollController ??= ScrollController(),
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header con información principal
          FlightHeader(
            flightDetails: flightDetails,
            formattedScheduleTime: formattedScheduleTime,
            formattedStatusTime: formattedStatusTime,
            isDelayed: isDelayed,
            isDeparted: isDeparted,
            isCancelled: isCancelled,
            airlineColor: airlineColor,
            documentId: documentId,
          ),

          // Información de estado
          FlightStatus(
            flightDetails: flightDetails,
            formattedScheduleTime: formattedScheduleTime,
            formattedStatusTime: formattedStatusTime,
            isDelayed: isDelayed,
            isCancelled: isCancelled,
          ),

          // Divider
          Divider(color: Colors.grey.shade300, thickness: 1),

          // Historial de cambios de puerta
          GateHistory(
            gateHistory: gateHistory,
            formattedScheduleTime: formattedScheduleTime,
          ),

          // Divider
          Divider(color: Colors.grey.shade300, thickness: 1),

          // Trolleys en puerta
          GateTrolleys(
            documentId: documentId,
            flightId: flightDetails['flight_id'] ?? '',
            currentGate: currentGate,
            currentTrolleyCount: currentTrolleyCount,
            onUpdateSuccess: onRefresh,
          ),

          // Additional flight information - solo visible en modo desarrollador
          if (_developerModeEnabled)
            Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton.icon(
                onPressed: () => _showAdditionalInfoModal(context),
                icon: const Icon(Icons.info_outline),
                label: const Text('Show Additional Information'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: airlineColor.withOpacity(0.3),
                  foregroundColor: AirlineHelper.getTextColorForAirline(
                      flightDetails['airline'] ?? ''),
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(
                      color: airlineColor,
                      width: 1.5,
                    ),
                  ),
                  elevation: 2,
                ),
              ),
            ),

          const SizedBox(height: 16),

          // Debug Information - solo visible en modo desarrollador
          if (_developerModeEnabled)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.bug_report,
                          size: 16, color: Colors.grey.shade700),
                      const SizedBox(width: 8),
                      const Text(
                        'Debug Information',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                    ],
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Document ID:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.copy, size: 16),
                              tooltip: 'Copy to clipboard',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () {
                                Clipboard.setData(
                                    ClipboardData(text: documentId));
                                // Show a snackbar to indicate the copy was successful
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content:
                                        Text('Document ID copied to clipboard'),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        SelectableText(
                          documentId,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 24),
        ],
      ),
    );

    // Envolver en RefreshIndicator
    Widget content = RefreshIndicator(
      onRefresh: onRefresh,
      child: mainContent,
    );

    // Si se puede hacer swipe, añadir el detector de gestos
    if (widget.canSwipe) {
      content = _buildSwipeDetector(content);
    }

    return content;
  }

  /// Muestra un modal con información adicional del vuelo
  void _showAdditionalInfoModal(BuildContext context) {
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
                  child: Text(
                    'Additional Flight Information',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
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
                const Text(
                  'Full History Data:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                if (widget.fullHistory.isEmpty)
                  const Text(
                    'No history data available',
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
