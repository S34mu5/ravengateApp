import 'package:flutter/material.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../utils/logger.dart';
import '../../../../services/location/location_service.dart';
import 'models/oversize_item_types.dart';
import 'services/oversize_firebase_service.dart';
import 'services/oversize_photo_service.dart';
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

  // Método para verificar si estamos en ubicación Oversize
  Future<bool> _isOversizeLocation() async {
    try {
      return await LocationService.isOversizeLocation();
    } catch (e) {
      AppLogger.error('Error verificando ubicación oversize', e);
      return false;
    }
  }

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

  /// Enviar formulario
  Future<void> submitForm(GlobalKey<FormState> formKey) async {
    if (!formKey.currentState!.validate()) return;

    // PRIMER PROMPT: Confirmación antes de registrar
    final bool? shouldRegister = await _showRegistrationConfirmationDialog();
    if (shouldRegister != true) return;

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final int count = int.parse(countController.text);

      final List<String> registeredItemIds =
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

      // El mensaje de éxito ahora se maneja en el diálogo de confirmación de foto

      // Si estamos en ubicación Oversize, preguntar por foto
      final bool isOversize = await _isOversizeLocation();
      AppLogger.info(
          'Debug foto - mounted: $mounted, isOversize: $isOversize, registeredItemIds: ${registeredItemIds.length}');

      if (mounted && isOversize && registeredItemIds.isNotEmpty) {
        AppLogger.info('Iniciando prompt de foto...');
        await _promptForPhotoIfOversizeScreen(registeredItemIds, count);
      } else {
        AppLogger.info(
            'No se cumplieron condiciones para foto - mounted: $mounted, isOversize: $isOversize, items: ${registeredItemIds.length}');

        // Si no está en Oversize, mostrar mensaje de éxito simple
        if (mounted && !isOversize) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${AppLocalizations.of(context)!.register} completado: $count ${OversizeItemTypeUtils.getTypeLabel(selectedType, AppLocalizations.of(context)!)}',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      AppLogger.error('Error registrando elemento sobredimensionado', e);
      if (mounted) {
        setState(() {
          isLoading = false;
          errorMessage = 'Error: $e';
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
            content: Text('Error: $e'),
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
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ========== FUNCIONALIDAD DE FOTO ==========

  /// Solicita foto si estamos en ubicación oversize (SEGUNDO PROMPT)
  Future<void> _promptForPhotoIfOversizeScreen(
      List<String> itemDocumentIds, int itemCount) async {
    try {
      // SEGUNDO PROMPT: Mostrar confirmación de registro exitoso y preguntar por foto
      final bool? shouldProceedToPhoto =
          await _showRegistrationSuccessDialog(itemCount);

      if (shouldProceedToPhoto == true) {
        // TERCER PASO: Mostrar prompt de foto específico
        await OversizePhotoService.promptForPhoto(
          context: context,
          flightId: flightId,
          documentId: documentId,
          itemDocumentIds: itemDocumentIds,
          itemType: selectedType.name,
        );
      }
    } catch (e) {
      AppLogger.error('Error en proceso de foto', e);
      // No interrumpir el flujo principal por errores de foto
    }
  }

  /// PRIMER PROMPT: Confirmación antes de registrar el elemento
  Future<bool?> _showRegistrationConfirmationDialog() async {
    final int count = int.tryParse(countController.text) ?? 0;
    final String itemTypeLabel = OversizeItemTypeUtils.getTypeLabel(
        selectedType, AppLocalizations.of(context)!);

    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.assignment_add, color: Colors.amber),
            SizedBox(width: 8),
            Text('Confirmar Registro'),
          ],
        ),
        content: Text(
          'Estás a punto de registrar:\n\n'
          '📦 $count ${itemTypeLabel.toLowerCase()}(s)\n'
          '${isFragile ? '⚠️ Frágil\n' : ''}'
          '${requiresSpecialHandling ? '🔧 Manejo especial\n' : ''}'
          '\n¿Deseas proceder con el registro?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.white,
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.save, size: 18),
                SizedBox(width: 4),
                Text('Registrar'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// SEGUNDO PROMPT: Pregunta por foto después del registro exitoso
  Future<bool?> _showRegistrationSuccessDialog(int itemCount) async {
    final String itemTypeLabel = OversizeItemTypeUtils.getTypeLabel(
        selectedType, AppLocalizations.of(context)!);

    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('Registro Exitoso'),
          ],
        ),
        content: Text(
          '✅ Se han registrado $itemCount ${itemTypeLabel.toLowerCase()}(s) correctamente.\n\n'
          '¿Deseas tomar una foto de los elementos registrados?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No, continuar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.camera_alt, size: 18),
                SizedBox(width: 4),
                Text('Sí, tomar foto'),
              ],
            ),
          ),
        ],
      ),
    );
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
