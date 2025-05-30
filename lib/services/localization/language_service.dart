import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/logger.dart';

/// Servicio para manejar la configuración de idioma de la aplicación
class LanguageService {
  static const String _languageKey = 'selected_language';

  /// Idiomas soportados por la aplicación
  static const List<LanguageOption> supportedLanguages = [
    LanguageOption(
      languageCode: 'es',
      countryCode: '',
      name: 'Español',
      flag: '🇪🇸',
    ),
    LanguageOption(
      languageCode: 'en',
      countryCode: '',
      name: 'English',
      flag: '🇺🇸',
    ),
    LanguageOption(
      languageCode: 'no',
      countryCode: '',
      name: 'Norsk',
      flag: '🇳🇴',
    ),
  ];

  /// Obtiene el idioma guardado en preferencias o el del sistema
  static Future<Locale> getSavedLanguage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedLanguageCode = prefs.getString(_languageKey);

      if (savedLanguageCode != null) {
        AppLogger.info('Idioma guardado encontrado: $savedLanguageCode');
        return Locale(savedLanguageCode);
      }

      // Si no hay idioma guardado, detectar idioma del sistema
      final systemLocale = _getSystemLocale();
      AppLogger.info('Usando idioma del sistema: ${systemLocale.languageCode}');
      return systemLocale;
    } catch (e) {
      AppLogger.error('No se pudo cargar el idioma guardado', e);
      // Fallback a inglés para usuarios nuevos
      return const Locale('en');
    }
  }

  /// Guarda el idioma seleccionado en preferencias
  static Future<bool> saveLanguage(String languageCode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_languageKey, languageCode);
      AppLogger.info('Idioma guardado: $languageCode');
      return true;
    } catch (e) {
      AppLogger.error('No se pudo guardar el idioma', e);
      return false;
    }
  }

  /// Obtiene el idioma del sistema si es soportado, sino devuelve inglés
  static Locale _getSystemLocale() {
    // En Flutter Web esto puede ser null, por eso usamos fallback
    final systemLocales = WidgetsBinding.instance.platformDispatcher.locales;

    if (systemLocales.isNotEmpty) {
      for (final locale in systemLocales) {
        // Verificar si el idioma del sistema es soportado
        if (_isLanguageSupported(locale.languageCode)) {
          return Locale(locale.languageCode);
        }
      }
    }

    // Fallback a inglés para usuarios nuevos
    return const Locale('en');
  }

  /// Verifica si un idioma está soportado
  static bool _isLanguageSupported(String languageCode) {
    return supportedLanguages.any((lang) => lang.languageCode == languageCode);
  }

  /// Obtiene la información completa de un idioma por su código
  static LanguageOption? getLanguageInfo(String languageCode) {
    try {
      return supportedLanguages
          .firstWhere((lang) => lang.languageCode == languageCode);
    } catch (e) {
      return null;
    }
  }

  /// Obtiene el nombre del idioma actual
  static String getLanguageName(String languageCode) {
    final languageInfo = getLanguageInfo(languageCode);
    return languageInfo?.name ?? 'Desconocido';
  }

  /// Obtiene la bandera del idioma actual
  static String getLanguageFlag(String languageCode) {
    final languageInfo = getLanguageInfo(languageCode);
    return languageInfo?.flag ?? '🌍';
  }

  /// Elimina la configuración de idioma guardada (para testing)
  static Future<bool> clearSavedLanguage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_languageKey);
      AppLogger.info('Configuración de idioma eliminada');
      return true;
    } catch (e) {
      AppLogger.error('No se pudo eliminar la configuración de idioma', e);
      return false;
    }
  }
}

/// Clase que representa una opción de idioma
class LanguageOption {
  final String languageCode;
  final String countryCode;
  final String name;
  final String flag;

  const LanguageOption({
    required this.languageCode,
    required this.countryCode,
    required this.name,
    required this.flag,
  });

  /// Convierte a Locale
  Locale get locale => Locale(languageCode, countryCode);

  @override
  String toString() {
    return '$flag $name';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LanguageOption &&
        other.languageCode == languageCode &&
        other.countryCode == countryCode;
  }

  @override
  int get hashCode => languageCode.hashCode ^ countryCode.hashCode;
}
