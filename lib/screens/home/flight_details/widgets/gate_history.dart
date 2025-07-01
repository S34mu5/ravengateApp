import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/flight_formatters.dart';
import '../../../../services/visualization/gate_stand_service.dart';
import '../../../../l10n/app_localizations.dart';

/// Widget que muestra el historial de cambios de puerta del vuelo
class GateHistory extends StatefulWidget {
  final List<Map<String, dynamic>> gateHistory;
  final String formattedScheduleTime;

  const GateHistory({
    required this.gateHistory,
    required this.formattedScheduleTime,
    super.key,
  });

  @override
  State<GateHistory> createState() => _GateHistoryState();
}

class _GateHistoryState extends State<GateHistory> {
  List<Map<String, dynamic>> _convertedHistory = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _convertGateHistory();
  }

  /// Convierte el historial de gates a su representación apropiada (gate o stand)
  Future<void> _convertGateHistory() async {
    List<Map<String, dynamic>> converted = [];

    for (final historyItem in widget.gateHistory) {
      final String oldGate = historyItem['old_gate']?.toString() ?? '';
      final String newGate = historyItem['new_gate']?.toString() ?? '';

      final String oldDisplay = await GateStandService.getDisplayValue(oldGate);
      final String newDisplay = await GateStandService.getDisplayValue(newGate);

      // Para el historial, solo mostramos el número sin "Stand"
      final String oldFinalDisplay = oldDisplay.startsWith('Stand ')
          ? oldDisplay.replaceFirst('Stand ', '')
          : oldDisplay;
      final String newFinalDisplay = newDisplay.startsWith('Stand ')
          ? newDisplay.replaceFirst('Stand ', '')
          : newDisplay;

      converted.add({
        ...historyItem,
        'old_gate_display': oldFinalDisplay,
        'new_gate_display': newFinalDisplay,
      });
    }

    if (mounted) {
      setState(() {
        _convertedHistory = converted;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        width: double.infinity,
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
                        text: widget.formattedScheduleTime,
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

            // Indicador de carga
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            // Lista de cambios
            else if (_convertedHistory.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  localizations.noGateChangesRecorded,
                  style: const TextStyle(
                    fontStyle: FontStyle.italic,
                    color: Colors.grey,
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _convertedHistory.length,
                itemBuilder: (context, index) {
                  final historyItem = _convertedHistory[index];
                  final DateTime timestamp =
                      historyItem['timestamp'] is Timestamp
                          ? (historyItem['timestamp'] as Timestamp).toDate()
                          : DateTime.parse(historyItem['timestamp'].toString());

                  final String oldDisplay = historyItem['old_gate_display'] ??
                      historyItem['old_gate'] ??
                      '';
                  final String newDisplay = historyItem['new_gate_display'] ??
                      historyItem['new_gate'] ??
                      '';

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      leading:
                          const Icon(Icons.compare_arrows, color: Colors.blue),
                      title: RichText(
                        text: TextSpan(
                          style: DefaultTextStyle.of(context).style,
                          children: [
                            TextSpan(
                              text: '${localizations.changedFrom} ',
                              style: const TextStyle(color: Colors.grey),
                            ),
                            TextSpan(
                              text: oldDisplay,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            TextSpan(
                              text: ' ${localizations.to} ',
                              style: const TextStyle(color: Colors.grey),
                            ),
                            TextSpan(
                              text: newDisplay,
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
