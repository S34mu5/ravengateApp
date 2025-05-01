import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/flight_formatters.dart';

/// Widget that allows the operator to register the number of trolleys left at the gate
class GateTrolleys extends StatefulWidget {
  final String documentId;
  final String flightId;
  final String currentGate;
  final Function? onUpdateSuccess;

  const GateTrolleys({
    required this.documentId,
    required this.flightId,
    required this.currentGate,
    this.onUpdateSuccess,
    Key? key,
  }) : super(key: key);

  @override
  State<GateTrolleys> createState() => _GateTrolleysState();
}

class _GateTrolleysState extends State<GateTrolleys> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _trolleyController = TextEditingController();
  bool _isUpdating = false;
  String? _errorMessage;
  bool _showSuccess = false;
  bool _isLoadingHistory = false;
  List<Map<String, dynamic>> _trolleyHistory = [];
  bool _showHistory = false;
  int? _currentTrolleyCount;
  bool _isLoadingCurrentCount = false;
  // Timer to hide success message
  Future<void>? _hideSuccessTimer;

  @override
  void initState() {
    super.initState();
    // Cargamos el conteo actual
    _loadCurrentTrolleyCount();
  }

  @override
  void dispose() {
    _trolleyController.dispose();
    // Cancel any pending timers
    _cancelTimers();
    super.dispose();
  }

  /// Cancels any pending timers
  void _cancelTimers() {
    _hideSuccessTimer = null;
  }

  /// Carga el conteo actual de trolleys calculado de la subcolección
  Future<void> _loadCurrentTrolleyCount() async {
    setState(() {
      _isLoadingCurrentCount = true;
    });

    try {
      final QuerySnapshot snapshot = await _firestore
          .collection('flights')
          .doc(widget.documentId)
          .collection('trolleys')
          .get();

      int totalCount = 0;
      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        totalCount += (data['count'] as int? ?? 0);
      }

      if (mounted) {
        setState(() {
          _currentTrolleyCount = totalCount;
          _isLoadingCurrentCount = false;

          // Inicializamos el campo con el total actual
          if (totalCount > 0) {
            _trolleyController.text = totalCount.toString();
          }
        });
      }
    } catch (e) {
      debugPrint('Error cargando conteo actual de trolleys: $e');
      if (mounted) {
        setState(() {
          _isLoadingCurrentCount = false;
        });
      }
    }
  }

  /// Loads trolley history
  Future<void> _loadTrolleyHistory() async {
    if (_isLoadingHistory || !mounted) return;

    setState(() {
      _isLoadingHistory = true;
    });

    try {
      final QuerySnapshot snapshot = await _firestore
          .collection('flights')
          .doc(widget.documentId)
          .collection('trolleys')
          .orderBy('timestamp', descending: true)
          .limit(10)
          .get();

      // Verify if widget is still mounted before updating state
      if (!mounted) return;

      final List<Map<String, dynamic>> history = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();

      // Calculate running total for each entry
      int runningTotal = 0;
      for (int i = history.length - 1; i >= 0; i--) {
        runningTotal += history[i]['count'] as int;
        history[i]['running_total'] = runningTotal;
      }

      setState(() {
        _trolleyHistory = history;
        _isLoadingHistory = false;
        _showHistory = true;
      });
    } catch (e) {
      debugPrint('Error loading trolley history: $e');
      if (mounted) {
        setState(() {
          _isLoadingHistory = false;
        });
      }
    }
  }

  /// Saves trolley count to Firestore
  Future<void> _saveTrolleyCount() async {
    // Validate it's a number
    if (_trolleyController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a number';
      });
      return;
    }

    final int? count = int.tryParse(_trolleyController.text);
    if (count == null || count < 0) {
      setState(() {
        _errorMessage = 'Please enter a valid number';
      });
      return;
    }

    // Check if value has changed
    if (_currentTrolleyCount == count) {
      setState(() {
        _showSuccess = true;
        _errorMessage = null;
      });

      // Cancel any previous timer
      _cancelTimers();

      // Hide message after 3 seconds
      _hideSuccessTimer = Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _showSuccess = false;
          });
        }
      });

      return;
    }

    setState(() {
      _isUpdating = true;
      _errorMessage = null;
      _showSuccess = false;
    });

    try {
      // Record in new 'trolleys' subcollection instead of 'history'
      await _firestore
          .collection('flights')
          .doc(widget.documentId)
          .collection('trolleys') // Use 'trolleys' instead of 'history'
          .add({
        'timestamp': FieldValue.serverTimestamp(),
        'count': count,
        'gate': widget.currentGate,
        'flight_id': widget.flightId,
        'action': 'update',
      });

      // Verify if widget is still mounted before continuing
      if (!mounted) return;

      // Actualizamos el conteo actual
      await _loadCurrentTrolleyCount();

      // After saving, load updated history if visible
      if (_showHistory) {
        _loadTrolleyHistory();
      }

      setState(() {
        _isUpdating = false;
        _showSuccess = true;
      });

      // Notify parent if needed
      if (widget.onUpdateSuccess != null) {
        widget.onUpdateSuccess!();
      }

      // Cancel any previous timer
      _cancelTimers();

      // Hide success message after 3 seconds
      _hideSuccessTimer = Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _showSuccess = false;
          });
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUpdating = false;
          _errorMessage = 'Error saving: $e';
        });
      }
      debugPrint('Error saving trolleys: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section title
          const Text(
            'Trolleys at Gate',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 8),

          // Description
          Text(
            'Register the number of trolleys left at gate ${widget.currentGate}',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),

          const SizedBox(height: 16),

          // Input field and button
          Row(
            children: [
              // Text field for quantity
              Expanded(
                child: TextField(
                  controller: _trolleyController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Quantity',
                    border: const OutlineInputBorder(),
                    errorText: _errorMessage,
                    hintText: _isLoadingCurrentCount
                        ? 'Cargando...'
                        : (_currentTrolleyCount != null &&
                                _currentTrolleyCount! > 0
                            ? 'Current: $_currentTrolleyCount'
                            : 'Ex: 3'),
                    prefixIcon: const Icon(Icons.shopping_cart),
                  ),
                ),
              ),

              const SizedBox(width: 16),

              // Save button (smaller)
              ElevatedButton.icon(
                onPressed: _isUpdating ? null : _saveTrolleyCount,
                icon: _isUpdating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.save, size: 16),
                label: const Text('Save'),
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                ),
              ),
            ],
          ),

          // Success message
          if (_showSuccess)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Row(
                children: [
                  Icon(Icons.check_circle,
                      color: Colors.green.shade600, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Trolleys successfully registered',
                    style: TextStyle(
                      color: Colors.green.shade600,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

          // Button to show/hide history
          Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: InkWell(
              onTap: () {
                setState(() {
                  _showHistory = !_showHistory;
                });
                if (_showHistory && _trolleyHistory.isEmpty) {
                  _loadTrolleyHistory();
                }
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _showHistory
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 16,
                    color: Colors.blue,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _showHistory ? 'Hide history' : 'Show history',
                    style: const TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Trolley history
          if (_showHistory)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: _isLoadingHistory
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(8.0),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : _trolleyHistory.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Text('No history available'),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8.0),
                              child: Text(
                                'Gate Trolleys History',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            ...(_trolleyHistory.map((item) {
                              final timestamp = item['timestamp'] is Timestamp
                                  ? (item['timestamp'] as Timestamp).toDate()
                                  : DateTime.now();
                              return Card(
                                margin:
                                    const EdgeInsets.symmetric(vertical: 4.0),
                                elevation: 1,
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            FlightFormatters.formatDateTime(
                                                timestamp),
                                            style: TextStyle(
                                              color: Colors.grey.shade600,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8.0),
                                      Row(
                                        children: [
                                          const Icon(Icons.shopping_cart,
                                              size: 18),
                                          const SizedBox(width: 8),
                                          Text(
                                            '${item['count']} trolleys at gate ${item['gate']}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6.0),
                                      Row(
                                        children: [
                                          const Icon(Icons.add_circle_outline,
                                              size: 18, color: Colors.blue),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Total: ${item['running_total']} trolleys',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w500,
                                              fontSize: 14,
                                              color: Colors.blue.shade800,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList()),
                          ],
                        ),
            ),
        ],
      ),
    );
  }
}
