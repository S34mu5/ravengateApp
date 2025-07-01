import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../services/visualization/gate_stand_service.dart';
import '../../../../utils/logger.dart';

class GateTrolleyHistory extends StatefulWidget {
  final String documentId;
  final String flightId;
  final String currentGate;
  final Function? onUpdateSuccess;

  const GateTrolleyHistory({
    required this.documentId,
    required this.flightId,
    required this.currentGate,
    this.onUpdateSuccess,
    Key? key,
  }) : super(key: key);

  @override
  State<GateTrolleyHistory> createState() => _GateTrolleyHistoryState();
}

class _GateTrolleyHistoryState extends State<GateTrolleyHistory> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoadingHistory = false;
  List<Map<String, dynamic>> _trolleyHistory = [];

  @override
  void initState() {
    AppLogger.debug('🚀 Iniciando GateTrolleyHistory.initState()', null,
        'GateTrolleyHistory');
    super.initState();
    try {
      _loadTrolleyHistory();
      AppLogger.debug(
          '✅ initState completado exitosamente', null, 'GateTrolleyHistory');
    } catch (e) {
      AppLogger.error('💥 Error en initState: $e', e, 'GateTrolleyHistory');
    }
  }

  /// Utils ---------------------------------------------------------------
  String _getTrolleyText(int count, AppLocalizations l10n) {
    return count == 1 ? l10n.trolley : '${l10n.trolley}s';
  }

  Future<String> _convertGateDisplay(String gate) async {
    return GateStandService.getDisplayValue(gate);
  }

  /// Firestore -----------------------------------------------------------
  Future<void> _loadTrolleyHistory() async {
    AppLogger.debug('🔄 Iniciando carga de historial trolleys...', null,
        'GateTrolleyHistory');
    if (_isLoadingHistory || !mounted) {
      AppLogger.debug(
          '⚠️ Evitando carga duplicada - Loading: $_isLoadingHistory, Mounted: $mounted',
          null,
          'GateTrolleyHistory');
      return;
    }

    try {
      setState(() => _isLoadingHistory = true);
      AppLogger.debug(
          '🔄 Estado de carga activado', null, 'GateTrolleyHistory');

      AppLogger.debug(
          '📡 Consultando Firestore...', null, 'GateTrolleyHistory');
      final snapshot = await _firestore
          .collection('flights')
          .doc(widget.documentId)
          .collection('trolleys')
          .orderBy('timestamp', descending: true)
          .limit(10)
          .get();

      AppLogger.debug('📊 Documentos encontrados: ${snapshot.docs.length}',
          null, 'GateTrolleyHistory');

      if (!mounted) {
        AppLogger.debug('⚠️ Widget desmontado durante consulta Firestore', null,
            'GateTrolleyHistory');
        return;
      }

      final List<Map<String, dynamic>> history = [];
      for (int i = 0; i < snapshot.docs.length; i++) {
        final doc = snapshot.docs[i];
        AppLogger.debug('📝 Procesando documento $i: ${doc.id}', null,
            'GateTrolleyHistory');

        try {
          final data = doc.data();
          AppLogger.debug(
              '📄 Doc $i data: ${data.toString()}', null, 'GateTrolleyHistory');

          final gateDisplay =
              await _convertGateDisplay(data['gate']?.toString() ?? '');
          AppLogger.debug(
              '🚪 Gate $i convertido: ${data['gate']} -> $gateDisplay',
              null,
              'GateTrolleyHistory');

          history.add({'id': doc.id, 'gate_display': gateDisplay, ...data});
          AppLogger.debug('✅ Documento $i procesado correctamente', null,
              'GateTrolleyHistory');
        } catch (e) {
          AppLogger.error(
              '💥 Error procesando documento $i: $e', e, 'GateTrolleyHistory');
          // Continúa con el siguiente documento
        }
      }

      AppLogger.debug('✅ Historial procesado: ${history.length} elementos',
          null, 'GateTrolleyHistory');

      if (!mounted) {
        AppLogger.debug('⚠️ Widget desmontado antes de setState', null,
            'GateTrolleyHistory');
        return;
      }

      setState(() {
        _trolleyHistory = history;
        _isLoadingHistory = false;
      });
      AppLogger.debug(
          '🎯 Estado actualizado exitosamente', null, 'GateTrolleyHistory');
    } catch (e) {
      AppLogger.error(
          '💥 Error en _loadTrolleyHistory: $e', e, 'GateTrolleyHistory');
      if (mounted) {
        setState(() => _isLoadingHistory = false);
        AppLogger.debug('🔄 Estado de carga desactivado tras error', null,
            'GateTrolleyHistory');
      }
    }
  }

  Future<void> _deleteAllDeliveries() async {
    try {
      final snapshot = await _firestore
          .collection('flights')
          .doc(widget.documentId)
          .collection('trolleys')
          .get();

      final docsToDelete =
          snapshot.docs.where((d) => (d.data()['deleted'] ?? false) != true);
      final batch = _firestore.batch();
      for (var doc in docsToDelete) {
        batch.set(
            doc.reference,
            {'deleted': true, 'deleted_at': FieldValue.serverTimestamp()},
            SetOptions(merge: true));
      }
      await batch.commit();
      await _loadTrolleyHistory();
      widget.onUpdateSuccess?.call();
    } catch (e) {
      AppLogger.error('Error deleting all deliveries', e);
    }
  }

  Future<void> _showDeleteAllConfirmation() async {
    final l10n = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.deleteAllDeliveries),
        content: Text(l10n.areYouSureDelete),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.cancel)),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('OK')),
        ],
      ),
    );
    if (confirm == true) _deleteAllDeliveries();
  }

  /// Muestra el modal con el mapa ampliado
  void _showMapModal(BuildContext context, Map<String, dynamic> gps,
      String gateDisplay, int count, AppLocalizations l10n) {
    final lat = gps['lat']?.toDouble() ?? 0.0;
    final lng = gps['lng']?.toDouble() ?? 0.0;
    final gpsText =
        'Lat: ${lat.toStringAsFixed(5)}, Lng: ${lng.toStringAsFixed(5)}';

    AppLogger.debug('🗺️ Abriendo modal de mapa para: $gpsText', null,
        'GateTrolleyHistory');

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.7,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                    color: Colors.blueGrey,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.location_on, color: Colors.white),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '$count ${_getTrolleyText(count, l10n)} - $gateDisplay',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                // Map
                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                    child: GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: LatLng(lat, lng),
                        zoom: 30.0, // Zoom máximo para el modal
                      ),
                      markers: {
                        Marker(
                          markerId: const MarkerId('delivery_location_modal'),
                          position: LatLng(lat, lng),
                          infoWindow: InfoWindow(
                            title: 'Delivery Location',
                            snippet:
                                '$count ${_getTrolleyText(count, l10n)} delivered',
                          ),
                        ),
                      },
                      mapType: MapType.normal,
                      zoomControlsEnabled: true,
                      scrollGesturesEnabled: true,
                      zoomGesturesEnabled: true,
                      tiltGesturesEnabled: true,
                      rotateGesturesEnabled: true,
                    ),
                  ),
                ),
                // Footer con coordenadas
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.gps_fixed,
                          size: 16, color: Colors.blueGrey),
                      const SizedBox(width: 4),
                      Text(
                        gpsText,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blueGrey.shade700,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    AppLogger.debug(
        '🎨 Iniciando build() - Loading: $_isLoadingHistory, History count: ${_trolleyHistory.length}',
        null,
        'GateTrolleyHistory');

    final l10n = AppLocalizations.of(context)!;
    AppLogger.debug(
        '🌐 Localización obtenida exitosamente', null, 'GateTrolleyHistory');

    try {
      if (_isLoadingHistory) {
        AppLogger.debug(
            '⏳ Mostrando indicador de carga', null, 'GateTrolleyHistory');
        return const Center(
            child: Padding(
                padding: EdgeInsets.all(8),
                child: CircularProgressIndicator()));
      }
      if (_trolleyHistory.isEmpty) {
        AppLogger.debug('📭 Historial vacío, mostrando mensaje', null,
            'GateTrolleyHistory');
        return Padding(
            padding: const EdgeInsets.all(8),
            child: Text(l10n.noHistoryAvailable));
      }

      AppLogger.debug(
          '📋 Construyendo lista con ${_trolleyHistory.length} elementos',
          null,
          'GateTrolleyHistory');
    } catch (e) {
      AppLogger.error(
          '💥 Error en build() - fase inicial: $e', e, 'GateTrolleyHistory');
      return Container(
        padding: const EdgeInsets.all(16),
        child: Text('Error: $e', style: const TextStyle(color: Colors.red)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(l10n.gateTrolleysHistory,
              style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        ..._trolleyHistory.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;

          AppLogger.debug('🔧 Procesando item $index: ${item.toString()}', null,
              'GateTrolleyHistory');

          final timestamp = item['timestamp'] is Timestamp
              ? (item['timestamp'] as Timestamp).toDate()
              : DateTime.now();
          final isDeleted = item['deleted'] ?? false;
          final gateDisplay = item['gate_display'] ?? item['gate'] ?? '';
          final gps = item['gps'] as Map<String, dynamic>?;

          AppLogger.debug(
              '📊 Item $index - Timestamp: $timestamp, Deleted: $isDeleted, Gate: $gateDisplay',
              null,
              'GateTrolleyHistory');

          final gpsText = gps != null
              ? 'Lat: ${gps['lat']?.toStringAsFixed(5)}, Lng: ${gps['lng']?.toStringAsFixed(5)}'
              : null;

          // Debug logs
          AppLogger.debug(
              '🗺️ Item $index GPS data: $gps', null, 'GateTrolleyHistory');
          if (gps != null) {
            final lat = gps['lat']?.toDouble() ?? 0.0;
            final lng = gps['lng']?.toDouble() ?? 0.0;
            AppLogger.debug(
                '🧭 Item $index coordenadas convertidas - Lat: $lat, Lng: $lng',
                null,
                'GateTrolleyHistory');
          }

          try {
            AppLogger.debug('🎨 Construyendo Card para item $index', null,
                'GateTrolleyHistory');

            return GestureDetector(
              onTap: gps != null
                  ? () => _showMapModal(
                      context, gps, gateDisplay, item['count'], l10n)
                  : null,
              child: Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                elevation: 1,
                child: SizedBox(
                  height: 120, // Altura fija para todas las cards
                  child: Stack(
                    children: [
                      if (gps != null)
                        Builder(builder: (context) {
                          AppLogger.debug('🚀 Intentando crear GoogleMap...',
                              null, 'GateTrolleyHistory');
                          try {
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: SizedBox(
                                height: 120,
                                child: GoogleMap(
                                  onMapCreated:
                                      (GoogleMapController controller) {
                                    final lat = gps['lat']?.toDouble() ?? 0.0;
                                    final lng = gps['lng']?.toDouble() ?? 0.0;
                                    AppLogger.debug(
                                        '✅ GoogleMap creado - Target: $lat,$lng',
                                        null,
                                        'GateTrolleyHistory');
                                  },
                                  initialCameraPosition: CameraPosition(
                                    target: LatLng(
                                        gps['lat']?.toDouble() ?? 0.0,
                                        gps['lng']?.toDouble() ?? 0.0),
                                    zoom: 20.0, // Zoom máximo para las cards
                                  ),
                                  markers: {
                                    Marker(
                                      markerId:
                                          const MarkerId('delivery_location'),
                                      position: LatLng(
                                          gps['lat']?.toDouble() ?? 0.0,
                                          gps['lng']?.toDouble() ?? 0.0),
                                      infoWindow: InfoWindow(
                                          title: 'Delivery Location',
                                          snippet: gpsText),
                                    ),
                                  },
                                  mapType: MapType.normal,
                                  zoomControlsEnabled: false,
                                  scrollGesturesEnabled: false,
                                  zoomGesturesEnabled: false,
                                  tiltGesturesEnabled: false,
                                  rotateGesturesEnabled: false,
                                ),
                              ),
                            );
                          } catch (e) {
                            AppLogger.error('💥 Error creando GoogleMap: $e', e,
                                'GateTrolleyHistory');
                            return Container(
                              height: 120,
                              decoration: BoxDecoration(
                                color: Colors.red.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Center(
                                child: Text('Error: Map failed to load',
                                    style: TextStyle(color: Colors.red)),
                              ),
                            );
                          }
                        }),
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: const BorderRadius.only(
                              bottomLeft: Radius.circular(8),
                              bottomRight: Radius.circular(8),
                            ),
                            color: gps != null
                                ? Colors.white.withValues(alpha: 0.7)
                                : Colors.white,
                          ),
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(children: [
                                Icon(Icons.shopping_cart,
                                    size: 18,
                                    color: isDeleted ? Colors.grey : null),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                      '${item['count']} ${_getTrolleyText(item['count'], l10n)} ${l10n.deliveredAtGate} $gateDisplay at ${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color: isDeleted ? Colors.grey : null,
                                          decoration: isDeleted
                                              ? TextDecoration.lineThrough
                                              : null)),
                                ),
                              ]),
                              const SizedBox(height: 4),
                              Row(children: [
                                const Icon(Icons.location_on,
                                    size: 16, color: Colors.blueGrey),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(gpsText ?? 'No GPS coordinates',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: gpsText != null
                                              ? Colors.blueGrey.shade700
                                              : Colors.grey.shade600,
                                          fontStyle: gpsText != null
                                              ? FontStyle.normal
                                              : FontStyle.italic)),
                                ),
                              ]),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          } catch (e) {
            AppLogger.error('💥 Error construyendo Card para item $index: $e',
                e, 'GateTrolleyHistory');
            return Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('Error en item $index: $e',
                  style: const TextStyle(color: Colors.red, fontSize: 12)),
            );
          }
        }).toList(),
        const SizedBox(height: 8),
        Center(
            child: TextButton.icon(
                onPressed: _showDeleteAllConfirmation,
                icon: const Icon(Icons.delete_forever, color: Colors.red),
                label: Text(l10n.deleteAllDeliveries,
                    style: const TextStyle(color: Colors.red))))
      ],
    );
  }
}
