import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../utils/airline_helper.dart';
import '../../utils/flight_search_helper.dart';
import '../../utils/flight_filter_util.dart';

/// Widget reutilizable que representa una tarjeta de vuelo
/// Se puede usar tanto en All Departures como en My Departures
class FlightCard extends StatelessWidget {
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
    this.selectionColor = Colors.green,
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
  Widget build(BuildContext context) {
    // Extraer información del vuelo
    final String formattedTime =
        FlightFilterUtil.extractTimeFromSchedule(flight['schedule_time']);
    final String formattedDate =
        FlightFilterUtil.extractDateFromSchedule(flight['schedule_time']);

    // Extraer hora de estado si está disponible
    final String? statusTime = flight['status_time'] != null &&
            flight['status_time'].toString().isNotEmpty
        ? FlightFilterUtil.extractTimeFromSchedule(flight['status_time'])
        : null;

    // Verificar si el vuelo está retrasado
    final bool isDelayed = statusTime != null &&
        statusTime != formattedTime &&
        FlightFilterUtil.isLaterTime(statusTime, formattedTime);

    // Verificar estados especiales
    final bool isDeparted = flight['status_code'] == 'D';
    final bool isCancelled = flight['status_code'] == 'C';

    // Color de fondo según estado
    final Color cardColor = isCancelled ? Colors.grey.shade200 : Colors.white;
    final Color textColor =
        isCancelled || isDeparted ? Colors.grey.shade700 : Colors.black87;

    // Crear el contenido de la tarjeta
    Widget cardContent = Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 1.5,
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Primera línea: ID, hora, aeropuerto, fecha
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: flight['color'],
                  radius: 18,
                  child: Text(
                    flight['airline'],
                    style: TextStyle(
                      color: AirlineHelper.getTextColorForAirline(
                          flight['airline']),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${flight['flight_id']} $formattedTime ${flight['airport']} $formattedDate',
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
                if (trailing != null) trailing!,
                if (showStatusBadges && trailing == null) ...[
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
                Text('Gate: ${flight['gate']}',
                    style: TextStyle(color: textColor)),
                // Mostrar siempre trolleys at gate (0 si no hay dato)
                Row(
                  children: [
                    const SizedBox(width: 12),
                    Icon(Icons.shopping_cart,
                        size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 2),
                    Text(
                      'Trolleys at gate: '
                      '${(flight['trolleys_at_gate'] != null && flight['trolleys_at_gate']['count'] != null) ? flight['trolleys_at_gate']['count'] : 0}',
                      style: TextStyle(
                        fontSize: 13,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
                // Empujar el badge DELAYED a la derecha
                if (isDelayed && !isCancelled) ...[
                  const Spacer(),
                  _buildStatusPill(
                      'DELAYED ${statusTime!}', Colors.amber.shade700),
                ],
              ],
            ),
          ],
        ),
      ),
    );

    // Si la tarjeta es deslizable, envolver en Dismissible
    if (isDismissible) {
      return Dismissible(
        key: Key(flight['id'] ?? flight['flight_id'] ?? 'flight'),
        direction: DismissDirection.endToStart,
        background: Container(
          color: Colors.red,
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20.0),
          child: const Icon(Icons.delete, color: Colors.white),
        ),
        confirmDismiss: confirmDismiss,
        onDismissed: onDismissed,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: cardContent,
        ),
      );
    }

    // Si no es dismissible pero tiene callbacks, envolver en InkWell
    if (onTap != null || onLongPress != null) {
      return InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
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
