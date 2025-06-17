import 'package:flutter/material.dart';
import '../../../../../l10n/app_localizations.dart';
import '../models/oversize_item_types.dart';

/// Utilidades para validaciones y diálogos relacionados con elementos sobredimensionados
class OversizeValidationUtils {
  /// Validador para el campo de cantidad
  static String? validateCountField(String? value, AppLocalizations l10n) {
    if (value == null || value.isEmpty) {
      return l10n.pleaseEnterNumber;
    }
    final count = int.tryParse(value);
    if (count == null || count <= 0) {
      return l10n.pleaseEnterValidNumber;
    }
    return null;
  }

  /// Muestra modal para detalles de manejo especial
  static Future<String?> showSpecialHandlingModal(
      BuildContext context, String currentDetails) async {
    final TextEditingController detailsController =
        TextEditingController(text: currentDetails);
    final l10n = AppLocalizations.of(context)!;

    final String? result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.specialHandlingDetails),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: detailsController,
              decoration: InputDecoration(
                labelText: l10n.enterSpecialHandlingDetails,
                hintText: l10n.specialHandlingPlaceholder,
                border: const OutlineInputBorder(),
              ),
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.of(context).pop(detailsController.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.white,
            ),
            child: Text(l10n.save),
          ),
        ],
      ),
    );

    detailsController.dispose();
    return result;
  }

  /// Diálogo de confirmación para borrar individual
  static Future<void> showDeleteConfirmation(
    BuildContext context, {
    required String docId,
    required int count,
    required OversizeItemType selectedType,
    required Function(String) onConfirm,
  }) async {
    final l10n = AppLocalizations.of(context)!;

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.confirmDeletion),
        content: Text(
            '${l10n.deleteRegistryConfirmation} $count ${OversizeItemTypeUtils.getTypeLabel(selectedType, l10n).toLowerCase()}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.cancel),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () async {
              Navigator.of(context).pop();
              onConfirm(docId);
            },
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
  }

  /// Confirmación antes de borrar todos
  static Future<bool> showDeleteAllConfirmation(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteAllRecords),
        content: Text(l10n.deleteAllRegistriesConfirmation),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.deleteAllRegistries),
          ),
        ],
      ),
    );

    return confirm ?? false;
  }
}
