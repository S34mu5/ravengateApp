import 'package:flutter/material.dart';
import 'photo_service.dart';
import '../location/location_service.dart';
import '../../l10n/app_localizations.dart';

/// Widget para mostrar el botón de foto en cada elemento de la lista
/// Cambia entre ícono de cámara y miniatura según si tiene foto o no
class PhotoButtonWidget extends StatefulWidget {
  final String documentId;
  final String flightId;
  final String itemId;
  final VoidCallback? onPhotoChanged;

  const PhotoButtonWidget({
    required this.documentId,
    required this.flightId,
    required this.itemId,
    this.onPhotoChanged,
    Key? key,
  }) : super(key: key);

  @override
  State<PhotoButtonWidget> createState() => _PhotoButtonWidgetState();
}

class _PhotoButtonWidgetState extends State<PhotoButtonWidget> {
  final PhotoService _photoService = PhotoService();
  String? _currentPhotoBase64;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadPhoto();
  }

  /// Carga la foto existente si la hay
  Future<void> _loadPhoto() async {
    final photo = await _photoService.getPhoto(
      documentId: widget.documentId,
      flightId: widget.flightId,
      itemId: widget.itemId,
    );

    if (mounted) {
      setState(() {
        _currentPhotoBase64 = photo;
      });
    }
  }

  /// Maneja el tap simple en el botón
  Future<void> _handleTap() async {
    if (_isLoading) return;

    // Verificar si el usuario está en ubicación Oversize
    final isOversizeLocation = await LocationService.isOversizeLocation();

    if (_currentPhotoBase64 != null) {
      // Si ya tiene foto, mostrarla directamente
      await _showFullPhoto(canManagePhoto: isOversizeLocation);
    } else {
      // Solo permitir agregar fotos si está en ubicación Oversize
      if (!isOversizeLocation) {
        await _showLocationRestrictedMessage();
        return;
      }

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
      String? newPhoto;
      switch (result) {
        case 'camera':
          newPhoto = await _photoService.takePhoto(
            documentId: widget.documentId,
            flightId: widget.flightId,
            itemId: widget.itemId,
          );
          break;
        case 'gallery':
          newPhoto = await _photoService.pickFromGallery(
            documentId: widget.documentId,
            flightId: widget.flightId,
            itemId: widget.itemId,
          );
          break;
      }

      if (newPhoto != null && mounted) {
        setState(() {
          _currentPhotoBase64 = newPhoto;
        });
        widget.onPhotoChanged?.call();
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

  /// Muestra la foto en pantalla completa con opciones de gestión
  Future<void> _showFullPhoto({bool canManagePhoto = true}) async {
    if (_currentPhotoBase64 == null) return;

    final imageBytes = PhotoService.base64ToBytes(_currentPhotoBase64);
    if (imageBytes == null) return;

    final l10n = AppLocalizations.of(context)!;

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
    if (result != null && mounted && canManagePhoto) {
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

  /// Elimina la foto
  Future<void> _deletePhoto() async {
    final success = await _photoService.deletePhoto(
      documentId: widget.documentId,
      flightId: widget.flightId,
      itemId: widget.itemId,
    );

    if (success && mounted) {
      setState(() {
        _currentPhotoBase64 = null;
      });
      widget.onPhotoChanged?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
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
            child: Container(
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
