import 'package:flutter/material.dart';
import '../../utils/logger.dart';
import 'photo_service.dart';
import '../location/location_service.dart';
import '../../l10n/app_localizations.dart';

/// Widget para mostrar el botón de foto en cada elemento de la lista
/// Cambia entre ícono de cámara y miniatura según si tiene foto o no
class PhotoButtonWidget extends StatefulWidget {
  final String documentId;
  final String flightId;
  final String itemId;
  final String itemType;
  final DateTime? flightDate; // Fecha del vuelo para organizar carpetas
  final VoidCallback? onPhotoChanged;

  const PhotoButtonWidget({
    required this.documentId,
    required this.flightId,
    required this.itemId,
    required this.itemType,
    this.flightDate,
    this.onPhotoChanged,
    super.key,
  });

  @override
  State<PhotoButtonWidget> createState() => _PhotoButtonWidgetState();
}

class _PhotoButtonWidgetState extends State<PhotoButtonWidget> {
  final PhotoService _photoService = PhotoService();
  String? _currentPhotoBase64;
  bool _isLoading = false;
  bool _isLoadingInitial = true; // Loading para la carga inicial
  bool _isSynced = false;

  @override
  void initState() {
    super.initState();
    _loadPhoto();
  }

  /// Carga la foto existente si la hay
  Future<void> _loadPhoto() async {
    if (!mounted) return;

    AppLogger.debug('🔍 Cargando foto existente para item ${widget.itemId}...',
        null, 'PhotoButtonWidget');
    AppLogger.debug(
        '📋 Parámetros - documentId: ${widget.documentId}, itemType: ${widget.itemType}',
        null,
        'PhotoButtonWidget');

    try {
      // 1. Intentar cargar DESDE CACHÉ local primero
      AppLogger.debug(
          '📱 Buscando en caché local...', null, 'PhotoButtonWidget');
      String? photo = await _photoService.getPhoto(
        documentId: widget.documentId,
        flightId: widget.flightId,
        itemId: widget.itemId,
      );

      bool isSynced = await _photoService.isPhotoSynced(
        documentId: widget.documentId,
        flightId: widget.flightId,
        itemId: widget.itemId,
      );

      // 2. Si no hay foto local o no está sincronizada, consultar Firebase
      if (photo == null || !isSynced) {
        AppLogger.debug(
            '☁️ Caché vacía o desincronizada → buscando en Firebase...',
            null,
            'PhotoButtonWidget');
        final String? remotePhoto = await _photoService.getPhotoFromFirebase(
          documentId: widget.documentId,
          itemId: widget.itemId,
          itemType: widget.itemType,
        );

        if (remotePhoto != null) {
          AppLogger.info(
              '✅ Foto obtenida de Firebase', null, 'PhotoButtonWidget');
          photo = remotePhoto;
          isSynced = true;

          // Guardar la copia descargada para futuras cargas sin red
          await _photoService.savePhotoLocally(
            documentId: widget.documentId,
            flightId: widget.flightId,
            itemId: widget.itemId,
            photoBase64: remotePhoto,
            firebaseResult: {
              'photo_id': 'cached',
              'url': 'cached',
              'photo_data': {},
            },
          );
          AppLogger.debug('💾 Copia remota almacenada en caché local', null,
              'PhotoButtonWidget');
        } else {
          AppLogger.warning(
              '❌ No se encontró foto en Firebase', null, 'PhotoButtonWidget');
        }
      } else {
        AppLogger.debug(
            '✅ Foto obtenida de caché local', null, 'PhotoButtonWidget');
      }

      AppLogger.debug(
          '🏁 Resultado final - Foto encontrada: ${photo != null ? "Sí" : "No"}',
          null,
          'PhotoButtonWidget');
      AppLogger.debug(
          '☁️ Está sincronizada: $isSynced', null, 'PhotoButtonWidget');

      if (mounted) {
        setState(() {
          _currentPhotoBase64 = photo;
          _isSynced = isSynced;
          _isLoadingInitial = false; // Finalizar loading inicial
        });
      }
    } catch (e) {
      AppLogger.error('💥 Error cargando foto para itemId ${widget.itemId}: $e',
          e, 'PhotoButtonWidget');
      if (mounted) {
        setState(() {
          _isLoadingInitial =
              false; // Finalizar loading inicial incluso en error
        });
      }
    }
  }

  /// Maneja el tap simple en el botón
  Future<void> _handleTap() async {
    AppLogger.debug('👆 Tap detectado', null, 'PhotoButtonWidget');
    if (_isLoading) {
      AppLogger.debug(
          '⏳ Ya está cargando, ignorando tap', null, 'PhotoButtonWidget');
      return;
    }

    // Verificar si el usuario está en ubicación Oversize
    AppLogger.debug('📍 Verificando ubicación...', null, 'PhotoButtonWidget');
    final isOversizeLocation = await LocationService.isOversizeLocation();
    AppLogger.debug('📍 Ubicación Oversize: $isOversizeLocation', null,
        'PhotoButtonWidget');

    if (_currentPhotoBase64 != null) {
      AppLogger.debug('🖼️ Ya tiene foto, mostrando vista completa', null,
          'PhotoButtonWidget');
      // Si ya tiene foto, mostrarla directamente
      await _showFullPhoto(canManagePhoto: isOversizeLocation);
    } else {
      AppLogger.debug(
          'No tiene foto, verificando permisos', null, 'PhotoButtonWidget');
      // Solo permitir agregar fotos si está en ubicación Oversize
      if (!isOversizeLocation) {
        AppLogger.warning(
            '🚫 Ubicación no permitida', null, 'PhotoButtonWidget');
        await _showLocationRestrictedMessage();
        return;
      }

      AppLogger.info('✅ Mostrando opciones de foto', null, 'PhotoButtonWidget');
      // Si no tiene foto y está en Oversize, mostrar opciones para agregar
      setState(() {
        _isLoading = true;
      });

      try {
        await _showPhotoAddOptions();
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  /// Muestra opciones para agregar foto
  Future<void> _showPhotoAddOptions() async {
    final l10n = AppLocalizations.of(context)!;

    final result = await showModalBottomSheet<String>(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: Text(l10n.takePhoto),
                onTap: () => Navigator.pop(context, 'camera'),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: Text(l10n.selectFromGallery),
                onTap: () => Navigator.pop(context, 'gallery'),
              ),
              ListTile(
                leading: const Icon(Icons.cancel),
                title: Text(l10n.cancel),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    );

    if (result != null && mounted) {
      AppLogger.info('Opción seleccionada: $result', null, 'PhotoButtonWidget');
      String? newPhoto;
      switch (result) {
        case 'camera':
          AppLogger.info(
              '📸 Tomando foto con cámara...', null, 'PhotoButtonWidget');
          newPhoto = await _photoService.takePhoto(
            documentId: widget.documentId,
            flightId: widget.flightId,
            itemId: widget.itemId,
            itemType: widget.itemType,
            flightDate: widget.flightDate,
          );
          break;
        case 'gallery':
          AppLogger.info(
              '🖼️ Seleccionando de galería...', null, 'PhotoButtonWidget');
          newPhoto = await _photoService.pickFromGallery(
            documentId: widget.documentId,
            flightId: widget.flightId,
            itemId: widget.itemId,
            itemType: widget.itemType,
            flightDate: widget.flightDate,
          );
          break;
      }

      if (newPhoto != null && mounted) {
        AppLogger.info('✅ Nueva foto obtenida, actualizando UI', null,
            'PhotoButtonWidget');
        setState(() {
          _currentPhotoBase64 = newPhoto;
          _isSynced = true; // La foto recién subida está sincronizada
        });
        widget.onPhotoChanged?.call();
      } else {
        AppLogger.warning(
            '❌ No se obtuvo foto nueva', null, 'PhotoButtonWidget');
        // Mostrar mensaje de error al usuario
        if (mounted) {
          _showUploadErrorMessage();
        }
      }
    }
  }

  /// Muestra mensaje cuando la ubicación no permite gestionar fotos
  Future<void> _showLocationRestrictedMessage() async {
    final l10n = AppLocalizations.of(context)!;

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(l10n.accessRestricted),
          content: Text(l10n.oversizeLocationOnly),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.understood),
            ),
          ],
        );
      },
    );
  }

  /// Muestra mensaje de error cuando falla la subida de foto
  Future<void> _showUploadErrorMessage() async {
    final l10n = AppLocalizations.of(context)!;

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.error, color: Colors.red),
              const SizedBox(width: 8),
              Text(l10n.uploadError),
            ],
          ),
          content: Text(l10n.photoUploadFailed),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.understood),
            ),
          ],
        );
      },
    );
  }

  /// Muestra la foto en pantalla completa con opciones de gestión
  Future<void> _showFullPhoto({bool canManagePhoto = true}) async {
    if (_currentPhotoBase64 == null || !mounted) return;

    final imageBytes = PhotoService.base64ToBytes(_currentPhotoBase64);
    if (imageBytes == null) return;

    final l10n = AppLocalizations.of(context)!;

    // Obtener metadatos para mostrar información de subida
    final metadata = await _photoService.getFirebaseMetadata(
      documentId: widget.documentId,
      flightId: widget.flightId,
      itemId: widget.itemId,
    );

    if (!mounted) return;

    final result = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          child: Container(
            constraints: const BoxConstraints(maxHeight: 600),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppBar(
                  title: Text(l10n.photoOfElement),
                  leading: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                // Información de metadatos si está disponible
                if (metadata != null) _buildPhotoMetadata(metadata, l10n),
                Expanded(
                  child: InteractiveViewer(
                    child: Image.memory(
                      imageBytes,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                // Opciones de gestión en la parte inferior (solo si está en ubicación Oversize)
                if (canManagePhoto)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      border: Border(
                        top: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => Navigator.pop(context, 'change'),
                            icon: const Icon(Icons.camera_alt),
                            label: Text(l10n.changePhoto),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => Navigator.pop(context, 'delete'),
                            icon: const Icon(Icons.delete),
                            label: Text(l10n.deletePhoto),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );

    // Procesar la acción seleccionada (solo si se puede gestionar la foto)
    if (result != null && canManagePhoto && mounted) {
      switch (result) {
        case 'change':
          await _showPhotoAddOptions();
          break;
        case 'delete':
          await _deletePhoto();
          break;
      }
    }
  }

  /// Construye el widget de metadatos de la foto
  Widget _buildPhotoMetadata(
      Map<String, dynamic> metadata, AppLocalizations l10n) {
    // Extraer información de los metadatos
    final String? syncedAt = metadata['synced_at'];
    final Map<String, dynamic>? photoData = metadata['photo_data'];
    final Map<String, dynamic>? uploadedBy = photoData?['uploaded_by'];

    String timeText = l10n.unknownTime;
    String userText = l10n.unknownUser;

    // Formatear fecha de subida
    if (syncedAt != null) {
      try {
        final DateTime uploadTime = DateTime.parse(syncedAt);
        final String formattedDate =
            '${uploadTime.day.toString().padLeft(2, '0')}/'
            '${uploadTime.month.toString().padLeft(2, '0')}/'
            '${uploadTime.year}';
        final String formattedTime =
            '${uploadTime.hour.toString().padLeft(2, '0')}:'
            '${uploadTime.minute.toString().padLeft(2, '0')}';
        timeText = l10n.uploadedAtTime(formattedDate, formattedTime);
      } catch (e) {
        AppLogger.warning(
            'Error parseando fecha: $e', null, 'PhotoButtonWidget');
      }
    }

    // Extraer información del usuario
    if (uploadedBy != null) {
      final String? email = uploadedBy['email'];
      final String? displayName = uploadedBy['displayName'];
      if (displayName != null && displayName.isNotEmpty) {
        userText = displayName;
      } else if (email != null) {
        userText = email;
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        border: Border(
          bottom: BorderSide(color: Colors.blue.shade200),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.access_time, size: 16, color: Colors.blue.shade700),
              const SizedBox(width: 6),
              Text(
                '${l10n.uploadedAt} $timeText',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.blue.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.person, size: 16, color: Colors.blue.shade700),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${l10n.uploadedBy} $userText',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.blue.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Elimina la foto
  Future<void> _deletePhoto() async {
    final success = await _photoService.deletePhoto(
      documentId: widget.documentId,
      flightId: widget.flightId,
      itemId: widget.itemId,
      itemType: widget.itemType,
    );

    if (success && mounted) {
      setState(() {
        _currentPhotoBase64 = null;
        _isSynced = false; // Resetear estado de sincronización
      });
      widget.onPhotoChanged?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Mostrar spinner durante loading inicial o loading de acciones
    if (_isLoadingInitial || _isLoading) {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    return FutureBuilder<bool>(
      future: LocationService.isOversizeLocation(),
      builder: (context, snapshot) {
        final isOversizeLocation = snapshot.data ?? false;
        final isEnabled = _currentPhotoBase64 != null || isOversizeLocation;

        if (_currentPhotoBase64 != null) {
          // Mostrar miniatura de la foto
          final imageBytes = PhotoService.base64ToBytes(_currentPhotoBase64);

          return GestureDetector(
            onTap: _handleTap,
            child: Stack(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.green, width: 2),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: imageBytes != null
                        ? Image.memory(
                            imageBytes,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                          )
                        : const Icon(
                            Icons.error,
                            color: Colors.red,
                            size: 20,
                          ),
                  ),
                ),
                // Indicador de sincronización en la esquina superior derecha
                Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: _isSynced ? Colors.blue : Colors.grey,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1),
                    ),
                    child: Icon(
                      _isSynced ? Icons.cloud_done : Icons.cloud_off,
                      color: Colors.white,
                      size: 8,
                    ),
                  ),
                ),
              ],
            ),
          );
        } else {
          // Mostrar ícono de cámara (siempre clickeable para mostrar restricción si es necesario)
          return GestureDetector(
            onTap: _handleTap,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isEnabled ? Colors.blue.shade50 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color:
                      isEnabled ? Colors.blue.shade200 : Colors.grey.shade300,
                ),
              ),
              child: Icon(
                Icons.camera_alt,
                color: isEnabled ? Colors.blue.shade600 : Colors.grey.shade400,
                size: 20,
              ),
            ),
          );
        }
      },
    );
  }
}
