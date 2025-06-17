import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../../l10n/app_localizations.dart';
import '../forms/oversize_item_registration_logic.dart';

/// Widget para la gestión de equipaje de gran tamaño
class OversizeBaggage extends StatefulWidget {
  final String documentId;
  final String flightId;
  final String currentGate;

  const OversizeBaggage({
    required this.documentId,
    required this.flightId,
    required this.currentGate,
    Key? key,
  }) : super(key: key);

  @override
  State<OversizeBaggage> createState() => _OversizeBaggageState();
}

class _OversizeBaggageState extends State<OversizeBaggage> {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final Map<OversizeItemType, int> counts = {
    OversizeItemType.trolley: 0,
    OversizeItemType.avih: 0,
    OversizeItemType.weap: 0,
    OversizeItemType.spare: 0,
  };
  bool isLoading = true;
  OversizeItemType? expandedType;
  List<Map<String, dynamic>> expandedItems = [];
  bool isLoadingItems = false;

  static String collectionNameForType(OversizeItemType type) {
    switch (type) {
      case OversizeItemType.trolley:
        return 'oversize_trolleys';
      case OversizeItemType.avih:
        return 'oversize_avihs';
      case OversizeItemType.weap:
        return 'oversize_weaps';
      case OversizeItemType.spare:
        return 'oversize_items';
    }
  }

  @override
  void initState() {
    super.initState();
    _loadCounts();
  }

  Future<void> _loadCounts() async {
    for (final type in OversizeItemType.values) {
      final String collectionName = collectionNameForType(type);
      final QuerySnapshot snapshot = await firestore
          .collection('flights')
          .doc(widget.documentId)
          .collection(collectionName)
          .get();
      int total = 0;
      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        if (!(data['deleted'] ?? false)) {
          total += (data['count'] as int? ?? 0);
        }
      }
      counts[type] = total;
    }
    if (mounted) {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _loadItemDetails(OversizeItemType type) async {
    setState(() {
      isLoadingItems = true;
    });

    try {
      final String collectionName = collectionNameForType(type);
      final QuerySnapshot snapshot = await firestore
          .collection('flights')
          .doc(widget.documentId)
          .collection(collectionName)
          .orderBy('timestamp', descending: true)
          .get();

      final List<Map<String, dynamic>> items = snapshot.docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return !(data['deleted'] ?? false);
      }).map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();

      if (mounted) {
        setState(() {
          expandedItems = items;
          isLoadingItems = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoadingItems = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading details: $e')),
        );
      }
    }
  }

  void _toggleExpanded(OversizeItemType type) {
    if (expandedType == type) {
      // Si ya está expandido, contraer
      setState(() {
        expandedType = null;
        expandedItems.clear();
      });
    } else {
      // Expandir nuevo tipo
      setState(() {
        expandedType = type;
      });
      _loadItemDetails(type);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final icons = {
      OversizeItemType.trolley: Icons.shopping_cart,
      OversizeItemType.avih: Icons.pets,
      OversizeItemType.weap: Icons.security,
      OversizeItemType.spare: Icons.luggage,
    };
    final labels = {
      OversizeItemType.trolley: l10n.trolley,
      OversizeItemType.avih: l10n.avih,
      OversizeItemType.weap: l10n.weap,
      OversizeItemType.spare: l10n.spareItem,
    };
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
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.currentOversizeInfo,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: OversizeItemType.values.map((type) {
                      final column = _InfoColumn(
                        icon: icons[type]!,
                        label: labels[type]!,
                        count: counts[type]!,
                        isExpanded: expandedType == type,
                      );

                      return GestureDetector(
                        onTap: () => _toggleExpanded(type),
                        onLongPress: type == OversizeItemType.spare
                            ? () => _promptConvertSpareToTrolley()
                            : null,
                        child: column,
                      );
                    }).toList(),
                  ),
                  // Mostrar lista expandida si hay un tipo seleccionado
                  if (expandedType != null) ...[
                    const SizedBox(height: 16),
                    _buildExpandedList(),
                  ],
                ],
              ),
      ),
    );
  }

  Future<void> _promptConvertSpareToTrolley() async {
    final l10n = AppLocalizations.of(context)!;
    final int spareCount = counts[OversizeItemType.spare] ?? 0;
    if (spareCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.noSpareItemsToConvert)),
      );
      return;
    }

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.convertToTrolleyTitle),
        content: Text(l10n.convertConfirmationMessage
            .replaceFirst('{count}', spareCount.toString())),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.convertAction),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final String spareCollection =
          collectionNameForType(OversizeItemType.spare);
      final String trolleyCollection =
          collectionNameForType(OversizeItemType.trolley);

      final query = await firestore
          .collection('flights')
          .doc(widget.documentId)
          .collection(spareCollection)
          .get();

      // Filtrar documentos que no estén ya eliminados
      final docsToConvert = query.docs.where((doc) {
        final data = doc.data();
        return data['deleted'] != true;
      }).toList();

      if (docsToConvert.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.noSpareItemsAvailable)),
        );
        return;
      }

      final batch = firestore.batch();

      // Añadir nuevo trolley
      final trolleyDoc = firestore
          .collection('flights')
          .doc(widget.documentId)
          .collection(trolleyCollection)
          .doc();
      batch.set(trolleyDoc, {
        'timestamp': FieldValue.serverTimestamp(),
        'count': 1,
        'action': 'convert',
        'from_spare_count': spareCount,
        'type': 'trolley',
      });

      // Marcar spare items como convertidos
      for (final doc in docsToConvert) {
        batch.update(doc.reference, {
          'deleted': true,
          'deleted_at': FieldValue.serverTimestamp(),
          'converted': true,
          'converted_at': FieldValue.serverTimestamp(),
          'converted_to_trolley_id': trolleyDoc.id,
        });
      }

      await batch.commit();

      // Recargar conteos
      await _loadCounts();

      // Si hay una lista expandida, recargarla
      if (expandedType != null) {
        await _loadItemDetails(expandedType!);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.spareItemsConverted)),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Widget _buildExpandedList() {
    if (isLoadingItems) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (expandedItems.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Center(
          child: Text(
            AppLocalizations.of(context)!.noHistoryAvailable,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              _getTypeDisplayName(expandedType!),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          ...expandedItems.map((item) => _buildItemRow(item)).toList(),
        ],
      ),
    );
  }

  Widget _buildItemRow(Map<String, dynamic> item) {
    final timestamp = item['timestamp'];
    final DateTime date =
        timestamp is Timestamp ? timestamp.toDate() : DateTime.now();

    final bool isFragile = item['is_fragile'] ?? false;
    final bool requiresSpecialHandling =
        item['requires_special_handling'] ?? false;
    final String specialDetails = item['special_handling_details'] ?? '';

    final l10n = AppLocalizations.of(context)!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          // Cantidad
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.amber.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                '${item['count'] ?? 1}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Información del item
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatDateTime(date),
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (isFragile) ...[
                      const Icon(Icons.warning, size: 16, color: Colors.orange),
                      const SizedBox(width: 4),
                      Text(
                        l10n.fragileLabel,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.orange,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (requiresSpecialHandling) ...[
                      const Icon(Icons.priority_high,
                          size: 16, color: Colors.red),
                      const SizedBox(width: 4),
                      Text(
                        l10n.requiresSpecialHandlingLabel,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.red,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
                if (specialDetails.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    specialDetails,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade700,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getTypeDisplayName(OversizeItemType type) {
    final l10n = AppLocalizations.of(context)!;
    switch (type) {
      case OversizeItemType.trolley:
        return l10n.trolley;
      case OversizeItemType.avih:
        return l10n.avih;
      case OversizeItemType.weap:
        return l10n.weap;
      case OversizeItemType.spare:
        return l10n.spareItem;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year} '
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}

class _InfoColumn extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final bool isExpanded;

  const _InfoColumn({
    required this.icon,
    required this.label,
    required this.count,
    this.isExpanded = false,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: isExpanded ? Colors.amber.shade50 : Colors.transparent,
        border: isExpanded
            ? Border.all(color: Colors.amber.shade300, width: 2)
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isExpanded ? Colors.amber.shade700 : Colors.amber,
            size: 28,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: isExpanded ? Colors.amber.shade700 : Colors.black,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isExpanded ? Colors.amber.shade700 : Colors.black,
            ),
          ),
          if (isExpanded) ...[
            const SizedBox(height: 4),
            Icon(
              Icons.keyboard_arrow_up,
              size: 16,
              color: Colors.amber.shade700,
            ),
          ],
        ],
      ),
    );
  }
}
