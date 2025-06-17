import 'package:flutter/material.dart';
import '../../../../../l10n/app_localizations.dart';
import '../forms/models/oversize_item_types.dart';
import 'oversize_baggage_logic.dart';

/// UI para la visualización de información de equipaje sobredimensionado
class OversizeBaggageUI extends StatefulWidget {
  final String documentId;
  final String flightId;
  final String currentGate;

  const OversizeBaggageUI({
    required this.documentId,
    required this.flightId,
    required this.currentGate,
    Key? key,
  }) : super(key: key);

  @override
  State<OversizeBaggageUI> createState() => _OversizeBaggageUIState();
}

class _OversizeBaggageUIState extends State<OversizeBaggageUI>
    with OversizeBaggageLogic {
  // Implementación de los getters requeridos por el mixin
  @override
  String get documentId => widget.documentId;

  @override
  String get flightId => widget.flightId;

  @override
  String get currentGate => widget.currentGate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

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
                  _buildHeader(l10n),
                  const SizedBox(height: 16),
                  _buildTypeGrid(l10n),
                  if (expandedType != null) ...[
                    const SizedBox(height: 16),
                    _buildExpandedList(l10n),
                  ],
                ],
              ),
      ),
    );
  }

  /// Construye el header
  Widget _buildHeader(AppLocalizations l10n) {
    return Text(
      l10n.currentOversizeInfo,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  /// Construye la grilla de tipos
  Widget _buildTypeGrid(AppLocalizations l10n) {
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

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: OversizeItemType.values.map((type) {
        return GestureDetector(
          onTap: () => toggleExpanded(type),
          onLongPress: type == OversizeItemType.spare
              ? () => convertSpareToTrolley()
              : null,
          child: _InfoColumn(
            icon: icons[type]!,
            label: labels[type]!,
            count: counts[type]!,
            isExpanded: expandedType == type,
          ),
        );
      }).toList(),
    );
  }

  /// Construye la lista expandida
  Widget _buildExpandedList(AppLocalizations l10n) {
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
            l10n.noHistoryAvailable,
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
              getTypeDisplayName(expandedType!),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          ...expandedItems
              .asMap()
              .entries
              .map((entry) => _buildItemRow(entry.value, entry.key + 1, l10n))
              .toList(),
        ],
      ),
    );
  }

  /// Construye una fila de elemento
  Widget _buildItemRow(
      Map<String, dynamic> item, int itemNumber, AppLocalizations l10n) {
    final timestamp = item['timestamp'];
    final DateTime date = processTimestamp(timestamp);

    final bool isFragile = item['is_fragile'] ?? false;
    final bool requiresSpecialHandling =
        item['requires_special_handling'] ?? false;
    final String specialDetails = item['special_handling_details'] ?? '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          // Número de lista
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: Text(
                '$itemNumber',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.grey.shade700,
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
                  formatDateTime(date),
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
}

/// Widget para mostrar información de cada tipo de elemento
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
