import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../utils/airline_helper.dart';
import '../../utils/flight_search_helper.dart';
import '../../utils/flight_filter_util.dart';
import '../../screens/home/flight_details/utils/flight_formatters.dart';

/// Widget reutilizable que representa una tarjeta de vuelo
/// Se puede usar tanto en All Departures como en My Departures
class FlightCard extends StatefulWidget {
  /// Datos del vuelo a mostrar
  final Map<String, dynamic> flight;

  /// Determina si la tarjeta está en modo selección
  final bool isSelectionMode;

  /// Determina si la tarjeta está seleccionada (para modo selección)
  final bool isSelected;

  /// Determina si la tarjeta se puede deslizar para eliminar
  final bool isDismissible;

  /// Color del checkbox de selección
  final Color selectionColor;

  /// Callback cuando se toca la tarjeta
  final VoidCallback? onTap;

  /// Callback cuando se mantiene presionada la tarjeta
  final VoidCallback? onLongPress;

  /// Callback cuando se cambia el estado de selección (para modo selección)
  final Function(bool?)? onSelectionToggle;

  /// Callback para confirmar eliminación (para tarjetas dismissibles)
  final Future<bool> Function(DismissDirection)? confirmDismiss;

  /// Callback cuando se elimina la tarjeta (para tarjetas dismissibles)
  final Function(DismissDirection)? onDismissed;

  /// Widget personalizado para mostrar en la parte derecha de la tarjeta
  final Widget? trailing;

  /// Determina si se muestran los badges de estado
  final bool showStatusBadges;

  const FlightCard({
    required this.flight,
    this.isSelectionMode = false,
    this.isSelected = false,
    this.isDismissible = false,
    this.selectionColor = const Color(0xFF4285F4), // Google Blue por defecto
    this.onTap,
    this.onLongPress,
    this.onSelectionToggle,
    this.confirmDismiss,
    this.onDismissed,
    this.trailing,
    this.showStatusBadges = true,
    super.key,
  });

  @override
  State<FlightCard> createState() => _FlightCardState();
}

class _FlightCardState extends State<FlightCard> {
  int _trolleyCount = 0;
  bool _isLoadingTrolleys = false;

  @override
  void initState() {
    super.initState();
    _loadTrolleyCount();
  }

  /// Carga el conteo actual de trolleys calculado de la subcolección
  Future<void> _loadTrolleyCount() async {
    // Verificamos que tengamos el ID del documento
    if (widget.flight['id'] == null) return;

    setState(() {
      _isLoadingTrolleys = true;
    });

    try {
      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      final QuerySnapshot snapshot = await firestore
          .collection('flights')
          .doc(widget.flight['id'])
          .collection('trolleys')
          .get();

      int totalCount = 0;
      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        // Solo sumamos si no está eliminado
        if (!(data['deleted'] ?? false)) {
          totalCount += (data['count'] as int? ?? 0);
        }
      }

      if (mounted) {
        setState(() {
          _trolleyCount = totalCount;
          _isLoadingTrolleys = false;
        });
      }
    } catch (e) {
      debugPrint('Error cargando conteo de trolleys en FlightCard: $e');
      if (mounted) {
        setState(() {
          _isLoadingTrolleys = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Extraer información del vuelo
    final String formattedTime =
        FlightFormatters.formatTime(widget.flight['schedule_time']);
    final String formattedDate = FlightFilterUtil.extractDateFromSchedule(
        widget.flight['schedule_time']);

    // Extraer hora de estado si está disponible
    final String? statusTime = widget.flight['status_time'] != null &&
            widget.flight['status_time'].toString().isNotEmpty
        ? FlightFormatters.formatTime(widget.flight['status_time'])
        : null;

    // Verificar si el vuelo está retrasado
    final bool isDelayed = statusTime != null &&
        statusTime != formattedTime &&
        FlightFilterUtil.isLaterTime(statusTime, formattedTime);

    // Verificar si el vuelo despegó antes de tiempo o a su hora programada
    final bool isOnTimeOrEarly = widget.flight['status_code'] == 'D' &&
        statusTime != null &&
        (!FlightFilterUtil.isLaterTime(statusTime, formattedTime) ||
            statusTime == formattedTime);

    // Verificar estados especiales
    final bool isDeparted = widget.flight['status_code'] == 'D';
    final bool isCancelled = widget.flight['status_code'] == 'C';

    // Verificar si el vuelo está retrasado pero aún no ha despegado
    final bool isDelayedNotDeparted = statusTime != null &&
        statusTime != formattedTime &&
        FlightFilterUtil.isLaterTime(statusTime, formattedTime) &&
        !isDeparted;

    // Verificar si el vuelo despegó a tiempo o temprano
    final bool isOnTimeOrEarlyDeparture = isDeparted &&
        statusTime != null &&
        (!FlightFilterUtil.isLaterTime(statusTime, formattedTime) ||
            statusTime == formattedTime);

    // Verificar si el vuelo despegó tarde
    final bool isDelayedDeparture = isDeparted &&
        statusTime != null &&
        FlightFilterUtil.isLaterTime(statusTime, formattedTime);

    // Color de fondo según estado
    final Color cardColor = isCancelled
        ? Colors.grey.shade200
        : widget.isSelectionMode && widget.isSelected
            ? const Color(0xFF4285F4)
                .withOpacity(0.05) // Google Blue con muy baja opacidad
            : Colors.white;
    final Color textColor =
        isCancelled || isDeparted ? Colors.grey.shade700 : Colors.black87;

    // Crear el contenido de la tarjeta
    Widget cardContent = Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: widget.isSelectionMode && widget.isSelected ? 2.5 : 1.5,
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: widget.isSelectionMode && widget.isSelected
            ? const BorderSide(
                color: Color(0xFF4285F4), width: 2) // Google Blue
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Primera línea: ID, hora, aeropuerto, fecha
            Row(
              children: [
                if (widget.isSelectionMode)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Icon(
                      widget.isSelected
                          ? Icons.check_circle
                          : Icons.circle_outlined,
                      color: widget.isSelected
                          ? const Color(0xFF4285F4)
                          : Colors
                              .grey.shade400, // Google Blue cuando seleccionado
                      size: 24,
                    ),
                  ),
                CircleAvatar(
                  backgroundColor: widget.flight['color'],
                  radius: 18,
                  child: Text(
                    widget.flight['airline'],
                    style: TextStyle(
                      color: AirlineHelper.getTextColorForAirline(
                          widget.flight['airline']),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${widget.flight['flight_id']} $formattedTime ${widget.flight['airport']} $formattedDate',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: textColor,
                      decoration: isDeparted || isCancelled
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                ),
                if (widget.trailing != null) widget.trailing!,
                if (widget.showStatusBadges && widget.trailing == null) ...[
                  if (isDeparted)
                    _buildStatusPill('DEPARTED', Colors.red.shade700),
                  if (isCancelled)
                    _buildStatusPill('CANCELLED', Colors.grey.shade800),
                ],
              ],
            ),
            const SizedBox(height: 10),
            // Segunda línea: Gate y trolleys
            Row(
              children: [
                Icon(Icons.meeting_room, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text('Gate: ${widget.flight['gate']}',
                    style: TextStyle(color: textColor)),
                // Mostrar siempre trolleys at gate con el contador actualizado
                Row(
                  children: [
                    const SizedBox(width: 12),
                    Icon(Icons.shopping_cart,
                        size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 2),
                    _isLoadingTrolleys
                        ? const SizedBox(
                            width: 10,
                            height: 10,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            'Trolleys at gate: $_trolleyCount',
                            style: TextStyle(
                              fontSize: 13,
                              color: textColor,
                            ),
                          ),
                  ],
                ),
                // Empujar los badges a la derecha
                const Spacer(),
                // Mostrar badge según corresponda
                if (isDelayedNotDeparted && !isCancelled)
                  _buildStatusPill(
                      'DELAYED ${statusTime!}', Colors.amber.shade700)
                else if (isOnTimeOrEarlyDeparture)
                  _buildStatusPill(
                      'DEPARTED ${statusTime!}', Colors.green.shade700)
                else if (isDelayedDeparture)
                  _buildStatusPill(
                      'DEPARTED ${statusTime!}', Colors.amber.shade700),
              ],
            ),
          ],
        ),
      ),
    );

    // Si la tarjeta es deslizable, envolver en Dismissible
    if (widget.isDismissible) {
      return Dismissible(
        key: Key(widget.flight['id'] ?? widget.flight['flight_id'] ?? 'flight'),
        direction: DismissDirection.endToStart,
        background: Container(
          color: Colors.red,
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20.0),
          child: const Icon(Icons.delete, color: Colors.white),
        ),
        confirmDismiss: widget.confirmDismiss,
        onDismissed: widget.onDismissed,
        child: InkWell(
          onTap: widget.onTap,
          onLongPress: widget.onLongPress,
          child: cardContent,
        ),
      );
    }

    // Si no es dismissible pero tiene callbacks, envolver en InkWell
    if (widget.onTap != null || widget.onLongPress != null) {
      return InkWell(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: cardContent,
      );
    }

    return cardContent;
  }

  // Widget para los estados tipo pill
  Widget _buildStatusPill(String text, Color color) {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
