import 'package:flutter/material.dart';
import 'common_widgets.dart';

/// Widget que muestra la información de estado del vuelo
class FlightStatus extends StatelessWidget {
  final Map<String, dynamic> flightDetails;
  final String formattedScheduleTime;
  final String? formattedStatusTime;
  final bool isDelayed;
  final bool isCancelled;

  const FlightStatus({
    required this.flightDetails,
    required this.formattedScheduleTime,
    required this.formattedStatusTime,
    required this.isDelayed,
    required this.isCancelled,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.2),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            InfoRow(
              label: 'Scheduled time:',
              value: formattedScheduleTime,
              icon: Icons.schedule,
              textDecoration: isCancelled ? TextDecoration.lineThrough : null,
            ),
            if (isDelayed && !isCancelled)
              InfoRow(
                label: 'New time:',
                value: formattedStatusTime!,
                icon: Icons.timer,
                textColor: Colors.red,
              ),
            InfoRow(
              label: 'Gate:',
              value: flightDetails['gate'] ?? '-',
              icon: Icons.door_front_door,
              textDecoration: isCancelled ? TextDecoration.lineThrough : null,
            ),
          ],
        ),
      ),
    );
  }
}
