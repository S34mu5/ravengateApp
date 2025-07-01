import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../services/visualization/gate_stand_service.dart';
import '../../../../utils/logger.dart';
import '../../../../services/location/location_service.dart';
import 'gate_trolley_history.dart';

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
  bool _showHistory = false;
  int? _currentTrolleyCount;
  bool _isLoadingCurrentCount = false;
  String _gateDisplay = '';
  String _gateTitle = '';

  @override
  void initState() {
    super.initState();
    // Cargamos el conteo actual y el display de la gate
    _loadCurrentTrolleyCount();
    _loadGateDisplay();
  }

  @override
  void dispose() {
    _trolleyController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Carga el display apropiado para la gate/stand
  Future<void> _loadGateDisplay() async {
    final gate = widget.currentGate;
    if (gate.isNotEmpty && gate != '-') {
      final display = await GateStandService.getDisplayValue(gate);
      if (mounted) {
        setState(() {
          _gateDisplay = display;
          // Determinar el título apropiado
          _gateTitle = display.startsWith('Stand') ? 'Stand' : 'Gate';
        });
      }
    } else {
      setState(() {
        _gateDisplay = gate.isEmpty ? '-' : gate;
        _gateTitle = 'Gate';
      });
    }
  }

  /// Convierte una gate individual a su display apropiado
  Future<String> _convertGateDisplay(String gate) async {
    final display = await GateStandService.getDisplayValue(gate);
    // Para mostrar en el historial, usamos el formato completo
    return display;
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

  /// Loads trolley history with gate/stand conversion
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
      final List<Map<String, dynamic>> history = [];

      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final String gate = data['gate']?.toString() ?? '';
        final String gateDisplay = await _convertGateDisplay(gate);

        history.add({
          'id': doc.id,
          'gate_display': gateDisplay,
          ...data,
        });
      }

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

  /// Shows confirmation dialog before saving
  Future<bool> _showSaveConfirmation(int count) async {
    final localizations = AppLocalizations.of(context)!;

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(localizations.confirmDelivery),
          content: Text(
              '${localizations.pleaseConfirmDelivery} $count ${_getTrolleyText(count)} en $_gateDisplay'),
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
      // Intentar obtener coordenadas GPS
      double? latitude;
      double? longitude;
      double? accuracy;
      try {
        final position = await LocationService.getCurrentPosition();
        if (position != null) {
          latitude = position.latitude;
          longitude = position.longitude;
          accuracy = position.accuracy;
        }
      } catch (e) {
        // Si falla el GPS, registramos en logs pero no interrumpimos la entrega
        AppLogger.warning('No se pudo obtener posición GPS: $e');
      }

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
        if (latitude != null && longitude != null)
          'gps': {
            'lat': latitude,
            'lng': longitude,
            if (accuracy != null) 'accuracy': accuracy,
          },
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
              color: Colors.grey.withValues(alpha: 0.2),
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
              '${localizations.trolleysAtGate}${_gateTitle == 'Stand' ? ' Stand' : ''}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            // Description
            Text(
              _gateTitle == 'Stand'
                  ? 'Register trolleys left at $_gateDisplay'
                  : '${localizations.registerTrolleysLeft} $_gateDisplay',
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
                child: GateTrolleyHistory(
                  documentId: widget.documentId,
                  flightId: widget.flightId,
                  currentGate: widget.currentGate,
                  onUpdateSuccess: widget.onUpdateSuccess,
                ),
              ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}
