import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../services/localization/language_service.dart';

/// Widget selector de idiomas con diseño moderno
class LanguageSelector extends StatelessWidget {
  final String currentLanguageCode;
  final Function(String) onLanguageChanged;

  const LanguageSelector({
    required this.currentLanguageCode,
    required this.onLanguageChanged,
    super.key,
  });

  /// Muestra el modal selector de idiomas
  static Future<void> show(
    BuildContext context, {
    required String currentLanguageCode,
    required Function(String) onLanguageChanged,
  }) async {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return LanguageSelector(
          currentLanguageCode: currentLanguageCode,
          onLanguageChanged: onLanguageChanged,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Barra superior
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Título
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Icon(
                    Icons.language,
                    color: Theme.of(context).primaryColor,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          localizations.languageSettings,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          localizations.selectLanguage,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Lista de idiomas
            ...LanguageService.supportedLanguages.map((language) {
              final isSelected = language.languageCode == currentLanguageCode;

              return InkWell(
                onTap: () {
                  if (!isSelected) {
                    onLanguageChanged(language.languageCode);
                  }
                  Navigator.of(context).pop();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Theme.of(context).primaryColor.withValues(alpha: 0.1)
                        : null,
                  ),
                  child: Row(
                    children: [
                      // Bandera
                      Text(
                        language.flag,
                        style: const TextStyle(fontSize: 24),
                      ),
                      const SizedBox(width: 16),

                      // Nombre del idioma
                      Expanded(
                        child: Text(
                          language.name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight:
                                isSelected ? FontWeight.w600 : FontWeight.w400,
                            color: isSelected
                                ? Theme.of(context).primaryColor
                                : null,
                          ),
                        ),
                      ),

                      // Indicador de selección
                      if (isSelected)
                        Icon(
                          Icons.check_circle,
                          color: Theme.of(context).primaryColor,
                          size: 20,
                        ),
                    ],
                  ),
                ),
              );
            }).toList(),

            // Espacio inferior
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

/// Widget compacto para mostrar el idioma actual en configuración
class CurrentLanguageDisplay extends StatelessWidget {
  final String languageCode;
  final VoidCallback onTap;

  const CurrentLanguageDisplay({
    required this.languageCode,
    required this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final languageInfo = LanguageService.getLanguageInfo(languageCode);

    return ListTile(
      leading: const Icon(Icons.language, color: Colors.blue),
      title: Text(localizations.languageSettings),
      subtitle: Text(localizations.selectLanguage),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (languageInfo != null) ...[
            Text(
              languageInfo.flag,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(width: 8),
            Text(
              languageInfo.name,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(width: 8),
          ],
          const Icon(Icons.arrow_forward_ios, size: 16),
        ],
      ),
      onTap: onTap,
    );
  }
}
