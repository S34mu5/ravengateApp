import 'package:flutter/material.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../utils/logger.dart';
import 'models/oversize_item_types.dart';
import 'services/oversize_firebase_service.dart';
import 'utils/oversize_history_utils.dart';
import 'utils/oversize_validation_utils.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:typed_data';
import '../../../../services/photos/firebase_photo_service.dart';
import '../../../../services/photos/photo_service.dart';

/// Mixin que contiene la lógica de negocio para el registro de elementos sobredimensionados
/// Ahora modularizado y mucho más pequeño
mixin OversizeItemRegistrationLogic<T extends StatefulWidget> on State<T> {
  // Controladores
  final TextEditingController countController = TextEditingController();

  // Estado del formulario
  bool isLoading = false;
  String? errorMessage;
  OversizeItemType selectedType = OversizeItemType.spare;

  // Estado del historial
  bool showHistory = false;
  bool isLoadingHistory = false;
  List<Map<String, dynamic>> itemHistory = [];
  bool isDeleting = false;

  // Estado del conteo actual
  int? currentCount;
  bool isLoadingCurrentCount = false;

  // NUEVO: Estado para fotos
  bool showPhotoSection = false;
  List<String> pendingPhotosBase64 = []; // Fotos temporales antes del registro
  bool isUploadingPhotos = false;
  String? photoError;

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
    if (!mounted) return;

    setState(() {
      selectedType = type;
    });

    // Recargar historial al cambiar de pestaña si ya se mostraba
    if (showHistory) {
      loadItemHistory();
    }
    // Cargar conteo actual para el nuevo tipo
    loadCurrentCount();
  }

  // Métodos de frágil y manejo especial removidos temporalmente

  // ========== NUEVOS MÉTODOS PARA FOTOS ==========

  /// Alternar visibilidad de la sección de fotos
  void togglePhotoSection() {
    if (!mounted) return;

    setState(() {
      showPhotoSection = !showPhotoSection;
    });
  }

  /// Agregar foto pendiente (temporal)
  void addPendingPhoto(String photoBase64) {
    if (!mounted) return;

    setState(() {
      pendingPhotosBase64.add(photoBase64);
      photoError = null;
    });
    AppLogger.info(
        'Foto pendiente agregada', {'totalPhotos': pendingPhotosBase64.length});
  }

  /// Remover foto pendiente
  void removePendingPhoto(String photoBase64) {
    if (!mounted) return;

    setState(() {
      pendingPhotosBase64.remove(photoBase64);
    });
    AppLogger.info(
        'Foto removida', {'totalPhotos': pendingPhotosBase64.length});
  }

  /// Limpiar fotos pendientes
  void clearPendingPhotos() {
    if (!mounted) return;

    setState(() {
      pendingPhotosBase64.clear();
      photoError = null;
    });
    AppLogger.info('Fotos pendientes limpiadas');
  }

  /// Tomar foto usando cámara - ALMACENAR TEMPORALMENTE
  Future<void> takePhotoFromCamera() async {
    if (!mounted) return;

    setState(() {
      isUploadingPhotos = true;
      photoError = null;
    });

    try {
      AppLogger.info('Tomando foto con cámara para almacenamiento temporal');

      // Solo tomar la foto sin subir a Firebase
      final ImagePicker picker = ImagePicker();
      final XFile? photo = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 60,
        maxWidth: 800,
      );

      if (photo == null) {
        if (mounted) {
          setState(() {
            isUploadingPhotos = false;
          });
        }
        AppLogger.warning('No se seleccionó foto');
        return;
      }

      // Convertir a base64 para almacenamiento temporal
      final Uint8List imageBytes = await photo.readAsBytes();
      final String base64Image = base64Encode(imageBytes);

      if (mounted) {
        setState(() {
          pendingPhotosBase64.add(base64Image);
          isUploadingPhotos = false;
        });
        AppLogger.info('Foto almacenada temporalmente',
            {'totalPending': pendingPhotosBase64.length});
      }
    } catch (e) {
      AppLogger.error('Error tomando foto', e);
      if (mounted) {
        setState(() {
          isUploadingPhotos = false;
          photoError = '${AppLocalizations.of(context)!.error}: $e';
        });
      }
    }
  }

  /// Seleccionar foto de galería - ALMACENAR TEMPORALMENTE
  Future<void> pickPhotoFromGallery() async {
    if (!mounted) return;

    setState(() {
      isUploadingPhotos = true;
      photoError = null;
    });

    try {
      AppLogger.info(
          'Seleccionando foto de galería para almacenamiento temporal');

      // Solo seleccionar la foto sin subir a Firebase
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 60,
        maxWidth: 800,
      );

      if (image == null) {
        if (mounted) {
          setState(() {
            isUploadingPhotos = false;
          });
        }
        AppLogger.warning('No se seleccionó foto');
        return;
      }

      // Convertir a base64 para almacenamiento temporal
      final Uint8List imageBytes = await image.readAsBytes();
      final String base64Image = base64Encode(imageBytes);

      if (mounted) {
        setState(() {
          pendingPhotosBase64.add(base64Image);
          isUploadingPhotos = false;
        });
        AppLogger.info('Foto almacenada temporalmente',
            {'totalPending': pendingPhotosBase64.length});
      }
    } catch (e) {
      AppLogger.error('Error seleccionando foto', e);
      if (mounted) {
        setState(() {
          isUploadingPhotos = false;
          photoError = '${AppLocalizations.of(context)!.error}: $e';
        });
      }
    }
  }

  /// Subir fotos pendientes usando los IDs reales de los documentos de Firestore
  Future<void> _uploadPendingPhotos(List<String> documentIds) async {
    if (pendingPhotosBase64.isEmpty || !mounted) return;

    setState(() {
      isUploadingPhotos = true;
    });

    try {
      AppLogger.info('Subiendo fotos pendientes con itemId predecible', {
        'documentId': documentId,
        'photosCount': pendingPhotosBase64.length,
        'itemType': selectedType.name
      });

      final photoService = PhotoService();
      int uploadedCount = 0;

      for (int i = 0; i < pendingPhotosBase64.length; i++) {
        if (!mounted) return;

        final photoBase64 = pendingPhotosBase64[i];
        // Usar el ID real del documento de Firestore (distribuir fotos entre documentos)
        final itemId = documentIds[i % documentIds.length];

        try {
          // Convertir base64 a XFile temporal para usar el método existente
          final photoBytes = base64Decode(photoBase64);
          final tempFile =
              XFile.fromData(photoBytes, name: 'temp_photo_$i.jpg');

          final result = await FirebasePhotoService.uploadOversizePhoto(
            documentId: documentId,
            itemType: selectedType.name,
            itemId: itemId,
            photo: tempFile,
            flightId: flightId,
            flightDate: DateTime.now(),
          );

          if (result != null) {
            // CLAVE: Guardar también en SharedPreferences para que PhotoButtonWidget la encuentre
            await photoService.savePhotoLocally(
              documentId: documentId,
              flightId: flightId,
              itemId: itemId,
              photoBase64: photoBase64,
              firebaseResult: result,
            );

            uploadedCount++;
            AppLogger.info('Foto subida exitosamente y guardada localmente', {
              'index': i + 1,
              'total': pendingPhotosBase64.length,
              'itemId': itemId
            });
          }
        } catch (e) {
          AppLogger.error('Error subiendo foto individual', e);
          // Continuar con las siguientes fotos
        }
      }

      if (mounted) {
        setState(() {
          isUploadingPhotos = false;
        });
        AppLogger.info('Proceso de subida completado',
            {'uploaded': uploadedCount, 'total': pendingPhotosBase64.length});
      }
    } catch (e) {
      AppLogger.error('Error en proceso de subida de fotos pendientes', e);
      if (mounted) {
        setState(() {
          isUploadingPhotos = false;
        });
      }
    }
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
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  '${localizations.pleaseConfirmRegister} $count ${getTypeLabel(selectedType, localizations)} ${localizations.forFlight} $flightId'),
              if (pendingPhotosBase64.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  '${pendingPhotosBase64.length} ${AppLocalizations.of(context)!.changePhoto.toLowerCase()}s',
                  style: TextStyle(
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
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

  /// Enviar formulario con soporte para fotos
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
      isUploadingPhotos = pendingPhotosBase64.isNotEmpty;
    });

    try {
      AppLogger.info('Iniciando registro de elemento sobredimensionado', {
        'type': selectedType.name,
        'count': count,
        'hasPhotos': pendingPhotosBase64.isNotEmpty,
        'photosCount': pendingPhotosBase64.length
      });

      // 1. Registrar el elemento en Firestore primero para obtener IDs reales
      final List<String> documentIds =
          await OversizeFirebaseService.registerItems(
        documentId: documentId,
        flightId: flightId,
        type: selectedType,
        count: count,
        isFragile: false, // Temporalmente deshabilitado
        requiresSpecialHandling: false, // Temporalmente deshabilitado
        specialHandlingDetails: '', // Temporalmente deshabilitado
      );

      // 2. Subir fotos usando los IDs reales de los documentos
      if (pendingPhotosBase64.isNotEmpty && documentIds.isNotEmpty) {
        await _uploadPendingPhotos(documentIds);
      }

      if (!mounted) return;

      setState(() {
        isLoading = false;
        isUploadingPhotos = false;
        countController.clear();
        clearPendingPhotos();
        showPhotoSection =
            false; // Colapsar la sección de fotos después del registro
      });

      // Recargar datos
      if (showHistory) {
        loadItemHistory();
      }
      loadCurrentCount();
      onSuccess();

      // Mostrar mensaje de éxito
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        final photosText = pendingPhotosBase64.isNotEmpty
            ? ' + ${pendingPhotosBase64.length} fotos'
            : '';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${l10n.register} ${l10n.completed}: $count ${OversizeItemTypeUtils.getTypeLabel(selectedType, l10n)}$photosText',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }

      AppLogger.info('Elemento registrado exitosamente', {
        'type': selectedType.name,
        'count': count,
        'photosUploaded': pendingPhotosBase64.length,
        'note': 'Fotos subidas usando ID real del documento'
      });
    } catch (e) {
      AppLogger.error('Error registrando elemento sobredimensionado', e);
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        setState(() {
          isLoading = false;
          isUploadingPhotos = false;
          errorMessage = '${l10n.errorPrefix}: $e';
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
    if (!mounted) return;

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
    if (!mounted) return;

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

      if (mounted) {
        setState(() {
          isDeleting = false;
        });
      }

      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.deliveryMarkedDeleted),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      AppLogger.error('Error marcando elemento como eliminado', e);
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        setState(() {
          isDeleting = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.errorPrefix}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Eliminar todos los elementos
  Future<void> deleteAllItems() async {
    if (!mounted) return;

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
          final l10n = AppLocalizations.of(context)!;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.noRegistriesToDelete),
              backgroundColor: Colors.orange,
            ),
          );
          setState(() {
            isDeleting = false;
          });
        }
        return;
      }

      if (!mounted) return;

      // Recargar datos
      await loadItemHistory();
      await loadCurrentCount();

      if (mounted) {
        setState(() {
          isDeleting = false;
        });
      }

      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$deletedCount ${l10n.registriesDeleted}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      AppLogger.error('Error eliminando todos los elementos', e);
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        setState(() {
          isDeleting = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.errorPrefix}: $e'),
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
