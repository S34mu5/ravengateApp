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
                    'Oversize Items',
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
                      );
                      // Si es Spare Item, envolvemos con GestureDetector para long press
                      if (type == OversizeItemType.spare) {
                        return GestureDetector(
                          onLongPress: () => _promptConvertSpareToTrolley(),
                          child: column,
                        );
                      }
                      return column;
                    }).toList(),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _promptConvertSpareToTrolley() async {
    final int spareCount = counts[OversizeItemType.spare] ?? 0;
    if (spareCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No spare items to convert')),
      );
      return;
    }

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Convert to trolley'),
        content: Text(
            'Do you want to convert $spareCount spare item(s) into 1 trolley?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Convert'),
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
        final data = doc.data() as Map<String, dynamic>;
        return data['deleted'] != true;
      }).toList();

      if (docsToConvert.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No spare items available')),
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

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Spare items converted to trolley')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }
}

class _InfoColumn extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;

  const _InfoColumn({
    required this.icon,
    required this.label,
    required this.count,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.amber, size: 28),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 2),
        Text(
          '$count',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
      ],
    );
  }
}
