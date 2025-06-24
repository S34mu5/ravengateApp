import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Servicio para gestionar fotos de elementos de equipaje oversized
class PhotoService {
  static const String _photoKeysPrefix = 'oversize_photos_';
  static const int _maxImageQuality = 60; // Reducir calidad para menor tamaño
  static const double _maxImageWidth = 800; // Máximo ancho en píxeles

  final ImagePicker _picker = ImagePicker();

  /// Toma una foto con la cámara y la asocia a un elemento específico
  Future<String?> takePhoto({
    required String documentId,
    required String flightId,
    required String itemId,
  }) async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: _maxImageQuality,
        maxWidth: _maxImageWidth,
      );

      if (photo == null) return null;

      // Leer los bytes de la imagen
      final Uint8List imageBytes = await photo.readAsBytes();

      // Convertir a base64 para almacenamiento local
      final String base64Image = base64Encode(imageBytes);

      // Guardar en SharedPreferences
      await _savePhoto(documentId, flightId, itemId, base64Image);

      return base64Image;
    } catch (e) {
      debugPrint('Error tomando foto: $e');
      return null;
    }
  }

  /// Selecciona una foto de la galería y la asocia a un elemento específico
  Future<String?> pickFromGallery({
    required String documentId,
    required String flightId,
    required String itemId,
  }) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: _maxImageQuality,
        maxWidth: _maxImageWidth,
      );

      if (image == null) return null;

      final Uint8List imageBytes = await image.readAsBytes();
      final String base64Image = base64Encode(imageBytes);

      await _savePhoto(documentId, flightId, itemId, base64Image);

      return base64Image;
    } catch (e) {
      debugPrint('Error seleccionando foto: $e');
      return null;
    }
  }

  /// Obtiene la foto asociada a un elemento específico
  Future<String?> getPhoto({
    required String documentId,
    required String flightId,
    required String itemId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String key = _buildPhotoKey(documentId, flightId, itemId);
      return prefs.getString(key);
    } catch (e) {
      debugPrint('Error obteniendo foto: $e');
      return null;
    }
  }

  /// Elimina la foto asociada a un elemento específico
  Future<bool> deletePhoto({
    required String documentId,
    required String flightId,
    required String itemId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String key = _buildPhotoKey(documentId, flightId, itemId);
      return await prefs.remove(key);
    } catch (e) {
      debugPrint('Error eliminando foto: $e');
      return false;
    }
  }

  /// Construye la clave única para almacenar la foto
  String _buildPhotoKey(String documentId, String flightId, String itemId) {
    return '$_photoKeysPrefix${documentId}_${flightId}_$itemId';
  }

  /// Guarda la foto en SharedPreferences
  Future<void> _savePhoto(
    String documentId,
    String flightId,
    String itemId,
    String base64Image,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final String key = _buildPhotoKey(documentId, flightId, itemId);
    await prefs.setString(key, base64Image);
  }

  /// Convierte base64 a bytes para mostrar la imagen
  static Uint8List? base64ToBytes(String? base64String) {
    if (base64String == null || base64String.isEmpty) return null;
    try {
      return base64Decode(base64String);
    } catch (e) {
      debugPrint('Error convirtiendo base64 a bytes: $e');
      return null;
    }
  }
}
