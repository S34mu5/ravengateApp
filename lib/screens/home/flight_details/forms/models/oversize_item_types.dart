import 'package:flutter/material.dart';
import '../../../../../l10n/app_localizations.dart';

/// Enumeración para los tipos de elementos sobredimensionados
enum OversizeItemType {
  spare(Icons.inventory),
  trolley(Icons.shopping_cart),
  avih(Icons.pets),
  weap(Icons.security);

  const OversizeItemType(this.icon);
  final IconData icon;
}

/// Utilidades para trabajar con tipos de elementos sobredimensionados
class OversizeItemTypeUtils {
  /// Obtiene el nombre de la colección correspondiente a un tipo
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

  /// Convierte string a OversizeItemType
  static OversizeItemType stringToType(String? str) {
    switch (str) {
      case 'trolley':
        return OversizeItemType.trolley;
      case 'avih':
        return OversizeItemType.avih;
      case 'weap':
        return OversizeItemType.weap;
      case 'spare':
      default:
        return OversizeItemType.spare;
    }
  }

  /// Obtiene la etiqueta localizada para un tipo
  static String getTypeLabel(OversizeItemType type, AppLocalizations l10n) {
    switch (type) {
      case OversizeItemType.trolley:
        return 'Trolley';
      case OversizeItemType.avih:
        return 'AVIH';
      case OversizeItemType.weap:
        return 'WEAP';
      case OversizeItemType.spare:
        return 'Spare Item';
    }
  }

  /// Obtiene el icono correspondiente al tipo de elemento
  static IconData getIconForType(String typeStr) {
    switch (typeStr) {
      case 'trolley':
        return Icons.shopping_cart;
      case 'spare':
        return Icons.inventory;
      case 'avih':
        return Icons.pets;
      case 'weap':
        return Icons.security;
      default:
        return Icons.local_shipping;
    }
  }

  /// Obtiene el color del icono según el estado del elemento
  static Color getIconColor(bool isConverted, bool isDeleted) {
    if (isConverted) {
      return Colors.green;
    } else if (isDeleted) {
      return Colors.grey;
    } else {
      return Colors.amber;
    }
  }
}
