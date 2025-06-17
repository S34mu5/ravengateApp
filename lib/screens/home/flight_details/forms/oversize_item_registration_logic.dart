import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../utils/logger.dart';

/// Enumeración para los tipos de elementos sobredimensionados
enum OversizeItemType {
  spare(Icons.inventory),
  trolley(Icons.shopping_cart),
  avih(Icons.pets),
  weap(Icons.security);

  const OversizeItemType(this.icon);
  final IconData icon;
}

/// Mixin que contiene toda la lógica de negocio para el registro de elementos sobredimensionados
mixin OversizeItemRegistrationLogic<T extends StatefulWidget> on State<T> {
  // Controladores y servicios
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
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

  /// Obtiene el nombre de la colección correspondiente a un tipo
  String collectionNameForType(OversizeItemType type) {
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

  /// Convert string to OversizeItemType
  OversizeItemType stringToType(String? str) {
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
  String getTypeLabel(OversizeItemType type, AppLocalizations l10n) {
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
      if (!value) {
        requiresSpecialHandling = false;
        specialHandlingDetails = '';
      }
    });
  }

  /// Enviar formulario
  Future<void> submitForm(GlobalKey<FormState> formKey) async {
    if (!formKey.currentState!.validate()) return;

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('Usuario no autenticado');
      }

      final int count = int.parse(countController.text);
      final String collectionName = collectionNameForType(selectedType);

      // Usar subcolección dentro del documento de vuelo
      await firestore
          .collection('flights')
          .doc(documentId)
          .collection(collectionName)
          .add({
        'timestamp': FieldValue.serverTimestamp(),
        'count': count,
        'flight_id': flightId,
        'document_id': documentId,
        'user_id': user.uid,
        'user_email': user.email,
        'action': 'registro',
        'type': selectedType.name,
        'is_fragile': isFragile,
        'requires_special_handling': requiresSpecialHandling,
        'special_handling_details': specialHandlingDetails,
      });

      if (!mounted) return;

      setState(() {
        isLoading = false;
        countController.clear();
        isFragile = false;
        requiresSpecialHandling = false;
        specialHandlingDetails = '';
      });

      // Recargar historial si está visible
      if (showHistory) {
        loadItemHistory();
      }

      // Recargar conteo actual
      loadCurrentCount();

      // Callback de éxito
      onSuccess();

      // Mostrar mensaje de éxito
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${AppLocalizations.of(context)!.register} completado: $count ${getTypeLabel(selectedType, AppLocalizations.of(context)!)}',
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
          errorMessage = 'Error: $e';
        });
      }
    }
  }

  /// Carga el conteo actual para el tipo seleccionado
  Future<void> loadCurrentCount() async {
    if (isLoadingCurrentCount || !mounted) return;

    setState(() {
      isLoadingCurrentCount = true;
    });

    try {
      final String collectionName = collectionNameForType(selectedType);

      final QuerySnapshot snapshot = await firestore
          .collection('flights')
          .doc(documentId)
          .collection(collectionName)
          .get();

      int totalCount = 0;
      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        // Solo sumamos si no está eliminado
        if (!(data['deleted'] ?? false)) {
          totalCount += (data['count'] as int? ?? 0);
        }
      }

      if (mounted) {
        setState(() {
          currentCount = totalCount;
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
      final String collectionName = collectionNameForType(selectedType);

      // Buscar en la subcolección dentro del documento de vuelo
      final QuerySnapshot snapshot = await firestore
          .collection('flights')
          .doc(documentId)
          .collection(collectionName)
          .orderBy('timestamp', descending: true)
          .limit(50)
          .get();

      if (!mounted) return;

      final List<Map<String, dynamic>> history = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();

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

  /// Marcar elemento como eliminado
  Future<void> markItemAsDeleted(String docId) async {
    setState(() {
      isDeleting = true;
    });

    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('Usuario no autenticado');
      }

      final String collectionName = collectionNameForType(selectedType);

      // Usar subcolección dentro del documento de vuelo
      await firestore
          .collection('flights')
          .doc(documentId)
          .collection(collectionName)
          .doc(docId)
          .set(
        {
          'deleted': true,
          'deleted_at': FieldValue.serverTimestamp(),
          'deleted_by_user_id': user.uid,
          'deleted_by_user_email': user.email,
        },
        SetOptions(merge: true),
      );

      if (!mounted) return;

      // Recargar historial y conteo actual
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
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('Usuario no autenticado');
      }

      final String collectionName = collectionNameForType(selectedType);

      // Buscar en la subcolección dentro del documento de vuelo
      final QuerySnapshot snapshot = await firestore
          .collection('flights')
          .doc(documentId)
          .collection(collectionName)
          .get();

      final docsToDelete = snapshot.docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return data['deleted'] != true;
      }).toList();

      if (docsToDelete.isEmpty) {
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

      // Marcar todos como eliminados usando batch
      WriteBatch batch = firestore.batch();
      for (final doc in docsToDelete) {
        batch.update(doc.reference, {
          'deleted': true,
          'deleted_at': FieldValue.serverTimestamp(),
          'deleted_by_user_id': user.uid,
          'deleted_by_user_email': user.email,
        });
      }

      await batch.commit();

      if (!mounted) return;

      // Recargar historial y conteo actual
      await loadItemHistory();
      await loadCurrentCount();

      setState(() {
        isDeleting = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '${docsToDelete.length} ${AppLocalizations.of(context)!.registriesDeleted}'),
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

  /// Diálogo de confirmación para borrar individual
  Future<void> showDeleteConfirmation(String docId, int count) async {
    final l10n = AppLocalizations.of(context)!;

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.confirmDeletion),
        content: Text(
            '${l10n.deleteRegistryConfirmation} $count ${getTypeLabel(selectedType, l10n).toLowerCase()}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.cancel),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () async {
              Navigator.of(context).pop();
              await markItemAsDeleted(docId);
            },
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
  }

  /// Confirmación antes de borrar todos
  Future<void> showDeleteAllConfirmation() async {
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

    if (confirm == true) {
      await deleteAllItems();
    }
  }
}
