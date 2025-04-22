import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import '../../../utils/airline_helper.dart';

/// Widget that displays the user interface for a specific flight details
class FlightDetailsUI extends StatelessWidget {
  final Map<String, dynamic> flightDetails;
  final List<Map<String, dynamic>> gateHistory;
  final Future<void> Function() onRefresh;
  final String documentId;

  const FlightDetailsUI({
    required this.flightDetails,
    required this.gateHistory,
    required this.onRefresh,
    required this.documentId,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
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

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: SingleChildScrollView(
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

            // Additional flight information
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

            // Debug Information
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
      ),
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
    // List of fields that have already been shown in the UI
    final List<String> shownFields = [
      'flight_id',
      'airline',
      'schedule_time',
      'status_time',
      'airport',
      'gate',
      'status_code',
      'gate_history'
    ];

    // Filter fields that haven't been shown yet
    final Map<String, dynamic> additionalInfo = Map.from(flightDetails)
      ..removeWhere((key, value) => shownFields.contains(key));

    // If there's no additional information, show message
    if (additionalInfo.isEmpty) {
      return const Text(
        'No additional information available.',
        style: TextStyle(
          fontStyle: FontStyle.italic,
          color: Colors.grey,
        ),
      );
    }

    // Show each additional field
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
                Text(
                  '${_formatFieldName(entry.key)}: ',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Expanded(
                  child: Text(
                    _formatFieldValue(entry.value),
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
        AirlineHelper.getAirlineColor(flightDetails['airline'] ?? '');
    final Color airlineBgColor = airlineColor.withOpacity(0.3);
    // Get airline text color
    final Color airlineTextColor =
        AirlineHelper.getTextColorForAirline(flightDetails['airline'] ?? '');

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
                          'Additional Information',
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
                // Content
                Flexible(
                  child: SingleChildScrollView(
                    child: _buildAdditionalInfo(),
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
}
