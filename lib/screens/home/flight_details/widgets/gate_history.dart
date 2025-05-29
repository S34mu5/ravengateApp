import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/flight_formatters.dart';
import '../../../../l10n/app_localizations.dart';

/// Widget que muestra el historial de cambios de puerta del vuelo
class GateHistory extends StatelessWidget {
  final List<Map<String, dynamic>> gateHistory;
  final String formattedScheduleTime;

  const GateHistory({
    required this.gateHistory,
    required this.formattedScheduleTime,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Título y explicación del filtro
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  localizations.gateChangeHistory,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: Colors.grey.shade600,
                    ),
                    children: [
                      TextSpan(text: '${localizations.showingChangesFrom} '),
                      TextSpan(
                        text: localizations.twoHoursBefore,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                      ),
                      TextSpan(text: ' ${localizations.scheduledDepartureAt} '),
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
              ],
            ),

            const SizedBox(height: 8),

            // Lista de cambios
            gateHistory.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      localizations.noGateChangesRecorded,
                      style: const TextStyle(
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
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          leading: const Icon(Icons.compare_arrows,
                              color: Colors.blue),
                          title: RichText(
                            text: TextSpan(
                              style: DefaultTextStyle.of(context).style,
                              children: [
                                TextSpan(
                                  text: '${localizations.changedFrom} ',
                                  style: const TextStyle(color: Colors.grey),
                                ),
                                TextSpan(
                                  text: '${historyItem['old_gate']}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                TextSpan(
                                  text: ' ${localizations.to} ',
                                  style: const TextStyle(color: Colors.grey),
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
                          subtitle:
                              Text(FlightFormatters.formatDateTime(timestamp)),
                        ),
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }
}
