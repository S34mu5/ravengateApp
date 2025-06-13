import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../l10n/app_localizations.dart';
import '../utils/flight_formatters.dart';
import '../../../../utils/logger.dart';

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
  final ScrollController _scrollController = ScrollController();
  bool _isUpdating = false;
  String? _errorMessage;
  bool _isLoadingHistory = false;
  List<Map<String, dynamic>> _trolleyHistory = [];
  bool _showHistory = false;
  int? _currentTrolleyCount;
  bool _isLoadingCurrentCount = false;

  @override
  void initState() {
    super.initState();
    // Cargamos el conteo actual
    _loadCurrentTrolleyCount();
  }

  @override
  void dispose() {
    _trolleyController.dispose();
    _scrollController.dispose();
    super.dispose();
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
        // Solo sumamos si no está eliminado
        if (!(data['deleted'] ?? false)) {
          totalCount += (data['count'] as int? ?? 0);
        }
      }

      if (mounted) {
        setState(() {
          _currentTrolleyCount = totalCount;
          _isLoadingCurrentCount = false;
        });
      }
    } catch (e) {
      AppLogger.error('Error cargando conteo actual de trolleys', e);
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
      // Obtenemos todos los documentos
      final QuerySnapshot snapshot = await _firestore
          .collection('flights')
          .doc(widget.documentId)
          .collection('trolleys')
          .orderBy('timestamp', descending: true)
          .limit(10)
          .get();

      // Verify if widget is still mounted before updating state
      if (!mounted) return;

      // Convertimos todos los documentos a la lista de historial
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
        // Solo sumamos si no está eliminado
        if (!(history[i]['deleted'] ?? false)) {
          runningTotal += history[i]['count'] as int;
        }
        history[i]['running_total'] = runningTotal;
      }

      setState(() {
        _trolleyHistory = history;
        _isLoadingHistory = false;
        _showHistory = true;
      });
    } catch (e) {
      AppLogger.error('Error loading trolley history', e);
      if (mounted) {
        setState(() {
          _isLoadingHistory = false;
        });
      }
    }
  }

  /// Returns the correct form of trolley/trolleys based on count
  String _getTrolleyText(int count) {
    final localizations = AppLocalizations.of(context)!;
    return count == 1 ? localizations.trolley : '${localizations.trolley}s';
  }

  /// Shows confirmation dialog before marking as deleted
  Future<void> _showDeleteConfirmation(
      String docId, int count, String gate) async {
    final localizations = AppLocalizations.of(context)!;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations.confirmDeletion),
        content: Text(
            '${localizations.areYouSureDelete} $count ${_getTrolleyText(count)} ${localizations.gate.toLowerCase()}: $gate?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(localizations.cancel),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () async {
              Navigator.of(context).pop();
              await _markDeliveryAsDeleted(docId);
            },
            child: Text(localizations.delete),
          ),
        ],
      ),
    );
  }

  /// Marks a trolley delivery as deleted
  Future<void> _markDeliveryAsDeleted(String docId) async {
    final localizations = AppLocalizations.of(context)!;

    try {
      await _firestore
          .collection('flights')
          .doc(widget.documentId)
          .collection('trolleys')
          .doc(docId)
          .set(
              {
            'deleted': true,
            'deleted_at': FieldValue.serverTimestamp(),
          },
              SetOptions(
                  merge:
                      true)); // Usamos merge para no sobrescribir otros campos

      // Recargar el historial y el conteo actual
      await _loadCurrentTrolleyCount();
      if (_showHistory) {
        await _loadTrolleyHistory();
      }

      // Mostrar mensaje de éxito
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(localizations.deliveryMarkedDeleted),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Notificar al padre para actualizar la pantalla
      if (widget.onUpdateSuccess != null) {
        widget.onUpdateSuccess!();
      }
    } catch (e) {
      AppLogger.error('Error marking trolley delivery as deleted', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Shows confirmation dialog before saving
  Future<bool> _showSaveConfirmation(int count) async {
    final localizations = AppLocalizations.of(context)!;

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(localizations.confirmDelivery),
          content: Text(
              '${localizations.pleaseConfirmDelivery} $count ${_getTrolleyText(count)} en ${localizations.gate.toLowerCase()} ${widget.currentGate}'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(localizations.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: Colors.green,
              ),
              child: Text(localizations.confirmDelivery),
            ),
          ],
        );
      },
    );

    return confirm ?? false;
  }

  /// Saves trolley count to Firestore
  Future<void> _saveTrolleyCount() async {
    final localizations = AppLocalizations.of(context)!;

    // Validate it's a number
    if (_trolleyController.text.isEmpty) {
      setState(() {
        _errorMessage = localizations.pleaseEnterNumber;
      });
      return;
    }

    final int? count = int.tryParse(_trolleyController.text);
    if (count == null || count < 0) {
      setState(() {
        _errorMessage = localizations.pleaseEnterValidNumber;
      });
      return;
    }

    // Show confirmation dialog
    final bool confirmed = await _showSaveConfirmation(count);
    if (!confirmed) {
      return;
    }

    setState(() {
      _isUpdating = true;
      _errorMessage = null;
    });

    try {
      // Record in new 'trolleys' subcollection instead of 'history'
      await _firestore
          .collection('flights')
          .doc(widget.documentId)
          .collection('trolleys')
          .add({
        'timestamp': FieldValue.serverTimestamp(),
        'count': count,
        'gate': widget.currentGate,
        'flight_id': widget.flightId,
        'document_id': widget.documentId,
        'action': 'delivery',
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
        _trolleyController.clear();
      });

      // Notify parent if needed
      if (widget.onUpdateSuccess != null) {
        widget.onUpdateSuccess!();
      }
    } catch (e) {
      AppLogger.error('Error saving trolleys', e);
      if (mounted) {
        setState(() {
          _isUpdating = false;
          _errorMessage = '${localizations.errorSaving} $e';
        });
      }
    }
  }

  /// Shows confirmation dialog before deleting all deliveries
  Future<void> _showDeleteAllConfirmation() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete All Deliveries'),
          content: const Text(
            'This action should only be used in specific cases like gate changes.\n\n'
            'Are you sure you want to mark all deliveries as deleted? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text('Delete All'),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      await _deleteAllDeliveries();
    }
  }

  /// Marks all trolley deliveries as deleted
  Future<void> _deleteAllDeliveries() async {
    try {
      // Obtenemos todos los documentos y filtramos en memoria
      final QuerySnapshot snapshot = await _firestore
          .collection('flights')
          .doc(widget.documentId)
          .collection('trolleys')
          .get();

      // Filtramos los documentos que no están eliminados
      final docsToDelete = snapshot.docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return data['deleted'] !=
            true; // Consideramos eliminado solo si deleted es true
      }).toList();

      if (docsToDelete.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No deliveries to delete'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      final batch = _firestore.batch();
      for (var doc in docsToDelete) {
        batch.set(
            doc.reference,
            {
              'deleted': true,
              'deleted_at': FieldValue.serverTimestamp(),
            },
            SetOptions(
                merge: true)); // Usamos merge para no sobrescribir otros campos
      }

      await batch.commit();

      // Recargar el historial y el conteo actual
      await _loadCurrentTrolleyCount();
      if (_showHistory) {
        await _loadTrolleyHistory();
      }

      // Mostrar mensaje de éxito
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All deliveries have been marked as deleted'),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Notificar al padre para actualizar la pantalla
      if (widget.onUpdateSuccess != null) {
        widget.onUpdateSuccess!();
      }
    } catch (e) {
      AppLogger.error('Error deleting all trolley deliveries', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.all(16.0),
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
            // Section title
            Text(
              localizations.trolleysAtGate,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            // Description
            Text(
              '${localizations.registerTrolleysLeft} ${widget.currentGate}',
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
                      border: const OutlineInputBorder(),
                      errorText: _errorMessage,
                      hintText: _isLoadingCurrentCount
                          ? localizations.loading
                          : (_currentTrolleyCount != null &&
                                  _currentTrolleyCount! > 0
                              ? '${localizations.currentTrolleyCount}: $_currentTrolleyCount'
                              : localizations.enterQuantity),
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
                      : const Icon(Icons.local_shipping, size: 16),
                  label: Text(localizations.deliver),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 16),
                  ),
                ),
              ],
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
                      _showHistory
                          ? localizations.hideHistory
                          : localizations.showHistory,
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
                        ? Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(localizations.noHistoryAvailable),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8.0),
                                child: Text(
                                  localizations.gateTrolleysHistory,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              ...(_trolleyHistory.map((item) {
                                final timestamp = item['timestamp'] is Timestamp
                                    ? (item['timestamp'] as Timestamp).toDate()
                                    : DateTime.now();
                                final bool isDeleted = item['deleted'] ?? false;
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
                                            if (!isDeleted)
                                              IconButton(
                                                icon: const Icon(
                                                  Icons.delete_outline,
                                                  color: Colors.red,
                                                  size: 20,
                                                ),
                                                onPressed: () =>
                                                    _showDeleteConfirmation(
                                                  item['id'],
                                                  item['count'],
                                                  item['gate'],
                                                ),
                                                padding: EdgeInsets.zero,
                                                constraints:
                                                    const BoxConstraints(),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 8.0),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.shopping_cart,
                                              size: 18,
                                              color: isDeleted
                                                  ? Colors.grey
                                                  : null,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              '${item['count']} ${_getTrolleyText(item['count'])} ${localizations.deliveredAtGate} ${item['gate']}',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                                color: isDeleted
                                                    ? Colors.grey
                                                    : null,
                                                decoration: isDeleted
                                                    ? TextDecoration.lineThrough
                                                    : null,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList()),
                              const SizedBox(height: 16),
                              Center(
                                child: TextButton.icon(
                                  onPressed: _showDeleteAllConfirmation,
                                  icon: const Icon(Icons.delete_forever,
                                      color: Colors.red),
                                  label: Text(
                                    localizations.deleteAllDeliveries,
                                    style: const TextStyle(color: Colors.red),
                                  ),
                                ),
                              ),
                            ],
                          ),
              ),
          ],
        ),
      ),
    );
  }
}
