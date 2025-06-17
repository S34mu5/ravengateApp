import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/oversize_item_types.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../utils/flight_formatters.dart';

/// Utilidades para el procesamiento y formateo del historial de elementos sobredimensionados
class OversizeHistoryUtils {
  /// Agrupa las conversiones y registros múltiples
  static List<Map<String, dynamic>> groupItemHistory(
      List<Map<String, dynamic>> history) {
    final Map<String, List<Map<String, dynamic>>> conversionGroups = {};
    final Map<String, List<Map<String, dynamic>>> registryGroups = {};
    final List<Map<String, dynamic>> singleItems = [];

    // Agrupar items por tipo y timestamp
    for (final item in history) {
      final bool isConverted = item['converted'] ?? false;
      final String? trolleyId = item['converted_to_trolley_id'];
      final String action = item['action'] ?? '';

      if (isConverted && trolleyId != null) {
        // Agrupar conversiones por trolley_id
        conversionGroups.putIfAbsent(trolleyId, () => []).add(item);
      } else if (action == 'registry') {
        // Agrupar registros por timestamp (mismo minuto) y tipo
        final timestamp = item['timestamp'];
        final DateTime dateTime =
            timestamp is Timestamp ? timestamp.toDate() : DateTime.now();
        final String type = item['type'] ?? '';

        // Crear clave de agrupación: tipo + timestamp redondeado al minuto
        final String groupKey =
            '${type}_${dateTime.year}${dateTime.month.toString().padLeft(2, '0')}${dateTime.day.toString().padLeft(2, '0')}${dateTime.hour.toString().padLeft(2, '0')}${dateTime.minute.toString().padLeft(2, '0')}';

        registryGroups.putIfAbsent(groupKey, () => []).add(item);
      } else {
        singleItems.add(item);
      }
    }

    final List<Map<String, dynamic>> result = [];

    // Procesar registros agrupados
    registryGroups.forEach((groupKey, items) {
      if (items.length > 1) {
        // Múltiples items registrados al mismo tiempo - agrupar
        final firstItem = items.first;
        final groupedItem = Map<String, dynamic>.from(firstItem);

        groupedItem['count'] = items.length;
        groupedItem['is_grouped_registry'] = true;
        groupedItem['registry_items_count'] = items.length;

        result.add(groupedItem);
      } else {
        // Solo un item - agregar individualmente
        result.addAll(items);
      }
    });

    // Agregar items individuales (no agrupables)
    result.addAll(singleItems);

    // Crear entradas agrupadas para conversiones
    conversionGroups.forEach((trolleyId, items) {
      if (items.isNotEmpty) {
        final firstItem = items.first;
        final groupedItem = Map<String, dynamic>.from(firstItem);

        groupedItem['count'] = items.length;
        groupedItem['is_grouped_conversion'] = true;
        groupedItem['conversion_items_count'] = items.length;

        result.add(groupedItem);
      }
    });

    // Ordenar por timestamp (más recientes primero)
    result.sort((a, b) {
      final aTime = a['timestamp'] is Timestamp
          ? (a['timestamp'] as Timestamp).toDate()
          : DateTime.now();
      final bTime = b['timestamp'] is Timestamp
          ? (b['timestamp'] as Timestamp).toDate()
          : DateTime.now();
      return bTime.compareTo(aTime);
    });

    return result;
  }

  /// Construye el título para un item del historial
  static String buildItemTitle(
      Map<String, dynamic> item, String typeStr, AppLocalizations l10n) {
    final bool isConverted = item['converted'] ?? false;
    final bool isGroupedConversion = item['is_grouped_conversion'] ?? false;
    final bool isGroupedRegistry = item['is_grouped_registry'] ?? false;
    final int count = item['count'] ?? 1;

    if (isConverted) {
      if (isGroupedConversion) {
        // Conversión agrupada: "10 Spare Items → 1 Trolley"
        return '$count ${l10n.spareItem}s → 1 ${l10n.trolley}';
      } else {
        // Conversión individual (no debería mostrarse con la nueva lógica)
        return '$count ${l10n.spareItem} → 1 ${l10n.trolley}';
      }
    } else if (isGroupedRegistry) {
      // Registro agrupado: "15 Spare Items"
      final label = OversizeItemTypeUtils.getTypeLabel(
          OversizeItemTypeUtils.stringToType(typeStr), l10n);
      return count > 1 ? '$count ${label}s' : '$count $label';
    } else {
      // Item normal
      return '$count ${OversizeItemTypeUtils.getTypeLabel(OversizeItemTypeUtils.stringToType(typeStr), l10n)}';
    }
  }

  /// Construye el subtítulo para un item del historial
  static String buildItemSubtitle(
      Map<String, dynamic> item, DateTime ts, AppLocalizations l10n) {
    final bool isConverted = item['converted'] ?? false;
    final bool isGroupedConversion = item['is_grouped_conversion'] ?? false;
    final bool isGroupedRegistry = item['is_grouped_registry'] ?? false;

    if (isConverted) {
      if (isGroupedConversion) {
        // Para conversiones agrupadas, mostrar información más clara
        return '${l10n.registeredLabel}: ${_formatDateTime(ts)}\n${l10n.convertedLabel} → 1 ${l10n.trolley}';
      } else {
        return '${l10n.registeredLabel}: ${_formatDateTime(ts)}\n${l10n.convertedLabel} → 1 ${l10n.trolley}';
      }
    } else if (isGroupedRegistry) {
      // Para registros agrupados, indicar que es un registro múltiple
      final int count = item['registry_items_count'] ?? item['count'] ?? 1;
      return '${l10n.registeredLabel}: ${_formatDateTime(ts)}\n(Registro múltiple: $count elementos)';
    } else {
      return '${l10n.registeredLabel}: ${_formatDateTime(ts)}';
    }
  }

  /// Helper para formatear fecha y hora
  static String _formatDateTime(DateTime dateTime) {
    return FlightFormatters.formatDateTime(dateTime);
  }

  /// Procesa los datos del timestamp desde Firestore
  static DateTime processTimestamp(dynamic timestamp) {
    return timestamp is Timestamp ? timestamp.toDate() : DateTime.now();
  }
}
