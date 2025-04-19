import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'flight_details_ui.dart';

/// Component that handles the logic and data for the flight details screen
/// Gets detailed data of a specific flight from Firestore
class FlightDetailsScreen extends StatefulWidget {
  final String flightId;
  final String documentId;

  const FlightDetailsScreen(
      {required this.flightId, required this.documentId, super.key});

  @override
  State<FlightDetailsScreen> createState() => _FlightDetailsScreenState();
}

class _FlightDetailsScreenState extends State<FlightDetailsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Map<String, dynamic>? _flightDetails;
  List<Map<String, dynamic>> _gateHistory = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadFlightDetails();
  }

  /// Loads the complete flight details from Firestore
  Future<void> _loadFlightDetails() async {
    print('LOG: Loading flight details for ${widget.flightId}...');

    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // Get the flight document using its ID
      final DocumentSnapshot flightDoc =
          await _firestore.collection('flights').doc(widget.documentId).get();

      if (!flightDoc.exists) {
        print('LOG: Flight with ID ${widget.documentId} not found');
        setState(() {
          _errorMessage = 'No data found for this flight';
          _isLoading = false;
        });
        return;
      }

      // Convert data to Map
      final Map<String, dynamic> flightData =
          flightDoc.data() as Map<String, dynamic>;

      // Load gate change history from the 'history' subcollection
      List<Map<String, dynamic>> gateHistory = [];

      try {
        // Query the 'history' subcollection of this flight document
        final QuerySnapshot historySnapshot = await _firestore
            .collection('flights')
            .doc(widget.documentId)
            .collection('history')
            .orderBy('change_time', descending: true)
            .get();

        // Process each history document
        if (historySnapshot.docs.isNotEmpty) {
          gateHistory = historySnapshot.docs.map((historyDoc) {
            final data = historyDoc.data() as Map<String, dynamic>;

            // Format the data to a consistent structure
            return {
              'id': historyDoc.id,
              'timestamp': data[
                  'change_time'], // Keep original timestamp for sorting and display
              'new_gate': data['new_gate'] ?? '-',
              'old_gate': data['old_gate'] ?? '-',
            };
          }).toList();
        }

        print('LOG: Loaded ${gateHistory.length} gate history records');
      } catch (historyError) {
        print('LOG: Error loading history subcollection: $historyError');
        // Continue with main data even if history fails to load
      }

      // Assign values for the UI
      setState(() {
        _flightDetails = flightData;
        _gateHistory = gateHistory;
        _isLoading = false;
      });

      print('LOG: Flight details loaded successfully');
      print('LOG: Gate change history: ${_gateHistory.length} records');
    } catch (e) {
      print('LOG: Error loading flight details: $e');
      setState(() {
        _errorMessage = 'Error loading details: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Flight ${widget.flightId}'),
            Text(
              'ID: ${widget.documentId}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadFlightDetails,
            tooltip: 'Refresh data',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadFlightDetails,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : FlightDetailsUI(
                  flightDetails: _flightDetails!,
                  gateHistory: _gateHistory,
                  onRefresh: _loadFlightDetails,
                  documentId: widget.documentId,
                ),
    );
  }
}
