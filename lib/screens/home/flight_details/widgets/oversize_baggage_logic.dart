import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../../l10n/app_localizations.dart';
import '../forms/models/oversize_item_types.dart';
import '../forms/services/oversize_firebase_service.dart';

/// Mixin que contiene la lógica de negocio para la visualización de equipaje sobredimensionado
mixin OversizeBaggageLogic<T extends StatefulWidget> on State<T> {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  // Estado de los conteos
  final Map<OversizeItemType, int> counts = {
    OversizeItemType.trolley: 0,
    OversizeItemType.avih: 0,
    OversizeItemType.weap: 0,
    OversizeItemType.spare: 0,
  };

  // Estado de carga y expansión
  bool isLoading = true;
  OversizeItemType? expandedType;
  List<Map<String, dynamic>> expandedItems = [];
  bool isLoadingItems = false;

  // Getters que deben ser implementados por la clase que usa este mixin
  String get documentId;
  String get flightId;
  String get currentGate;

  @override
  void initState() {
    super.initState();
    _loadCounts();
  }

  /// Carga los conteos para todos los tipos de elementos
  Future<void> _loadCounts() async {
    for (final type in OversizeItemType.values) {
      try {
        final int count = await OversizeFirebaseService.getCurrentCount(
          documentId: documentId,
          type: type,
        );
        counts[type] = count;
      } catch (e) {
        counts[type] = 0;
      }
    }
    if (mounted) {
      setState(() {
        isLoading = false;
      });
    }
  }

  /// Carga los detalles de elementos para un tipo específico
  Future<void> _loadItemDetails(OversizeItemType type) async {
    setState(() {
      isLoadingItems = true;
    });

    try {
      final List<Map<String, dynamic>> items =
          await OversizeFirebaseService.getItemHistory(
        documentId: documentId,
        type: type,
      );

      // Filtrar solo elementos no eliminados
      final List<Map<String, dynamic>> activeItems = items.where((item) {
        return !(item['deleted'] ?? false);
      }).toList();

      if (mounted) {
        setState(() {
          expandedItems = activeItems;
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

  /// Alterna la expansión de un tipo de elemento
  void toggleExpanded(OversizeItemType type) {
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

  /// Convierte spare items a trolley
  Future<void> convertSpareToTrolley() async {
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
      await _performConversion(spareCount);

      // Recargar conteos
      await _loadCounts();

      // Si hay una lista expandida, recargarla
      if (expandedType != null) {
        await _loadItemDetails(expandedType!);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.spareItemsConverted)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  /// Realiza la conversión de spare items a trolley
  Future<void> _performConversion(int spareCount) async {
    final String spareCollection =
        OversizeItemTypeUtils.collectionNameForType(OversizeItemType.spare);
    final String trolleyCollection =
        OversizeItemTypeUtils.collectionNameForType(OversizeItemType.trolley);

    final query = await firestore
        .collection('flights')
        .doc(documentId)
        .collection(spareCollection)
        .get();

    // Filtrar documentos que no estén ya eliminados
    final docsToConvert = query.docs.where((doc) {
      final data = doc.data();
      return data['deleted'] != true;
    }).toList();

    if (docsToConvert.isEmpty) {
      throw Exception(AppLocalizations.of(context)!.noSpareItemsAvailable);
    }

    final batch = firestore.batch();

    // Añadir nuevo trolley
    final trolleyDoc = firestore
        .collection('flights')
        .doc(documentId)
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
  }

  /// Recarga los datos
  Future<void> refreshData() async {
    await _loadCounts();
    if (expandedType != null) {
      await _loadItemDetails(expandedType!);
    }
  }

  /// Obtiene el nombre localizado para un tipo
  String getTypeDisplayName(OversizeItemType type) {
    final l10n = AppLocalizations.of(context)!;
    return OversizeItemTypeUtils.getTypeLabel(type, l10n);
  }

  /// Formatea una fecha y hora
  String formatDateTime(DateTime dateTime) {
    return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year} '
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  /// Procesa timestamp de Firestore
  DateTime processTimestamp(dynamic timestamp) {
    return timestamp is Timestamp ? timestamp.toDate() : DateTime.now();
  }
}
