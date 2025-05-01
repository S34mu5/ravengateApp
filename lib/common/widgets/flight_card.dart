import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../utils/airline_helper.dart';
import '../../utils/flight_search_helper.dart';

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
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    // Extraer información del vuelo
    final String formattedTime =
        _extractTimeFromSchedule(flight['schedule_time']);
    final String formattedDate =
        _extractDateFromSchedule(flight['schedule_time']);

    // Extraer hora de estado si está disponible
    final String? statusTime = flight['status_time'] != null &&
            flight['status_time'].toString().isNotEmpty
        ? _extractTimeFromSchedule(flight['status_time'])
        : null;

    // Verificar si el vuelo está retrasado
    final bool isDelayed = statusTime != null &&
        statusTime != formattedTime &&
        _isLaterTime(statusTime, formattedTime);

    // Verificar estados especiales
    final bool isDeparted = flight['status_code'] == 'D';
    final bool isCancelled = flight['status_code'] == 'C';

    // Crear el contenido de la tarjeta
    Widget cardContent = Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        children: [
          ListTile(
            leading: isSelectionMode
                ? Checkbox(
                    value: isSelected,
                    onChanged: onSelectionToggle,
                    activeColor: selectionColor,
                  )
                : CircleAvatar(
                    backgroundColor: flight['color'],
                    child: Text(
                      flight['airline'],
                      style: TextStyle(
                        color: AirlineHelper.getTextColorForAirline(
                            flight['airline']),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
            title: Text(
              '${flight['flight_id']} - $formattedTime ${flight['airport']} - $formattedDate',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDeparted || isCancelled ? Colors.grey : Colors.black,
                decoration: isDeparted || isCancelled
                    ? TextDecoration.lineThrough
                    : null,
              ),
            ),
            subtitle: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Gate: ${flight['gate']}'),
                    if (flight['trolleys_at_gate'] != null &&
                        flight['trolleys_at_gate']['count'] != null)
                      Text(
                        'Trolleys at gate: ${flight['trolleys_at_gate']['count']}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      ),
                  ],
                ),
                if (isDelayed && !isCancelled) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade700,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'DELAYED',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          statusTime!,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            trailing: isSelectionMode
                ? null
                : trailing ?? const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: onTap,
            onLongPress: onLongPress,
          ),
          // Banner para vuelos salidos
          if (isDeparted)
            Positioned(
              right: 0,
              left: 0,
              top: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(4),
                child: Banner(
                  message: 'DEPARTED',
                  location: BannerLocation.topEnd,
                  color: Colors.red.shade700,
                  textStyle: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          // Banner para vuelos cancelados
          if (isCancelled)
            Positioned(
              right: 0,
              left: 0,
              top: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(4),
                child: Banner(
                  message: 'CANCELLED',
                  location: BannerLocation.topEnd,
                  color: Colors.grey.shade800,
                  textStyle: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
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
        child: cardContent,
      );
    }

    return cardContent;
  }

  /// Extrae la hora del formato ISO 8601 o del formato tradicional "HH:MM"
  String _extractTimeFromSchedule(String scheduleTime) {
    try {
      // Verificar si está en formato ISO 8601 (contiene una 'T')
      if (scheduleTime.contains('T')) {
        // Intentar analizar como ISO 8601
        final dateTime = DateTime.parse(scheduleTime);

        // Crear formateador para mostrar solo hora
        final formatter = DateFormat('HH:mm');

        // Convertir a hora local y formatear
        // Asegurar que la zona horaria UTC se maneje correctamente al convertir a local
        if (scheduleTime.endsWith('Z')) {
          // Conversión explícita de UTC a local
          final localDateTime = dateTime.toLocal();
          return formatter.format(localDateTime);
        } else {
          // Si no hay Z, puede que ya sea local o tenga un desplazamiento explícito
          return formatter.format(dateTime);
        }
      } else if (scheduleTime.contains(':')) {
        // Si es solo un formato de hora "HH:MM", devolverlo directamente
        return scheduleTime;
      } else {
        return scheduleTime; // Formato desconocido, devolver el original
      }
    } catch (e) {
      print('LOG: Error formatando hora: $e');
      return scheduleTime; // Devolver cadena original si hay error
    }
  }

  /// Extrae la fecha del formato ISO 8601 y la formatea como dd/MM
  String _extractDateFromSchedule(String scheduleTime) {
    try {
      // Verificar si está en formato ISO 8601 (contiene una 'T')
      if (scheduleTime.contains('T')) {
        // Intentar analizar como ISO 8601
        final dateTime = DateTime.parse(scheduleTime);

        // Crear formateador para mostrar solo fecha en formato dd/MM
        final formatter = DateFormat('dd/MM');

        // Convertir a hora local y formatear
        if (scheduleTime.endsWith('Z')) {
          // Conversión explícita de UTC a local
          final localDateTime = dateTime.toLocal();
          return formatter.format(localDateTime);
        } else {
          // Si no hay Z, puede que ya sea local o tenga desplazamiento explícito
          return formatter.format(dateTime);
        }
      } else {
        // Si es solo un formato de hora, usar fecha actual
        final now = DateTime.now();
        return DateFormat('dd/MM').format(now);
      }
    } catch (e) {
      print('LOG: Error extrayendo fecha: $e');
      return ''; // Devolver cadena vacía en caso de error
    }
  }

  /// Compara dos tiempos en formato HH:MM para determinar si el primero es posterior al segundo
  bool _isLaterTime(String time1, String time2) {
    try {
      // Convertir al formato actual de tiempo
      final parts1 = time1.split(':');
      final parts2 = time2.split(':');

      if (parts1.length >= 2 && parts2.length >= 2) {
        final hour1 = int.parse(parts1[0]);
        final minute1 = int.parse(parts1[1]);
        final hour2 = int.parse(parts2[0]);
        final minute2 = int.parse(parts2[1]);

        // Comparar horas y minutos
        if (hour1 > hour2) {
          return true;
        } else if (hour1 == hour2) {
          return minute1 > minute2;
        }
      }
      return false;
    } catch (e) {
      print('LOG: Error comparando tiempos: $e');
      return false;
    }
  }
}
