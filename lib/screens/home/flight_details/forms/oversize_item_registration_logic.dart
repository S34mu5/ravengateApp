import 'package:flutter/material.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../utils/logger.dart';
import 'models/oversize_item_types.dart';
import 'services/oversize_firebase_service.dart';
import 'utils/oversize_history_utils.dart';
import 'utils/oversize_validation_utils.dart';

/// Mixin que contiene la lógica de negocio para el registro de elementos sobredimensionados
/// Ahora modularizado y mucho más pequeño
mixin OversizeItemRegistrationLogic<T extends StatefulWidget> on State<T> {
  // Controladores
  final TextEditingController countController = TextEditingController();

  // Estado del formulario
  bool isLoading = false;
  String? errorMessage;
  OversizeItemType selectedType = OversizeItemType.spare;
  bool isFragile = false;
  bool requiresSpecialHandling = false;
  String specialHandlingDetails = '';

  // Estado del historial
  bool showHistory = false;
  bool isLoadingHistory = false;
  List<Map<String, dynamic>> itemHistory = [];
  bool isDeleting = false;

  // Estado del conteo actual
  int? currentCount;
  bool isLoadingCurrentCount = false;

  // Getters que deben ser implementados por la clase que usa este mixin
  String get flightId;
  String get documentId;
  String get currentGate;
  VoidCallback get onSuccess;

  @override
  void dispose() {
    countController.dispose();
    super.dispose();
  }

  // ========== MÉTODOS DE CAMBIO DE ESTADO ==========

  /// Cambia el tipo seleccionado
  void changeSelectedType(OversizeItemType type) {
    setState(() {
      selectedType = type;
      // Recargar historial al cambiar de pestaña si ya se mostraba
      if (showHistory) {
        loadItemHistory();
      }
      // Cargar conteo actual para el nuevo tipo
      loadCurrentCount();
    });
  }

  /// Cambia el estado de frágil
  void changeFragileState(bool value) {
    setState(() {
      isFragile = value;
    });
  }

  /// Cambia el estado de manejo especial
  void changeSpecialHandlingState(bool value) {
    setState(() {
      requiresSpecialHandling = value;
      if (!value) {
        specialHandlingDetails = '';
      }
    });
  }

  /// Actualiza los detalles del manejo especial
  void updateSpecialHandlingDetails(String details) {
    setState(() {
      specialHandlingDetails = details;
      if (details.isNotEmpty) {
        requiresSpecialHandling = true;
      }
    });
  }

  // ========== OPERACIONES PRINCIPALES ==========

  /// Muestra diálogo de confirmación antes de registrar
  Future<bool> _showRegisterConfirmation(int count) async {
    final localizations = AppLocalizations.of(context)!;

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(localizations.confirmRegister),
          content: Text(
              '${localizations.pleaseConfirmRegister} $count ${getTypeLabel(selectedType, localizations)} ${localizations.forFlight} $flightId'),
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
              child: Text(localizations.confirmRegister),
            ),
          ],
        );
      },
    );

    return confirm ?? false;
  }

  /// Enviar formulario
  Future<void> submitForm(GlobalKey<FormState> formKey) async {
    if (!formKey.currentState!.validate()) return;

    final int count = int.parse(countController.text);

    // Mostrar diálogo de confirmación
    final bool confirmed = await _showRegisterConfirmation(count);
    if (!confirmed) {
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      await OversizeFirebaseService.registerItems(
        documentId: documentId,
        flightId: flightId,
        type: selectedType,
        count: count,
        isFragile: isFragile,
        requiresSpecialHandling: requiresSpecialHandling,
        specialHandlingDetails: specialHandlingDetails,
      );

      if (!mounted) return;

      setState(() {
        isLoading = false;
        countController.clear();
        isFragile = false;
        requiresSpecialHandling = false;
        specialHandlingDetails = '';
      });

      // Recargar datos
      if (showHistory) {
        loadItemHistory();
      }
      loadCurrentCount();
      onSuccess();

      // Mostrar mensaje de éxito
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${AppLocalizations.of(context)!.register} ${AppLocalizations.of(context)!.completed}: $count ${OversizeItemTypeUtils.getTypeLabel(selectedType, AppLocalizations.of(context)!)}',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      AppLogger.error('Error registrando elemento sobredimensionado', e);
      if (mounted) {
        setState(() {
          isLoading = false;
          errorMessage = '${AppLocalizations.of(context)!.errorPrefix}: $e';
        });
      }
    }
  }

  // ========== OPERACIONES DE CARGA DE DATOS ==========

  /// Carga el conteo actual para el tipo seleccionado
  Future<void> loadCurrentCount() async {
    if (isLoadingCurrentCount || !mounted) return;

    setState(() {
      isLoadingCurrentCount = true;
    });

    try {
      final int count = await OversizeFirebaseService.getCurrentCount(
        documentId: documentId,
        type: selectedType,
      );

      if (mounted) {
        setState(() {
          currentCount = count;
          isLoadingCurrentCount = false;
        });
      }
    } catch (e) {
      AppLogger.error('Error cargando conteo actual de elementos', e);
      if (mounted) {
        setState(() {
          isLoadingCurrentCount = false;
        });
      }
    }
  }

  /// Cargar historial de elementos
  Future<void> loadItemHistory() async {
    if (isLoadingHistory || !mounted) return;

    setState(() {
      isLoadingHistory = true;
    });

    try {
      final List<Map<String, dynamic>> history =
          await OversizeFirebaseService.getItemHistory(
        documentId: documentId,
        type: selectedType,
      );

      if (!mounted) return;

      setState(() {
        itemHistory = history;
        isLoadingHistory = false;
      });
    } catch (e) {
      AppLogger.error('Error cargando historial de elementos', e);
      if (mounted) {
        setState(() {
          isLoadingHistory = false;
        });
      }
    }
  }

  /// Alternar visibilidad del historial
  void toggleHistory() {
    setState(() {
      showHistory = !showHistory;
    });

    if (showHistory && itemHistory.isEmpty) {
      loadItemHistory();
    }
  }

  // ========== OPERACIONES DE ELIMINACIÓN ==========

  /// Marcar elemento como eliminado
  Future<void> markItemAsDeleted(String docId) async {
    setState(() {
      isDeleting = true;
    });

    try {
      await OversizeFirebaseService.markItemAsDeleted(
        documentId: documentId,
        type: selectedType,
        docId: docId,
      );

      if (!mounted) return;

      // Recargar datos
      await loadItemHistory();
      await loadCurrentCount();

      setState(() {
        isDeleting = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.deliveryMarkedDeleted),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      AppLogger.error('Error marcando elemento como eliminado', e);
      if (mounted) {
        setState(() {
          isDeleting = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppLocalizations.of(context)!.errorPrefix}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Eliminar todos los elementos
  Future<void> deleteAllItems() async {
    setState(() {
      isDeleting = true;
    });

    try {
      final int deletedCount = await OversizeFirebaseService.deleteAllItems(
        documentId: documentId,
        type: selectedType,
      );

      if (deletedCount == 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.noRegistriesToDelete),
              backgroundColor: Colors.orange,
            ),
          );
        }
        setState(() {
          isDeleting = false;
        });
        return;
      }

      if (!mounted) return;

      // Recargar datos
      await loadItemHistory();
      await loadCurrentCount();

      setState(() {
        isDeleting = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '$deletedCount ${AppLocalizations.of(context)!.registriesDeleted}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      AppLogger.error('Error eliminando todos los elementos', e);
      if (mounted) {
        setState(() {
          isDeleting = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppLocalizations.of(context)!.errorPrefix}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ========== MÉTODOS DE DIÁLOGOS ==========

  /// Diálogo de confirmación para borrar individual
  Future<void> showDeleteConfirmation(String docId, int count) async {
    await OversizeValidationUtils.showDeleteConfirmation(
      context,
      docId: docId,
      count: count,
      selectedType: selectedType,
      onConfirm: markItemAsDeleted,
    );
  }

  /// Confirmación antes de borrar todos
  Future<void> showDeleteAllConfirmation() async {
    final bool confirm =
        await OversizeValidationUtils.showDeleteAllConfirmation(context);
    if (confirm) {
      await deleteAllItems();
    }
  }

  /// Muestra modal para detalles de manejo especial
  Future<String?> showSpecialHandlingModal(
      BuildContext context, String currentDetails) async {
    return await OversizeValidationUtils.showSpecialHandlingModal(
        context, currentDetails);
  }

  // ========== MÉTODOS DE UTILIDAD (DELEGADOS) ==========

  /// Agrupa las conversiones y registros múltiples
  List<Map<String, dynamic>> groupItemHistory(
      List<Map<String, dynamic>> history) {
    return OversizeHistoryUtils.groupItemHistory(history);
  }

  /// Construye el título para un item del historial
  String buildItemTitle(
      Map<String, dynamic> item, String typeStr, AppLocalizations l10n) {
    return OversizeHistoryUtils.buildItemTitle(item, typeStr, l10n);
  }

  /// Construye el subtítulo para un item del historial
  String buildItemSubtitle(
      Map<String, dynamic> item, DateTime ts, AppLocalizations l10n) {
    return OversizeHistoryUtils.buildItemSubtitle(item, ts, l10n);
  }

  /// Validador para el campo de cantidad
  String? validateCountField(String? value, AppLocalizations l10n) {
    return OversizeValidationUtils.validateCountField(value, l10n);
  }

  /// Obtiene el icono correspondiente al tipo de elemento
  IconData getIconForType(String typeStr) {
    return OversizeItemTypeUtils.getIconForType(typeStr);
  }

  /// Obtiene el color del icono según el estado del elemento
  Color getIconColor(bool isConverted, bool isDeleted) {
    return OversizeItemTypeUtils.getIconColor(isConverted, isDeleted);
  }

  /// Procesa los datos del timestamp desde Firestore
  DateTime processTimestamp(dynamic timestamp) {
    return OversizeHistoryUtils.processTimestamp(timestamp);
  }

  /// Obtiene la etiqueta localizada para un tipo
  String getTypeLabel(OversizeItemType type, AppLocalizations l10n) {
    return OversizeItemTypeUtils.getTypeLabel(type, l10n);
  }

  /// Convierte string a OversizeItemType
  OversizeItemType stringToType(String? str) {
    return OversizeItemTypeUtils.stringToType(str);
  }

  /// Obtiene el nombre de la colección correspondiente a un tipo
  String collectionNameForType(OversizeItemType type) {
    return OversizeItemTypeUtils.collectionNameForType(type);
  }
}
