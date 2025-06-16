import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/localization/language_service.dart';
import '../../../main.dart' as app;

class LanguageSettingsScreen extends StatefulWidget {
  const LanguageSettingsScreen({super.key});

  @override
  State<LanguageSettingsScreen> createState() => _LanguageSettingsScreenState();
}

class _LanguageSettingsScreenState extends State<LanguageSettingsScreen> {
  String _currentLanguageCode = 'en';

  @override
  void initState() {
    super.initState();
  }

  void _loadCurrentLanguage() {
    final currentLanguage = Localizations.localeOf(context).languageCode;
    if (_currentLanguageCode != currentLanguage) {
      setState(() {
        _currentLanguageCode = currentLanguage;
      });
    }
  }

  Future<void> _changeLanguage(String languageCode) async {
    if (languageCode != _currentLanguageCode) {
      // Cambiar idioma usando la función global
      app.changeAppLanguage(languageCode);

      // Actualizar el estado local
      setState(() {
        _currentLanguageCode = languageCode;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    // Cargar idioma actual aquí donde context está disponible
    _loadCurrentLanguage();

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.languageSettings),
        elevation: 0,
      ),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              localizations.selectLanguage,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
          ),
          // Lista de idiomas disponibles
          ...LanguageService.supportedLanguages.map((language) {
            final isSelected = language.languageCode == _currentLanguageCode;

            return InkWell(
              onTap: () => _changeLanguage(language.languageCode),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    // Bandera
                    Text(
                      language.flag,
                      style: const TextStyle(fontSize: 32),
                    ),
                    const SizedBox(width: 16),

                    // Información del idioma
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            language.name,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: isSelected
                                  ? Theme.of(context).primaryColor
                                  : null,
                            ),
                          ),
                          Text(
                            language.languageCode.toUpperCase(),
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Indicador de selección
                    if (isSelected)
                      Icon(
                        Icons.check_circle,
                        color: Theme.of(context).primaryColor,
                        size: 24,
                      )
                    else
                      Icon(
                        Icons.radio_button_unchecked,
                        color: Colors.grey[400],
                        size: 24,
                      ),
                  ],
                ),
              ),
            );
          }).toList(),

          // Información adicional
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.blue.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.blue[700],
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        localizations.languageInfo,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue[700],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    localizations.languageChangeInfo,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.blue[700],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
