import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import '../../../utils/airline_helper.dart';
import '../../../services/developer/developer_mode_service.dart';

/// Widget that displays the user interface for a specific flight details
class FlightDetailsUI extends StatefulWidget {
  final Map<String, dynamic> flightDetails;
  final List<Map<String, dynamic>> gateHistory;
  final List<Map<String, dynamic>> fullHistory;
  final Future<void> Function() onRefresh;
  final String documentId;
  final bool canSwipe; // Flag para saber si se puede hacer swipe
  final Function(DragEndDetails)? onSwipe; // Callback para el swipe
  final Function(DragStartDetails, bool)?
      onDragStart; // Callback para el inicio del arrastre
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
    this.onDragStart,
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
  Animation<Offset>? _swipeAnimation;
  Offset _dragOffset = Offset.zero;
  bool _isDragging = false;

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
          _dragOffset = Offset.zero;
          _isDragging = false;
        });
        _swipeController.reset();
      }
    });
  }

  @override
  void dispose() {
    _swipeController.dispose();
    super.dispose();
  }

  /// Verifica si el modo desarrollador está activado
  Future<void> _checkDeveloperMode() async {
    final isEnabled = await DeveloperModeService.isDeveloperModeEnabled();
    setState(() {
      _developerModeEnabled = isEnabled;
    });
    // El modo desarrollador solo debe afectar a las secciones de depuración,
    // no a la funcionalidad principal como el swipe
  }

  // Manejar el inicio del arrastre
  void _onDragStart(DragStartDetails details) {
    setState(() {
      _isDragging = true;
    });

    // Determinar la dirección hacia la que se está arrastrando
    // Si esto aún no se puede determinar, asumimos que es un arrastre horizontal
    // La dirección real se determinará en _onDragUpdate
    if (widget.onDragStart != null) {
      // No podemos determinar la dirección exacta en el inicio, pero podemos actualizar
      // cuando tengamos más información en _onDragUpdate
      widget.onDragStart!(details, false);
    }
  }

  // Manejar el arrastre
  void _onDragUpdate(DragUpdateDetails details) {
    final bool isRightDirection = details.delta.dx > 0;

    // Si es la primera actualización y tenemos el callback, notificar la dirección
    if (_dragOffset.dx == 0 &&
        widget.onDragStart != null &&
        details.delta.dx != 0) {
      widget.onDragStart!(
          DragStartDetails(
            sourceTimeStamp: details.sourceTimeStamp,
            globalPosition: details.globalPosition,
            localPosition: details.localPosition,
          ),
          isRightDirection);
    }

    // Actualizar la posición del arrastre
    setState(() {
      _dragOffset = Offset(_dragOffset.dx + details.delta.dx, 0);
    });
  }

  // Manejar el final del arrastre
  void _onDragEnd(DragEndDetails details) {
    // Calcular velocidad para determinar si es un swipe
    final velocity = details.velocity.pixelsPerSecond.dx;

    // Si la velocidad o el desplazamiento son suficientes, considerar como swipe
    if (velocity.abs() > 500 || _dragOffset.dx.abs() > 100) {
      // Crear la animación de salida
      final targetOffset = Offset(velocity > 0 ? 1.5 : -1.5, 0);
      _swipeAnimation = Tween<Offset>(
        begin: Offset(_dragOffset.dx / MediaQuery.of(context).size.width, 0),
        end: targetOffset,
      ).animate(CurvedAnimation(
        parent: _swipeController,
        curve: Curves.easeOutCubic,
      ));

      // Iniciar la animación
      _swipeController.forward();

      // Notificar a la pantalla padre
      if (widget.onSwipe != null) {
        widget.onSwipe!(details);
      }
    } else {
      // Si no es un swipe, volver a la posición inicial
      setState(() {
        _dragOffset = Offset.zero;
        _isDragging = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> flightDetails = widget.flightDetails;
    final List<Map<String, dynamic>> gateHistory = widget.gateHistory;
    final List<Map<String, dynamic>> fullHistory = widget.fullHistory;
    final Future<void> Function() onRefresh = widget.onRefresh;
    final String documentId = widget.documentId;

    // Format scheduled time
    final String formattedScheduleTime =
        _formatTime(flightDetails['schedule_time'] ?? '');

    // Format status time (if exists)
    final String? formattedStatusTime = flightDetails['status_time'] != null &&
            flightDetails['status_time'].toString().isNotEmpty
        ? _formatTime(flightDetails['status_time'])
        : null;

    // Check if flight is delayed
    final bool isDelayed = formattedStatusTime != null &&
        formattedStatusTime != formattedScheduleTime &&
        _isLaterTime(formattedStatusTime, formattedScheduleTime);

    // Check if flight has departed
    final bool isDeparted = flightDetails['status_code'] == 'D';

    // Check if flight is cancelled
    final bool isCancelled = flightDetails['status_code'] == 'C';

    // Color based on airline
    final Color airlineColor =
        AirlineHelper.getAirlineColor(flightDetails['airline'] ?? '');

    // Contenido principal
    final Widget mainContent = SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with main flight information
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
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
                      backgroundColor: airlineColor,
                      radius: 24,
                      child: Text(
                        flightDetails['airline'] ?? '',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AirlineHelper.getTextColorForAirline(
                              flightDetails['airline'] ?? ''),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          flightDetails['flight_id'] ?? '',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Destination: ${flightDetails['airport'] ?? ''}',
                          style: const TextStyle(
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    if (isDeparted)
                      _buildStatusChip('DEPARTED', Colors.red.shade700),
                    if (isCancelled)
                      _buildStatusChip('CANCELLED', Colors.grey.shade800),
                    if (isDelayed && !isDeparted && !isCancelled)
                      _buildStatusChip('DELAYED', Colors.amber.shade700),
                  ],
                ),
                const SizedBox(height: 16),
                // Time and gate information
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      _buildInfoRow(
                        'Scheduled time:',
                        formattedScheduleTime,
                        Icons.schedule,
                        textDecoration:
                            isCancelled ? TextDecoration.lineThrough : null,
                      ),
                      if (isDelayed && !isCancelled)
                        _buildInfoRow(
                          'New time:',
                          formattedStatusTime!,
                          Icons.timer,
                          textColor: Colors.red,
                        ),
                      _buildInfoRow(
                        'Gate:',
                        flightDetails['gate'] ?? '-',
                        Icons.door_front_door,
                        textDecoration:
                            isCancelled ? TextDecoration.lineThrough : null,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Title for history section
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Gate Change History',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          // Subtitle explaining the filter
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: Colors.grey.shade600,
                ),
                children: [
                  const TextSpan(text: 'Showing changes from '),
                  TextSpan(
                    text: '2 hours before',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                  const TextSpan(text: ' scheduled departure at '),
                  TextSpan(
                    text: formattedScheduleTime,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Gate change history list
          gateHistory.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    'No gate changes recorded for this flight.',
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: Colors.grey,
                    ),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: gateHistory.length,
                  itemBuilder: (context, index) {
                    final historyItem = gateHistory[index];
                    final DateTime timestamp = historyItem['timestamp']
                            is Timestamp
                        ? (historyItem['timestamp'] as Timestamp).toDate()
                        : DateTime.parse(historyItem['timestamp'].toString());

                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      child: ListTile(
                        leading: const Icon(Icons.compare_arrows,
                            color: Colors.blue),
                        title: RichText(
                          text: TextSpan(
                            style: DefaultTextStyle.of(context).style,
                            children: [
                              const TextSpan(
                                text: 'Changed from ',
                                style: TextStyle(color: Colors.grey),
                              ),
                              TextSpan(
                                text: '${historyItem['old_gate']}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const TextSpan(
                                text: ' to ',
                                style: TextStyle(color: Colors.grey),
                              ),
                              TextSpan(
                                text: '${historyItem['new_gate']}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                            ],
                          ),
                        ),
                        subtitle: Text(_formatDateTime(timestamp)),
                      ),
                    );
                  },
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

    // Aplicar animación de swipe si está activa
    Widget content = mainContent;

    if (widget.canSwipe) {
      // Preparar el contenido del vuelo adyacente (si existe)
      Widget? adjacentContent;
      if (widget.adjacentFlightDetails != null) {
        // Crear una versión simplificada de la UI para el vuelo adyacente
        adjacentContent =
            _buildSimplifiedFlightContent(widget.adjacentFlightDetails!);
      }

      if (_swipeAnimation != null && _swipeController.isAnimating) {
        // Si hay una animación en curso, usar SlideTransition
        if (adjacentContent != null) {
          // Mostrar el vuelo adyacente debajo y el actual con animación encima
          content = Stack(
            children: [
              adjacentContent,
              SlideTransition(
                position: _swipeAnimation!,
                child: mainContent,
              ),
            ],
          );
        } else {
          // Si no hay vuelo adyacente disponible, solo mostrar la animación
          content = SlideTransition(
            position: _swipeAnimation!,
            child: mainContent,
          );
        }
      } else if (_isDragging && _dragOffset.dx.abs() > 10) {
        // Si está arrastrando (con un umbral mínimo), aplicar un Transform
        final dragPercentage =
            _dragOffset.dx / MediaQuery.of(context).size.width;
        final isRightDirection = _dragOffset.dx > 0;

        if (adjacentContent != null) {
          // Calcular la opacidad del vuelo actual basado en cuánto se ha arrastrado
          final contentOpacity =
              1.0 - (dragPercentage.abs() * 0.3).clamp(0.0, 0.3);

          // Calcular la escala del vuelo adyacente
          // Comienza al 90% y aumenta hacia el 100% a medida que se arrastra
          final adjacentScale =
              0.9 + (dragPercentage.abs() * 0.1).clamp(0.0, 0.1);

          content = Stack(
            children: [
              // Vuelo adyacente con transformación de escala
              Transform.scale(
                scale: adjacentScale,
                child: adjacentContent,
              ),
              // Vuelo actual con transformación de posición y opacidad
              Transform.translate(
                offset: Offset(_dragOffset.dx, 0),
                child: Opacity(
                  opacity: contentOpacity,
                  child: mainContent,
                ),
              ),
            ],
          );
        } else {
          // Si no hay vuelo adyacente, solo mostrar el arrastre
          content = Transform.translate(
            offset: Offset(_dragOffset.dx, 0),
            child: mainContent,
          );
        }
      }

      // Envolver el contenido en un GestureDetector para detectar el swipe
      content = GestureDetector(
        onHorizontalDragStart: _onDragStart,
        onHorizontalDragUpdate: _onDragUpdate,
        onHorizontalDragEnd: _onDragEnd,
        child: content,
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: content,
    );
  }

  /// Builds a status chip (DEPARTED, DELAYED)
  Widget _buildStatusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  /// Builds an information row with icon and text
  Widget _buildInfoRow(
    String label,
    String value,
    IconData icon, {
    Color? textColor,
    TextDecoration? textDecoration,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey),
          const SizedBox(width: 8),
          Text(
            '$label ',
            style: const TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: textColor ?? Colors.black87,
              decoration: textDecoration,
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the additional information section with all remaining fields
  Widget _buildAdditionalInfo() {
    // Mostrar todos los campos del documento de vuelo
    final Map<String, dynamic> additionalInfo = Map.from(widget.flightDetails);

    // If there's no information, show message
    if (additionalInfo.isEmpty) {
      return const Text(
        'No information available.',
        style: TextStyle(
          fontStyle: FontStyle.italic,
          color: Colors.grey,
        ),
      );
    }

    // Show each field
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: additionalInfo.entries.map((entry) {
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    '${_formatFieldName(entry.key)}: ',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    _formatFieldValue(entry.value),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  /// Formats a field name to make it more readable
  String _formatFieldName(String fieldName) {
    // Convert snake_case to Title Case
    return fieldName
        .split('_')
        .map((word) => word.isNotEmpty
            ? '${word[0].toUpperCase()}${word.substring(1)}'
            : '')
        .join(' ');
  }

  /// Formats a field value to make it more readable
  String _formatFieldValue(dynamic value) {
    if (value == null) return 'Not available';

    if (value is Timestamp) {
      return _formatDateTime(value.toDate());
    } else if (value is DateTime) {
      return _formatDateTime(value);
    } else if (value is bool) {
      return value ? 'Yes' : 'No';
    } else if (value is Map || value is List) {
      return value.toString();
    } else {
      return value.toString();
    }
  }

  /// Formats a DateTime to show date and time
  String _formatDateTime(DateTime dateTime) {
    final DateFormat formatter = DateFormat('dd/MM/yyyy HH:mm');
    // Ensure we're using local time
    return formatter.format(dateTime.toLocal());
  }

  /// Formats time from different possible formats
  String _formatTime(String timeString) {
    try {
      // If it has ISO 8601 format
      if (timeString.contains('T')) {
        final DateTime dateTime = DateTime.parse(timeString);

        // Ensure the UTC timezone is properly handled when converting to local
        // The Z at the end of the ISO string means it's UTC
        if (timeString.endsWith('Z')) {
          // Explicit UTC to local conversion
          final localDateTime = dateTime.toLocal();
          print(
              'LOG: Converting UTC time $dateTime to local time $localDateTime for flight details');
          return DateFormat('HH:mm').format(localDateTime);
        } else {
          // If no Z, it might already be local or have explicit offset
          return DateFormat('HH:mm').format(dateTime);
        }
      }
      // If it already has HH:MM format
      else if (timeString.contains(':')) {
        return timeString;
      }
      // Unknown format
      else {
        return timeString;
      }
    } catch (e) {
      print('LOG: Error formatting time: $e');
      return timeString;
    }
  }

  /// Determines if one time is later than another
  bool _isLaterTime(String time1, String time2) {
    try {
      final parts1 = time1.split(':');
      final parts2 = time2.split(':');

      if (parts1.length >= 2 && parts2.length >= 2) {
        final int hour1 = int.parse(parts1[0]);
        final int minute1 = int.parse(parts1[1]);
        final int hour2 = int.parse(parts2[0]);
        final int minute2 = int.parse(parts2[1]);

        if (hour1 > hour2) {
          return true;
        } else if (hour1 == hour2) {
          return minute1 > minute2;
        }
      }
      return false;
    } catch (e) {
      print('LOG: Error comparing times: $e');
      return false;
    }
  }

  /// Returns the color corresponding to each airline
  Color _getAirlineColor(String airline) {
    return AirlineHelper.getAirlineColor(airline);
  }

  void _showAdditionalInfoModal(BuildContext context) {
    // Get the size of available screen
    final Size screenSize = MediaQuery.of(context).size;
    // Get airline color from the same source used in build method
    final Color airlineColor =
        AirlineHelper.getAirlineColor(widget.flightDetails['airline'] ?? '');
    final Color airlineBgColor = airlineColor.withOpacity(0.3);
    // Get airline text color
    final Color airlineTextColor = AirlineHelper.getTextColorForAirline(
        widget.flightDetails['airline'] ?? '');

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 8,
          child: Container(
            width: screenSize.width * 0.9,
            constraints: BoxConstraints(
              maxHeight: screenSize.height * 0.8,
            ),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: airlineColor.withOpacity(0.5),
                width: 1.5,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: airlineBgColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: airlineColor,
                      width: 1.0,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.info, size: 16, color: airlineTextColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Complete Flight Information',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: airlineTextColor,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: airlineTextColor),
                        onPressed: () => Navigator.of(context).pop(),
                        tooltip: 'Close',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Tabs para navegar entre las diferentes secciones
                DefaultTabController(
                  length: 2,
                  child: Column(
                    children: [
                      TabBar(
                        tabs: const [
                          Tab(text: 'Flight Data'),
                          Tab(text: 'History Collection'),
                        ],
                        labelColor: airlineColor,
                        indicatorColor: airlineColor,
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: screenSize.height * 0.5,
                        child: TabBarView(
                          children: [
                            // Primera pestaña: Información del vuelo
                            SingleChildScrollView(
                              child: _buildAdditionalInfo(),
                            ),

                            // Segunda pestaña: Historial completo
                            SingleChildScrollView(
                              child: _buildHistoryInfo(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Footer
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade600,
                      foregroundColor: Colors.white,
                      elevation: 2,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      minimumSize: const Size(80, 36),
                    ),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Builds the history collection information
  Widget _buildHistoryInfo() {
    // Agregar log para depuración
    print(
        'LOG DEBUG: Building history info with ${widget.fullHistory.length} records');

    if (widget.fullHistory.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'No history records found for this flight.',
            style: TextStyle(
              fontStyle: FontStyle.italic,
              color: Colors.grey,
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text(
            'History Collection: ${widget.fullHistory.length} records',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
        ...widget.fullHistory.map((record) {
          // Verificar que record es un Map no nulo
          if (record == null) {
            print('LOG ERROR: Found null record in history');
            return const SizedBox
                .shrink(); // No mostrar nada para registros nulos
          }

          // Añadir log para cada registro procesado
          print(
              'LOG DEBUG: Processing history record with ID: ${record['id']} and keys: ${record.keys.toList()}');

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: ExpansionTile(
              title: Text(
                'Record ID: ${record['id'] ?? 'Unknown'}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              subtitle: _buildHistoryRecordSubtitle(record),
              children: [
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: record.entries
                        .where((entry) =>
                            entry.key !=
                            'id') // Omitir el ID que ya se muestra en el título
                        .map((entry) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 2,
                              child: Text(
                                '${_formatFieldName(entry.key)}: ',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(
                                _formatFieldValue(entry.value),
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  /// Construye el subtítulo para un registro de historial de forma segura
  Widget _buildHistoryRecordSubtitle(Map<String, dynamic> record) {
    try {
      // Si tiene change_time, mostrar la marca de tiempo
      if (record.containsKey('change_time') && record['change_time'] != null) {
        final timestamp = record['change_time'];
        String formattedTime;

        if (timestamp is Timestamp) {
          formattedTime = _formatDateTime(timestamp.toDate());
        } else if (timestamp is String) {
          try {
            formattedTime = _formatDateTime(DateTime.parse(timestamp));
          } catch (e) {
            print('LOG ERROR: Could not parse timestamp string: $timestamp');
            formattedTime = timestamp;
          }
        } else {
          formattedTime = timestamp.toString();
        }

        return Text(
          'Timestamp: $formattedTime',
          style: const TextStyle(fontSize: 12),
        );
      }

      // Si tiene old_gate y new_gate, mostrar el cambio
      else if (record.containsKey('old_gate') &&
          record.containsKey('new_gate')) {
        return Text(
          'Gate change: ${record['old_gate']} → ${record['new_gate']}',
          style: const TextStyle(fontSize: 12),
        );
      }

      // Si no tiene ninguno de los anteriores pero tiene campos, mostrar alguna info útil
      else if (record.isNotEmpty) {
        // Buscar algún campo relevante para mostrar
        final keys = record.keys.where((k) => k != 'id').toList();
        if (keys.isNotEmpty) {
          final key = keys.first;
          return Text(
            '$key: ${_formatFieldValue(record[key])}',
            style: const TextStyle(fontSize: 12),
            overflow: TextOverflow.ellipsis,
          );
        }
      }

      // Si no se cumple ninguna condición anterior
      return const Text(
        'No details available',
        style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
      );
    } catch (e) {
      print('LOG ERROR: Error building history record subtitle: $e');
      return Text(
        'Error: $e',
        style: const TextStyle(fontSize: 12, color: Colors.red),
      );
    }
  }

  /// Construye una versión simplificada del contenido del vuelo para mostrar como fondo
  Widget _buildSimplifiedFlightContent(Map<String, dynamic> flightData) {
    // Formateo de datos básicos
    final String formattedScheduleTime =
        _formatTime(flightData['schedule_time'] ?? '');
    final String? formattedStatusTime = flightData['status_time'] != null &&
            flightData['status_time'].toString().isNotEmpty
        ? _formatTime(flightData['status_time'])
        : null;

    // Determinar estados del vuelo
    final bool isDelayed = formattedStatusTime != null &&
        formattedStatusTime != formattedScheduleTime &&
        _isLaterTime(formattedStatusTime, formattedScheduleTime);
    final bool isDeparted = flightData['status_code'] == 'D';
    final bool isCancelled = flightData['status_code'] == 'C';

    // Color basado en la aerolínea
    final Color airlineColor =
        AirlineHelper.getAirlineColor(flightData['airline'] ?? '');

    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header con información principal del vuelo
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Fila con número de vuelo, aerolínea y estado
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: airlineColor,
                      radius: 24,
                      child: Text(
                        flightData['airline'] ?? '',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AirlineHelper.getTextColorForAirline(
                              flightData['airline'] ?? ''),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          flightData['flight_id'] ?? '',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Destination: ${flightData['airport'] ?? ''}',
                          style: const TextStyle(
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    if (isDeparted)
                      _buildStatusChip('DEPARTED', Colors.red.shade700),
                    if (isCancelled)
                      _buildStatusChip('CANCELLED', Colors.grey.shade800),
                    if (isDelayed && !isDeparted && !isCancelled)
                      _buildStatusChip('DELAYED', Colors.amber.shade700),
                  ],
                ),
                const SizedBox(height: 16),
                // Información de tiempo y puerta
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      _buildInfoRow(
                        'Scheduled time:',
                        formattedScheduleTime,
                        Icons.schedule,
                        textDecoration:
                            isCancelled ? TextDecoration.lineThrough : null,
                      ),
                      if (isDelayed && !isCancelled)
                        _buildInfoRow(
                          'New time:',
                          formattedStatusTime!,
                          Icons.timer,
                          textColor: Colors.red,
                        ),
                      _buildInfoRow(
                        'Gate:',
                        flightData['gate'] ?? '-',
                        Icons.door_front_door,
                        textDecoration:
                            isCancelled ? TextDecoration.lineThrough : null,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Mostrar un espacio en blanco en lugar del historial de cambios
          const SizedBox(height: 500),
        ],
      ),
    );
  }
}
