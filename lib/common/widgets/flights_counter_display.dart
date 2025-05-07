import 'package:flutter/material.dart';

/// Widget para mostrar el contador de vuelos y botones de acción
class FlightsCounterDisplay extends StatelessWidget {
  /// Número total de vuelos filtrados
  final int flightCount;

  /// Texto de búsqueda actual
  final String searchQuery;

  /// Función para activar el modo de selección (ahora obsoleta ya que se usa pulsación larga)
  final VoidCallback? onSelectMode;

  /// Función para resetear los filtros
  final VoidCallback? onResetFilters;

  /// Si mostrar el botón para resetear filtros
  final bool showResetButton;

  /// Si la equivalencia Norwegian está habilitada
  final bool norwegianEquivalenceEnabled;

  /// Widgets adicionales para mostrar antes de los botones de acción
  final List<Widget> leadingActions;

  /// Widgets adicionales para mostrar después de los botones de acción
  final List<Widget> trailingActions;

  const FlightsCounterDisplay({
    required this.flightCount,
    required this.searchQuery,
    this.onSelectMode,
    this.onResetFilters,
    this.showResetButton = false,
    this.norwegianEquivalenceEnabled = true,
    this.leadingActions = const [],
    this.trailingActions = const [],
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Determinar si debemos mostrar el indicador de Norwegian
    final bool showNorwegianIndicator = norwegianEquivalenceEnabled &&
        (searchQuery.toLowerCase().contains('dy') ||
            searchQuery.toLowerCase().contains('d8'));

    return Padding(
      padding:
          const EdgeInsets.only(left: 16.0, right: 16.0, top: 2.0, bottom: 2.0),
      child: Row(
        children: [
          // 1. Contador de vuelos
          Text(
            '$flightCount flights',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),

          // Espaciador
          const SizedBox(width: 12),

          // 2. Indicador Norwegian (cuando sea necesario)
          if (showNorwegianIndicator) _buildNorwegianIndicator(),

          // Espaciador flexible que empuja los elementos a la derecha
          const Spacer(),

          // 3. Acciones principales (si hay)
          ...leadingActions,

          // 5. Botón Reset Filters
          if (showResetButton && onResetFilters != null)
            TextButton.icon(
              onPressed: onResetFilters,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Reset Filters'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                visualDensity: VisualDensity.compact,
              ),
            ),

          // 6. Acciones adicionales (si hay)
          ...trailingActions,
        ],
      ),
    );
  }

  // Widget personalizado para el indicador de Norwegian
  Widget _buildNorwegianIndicator() {
    // Determinar qué texto mostrar según el código buscado
    final String searchedCode =
        searchQuery.toLowerCase().contains('dy') ? 'DY' : 'D8';
    final String equivalentCode = searchedCode == 'DY' ? 'D8' : 'DY';

    // Color rojo de Norwegian
    const Color norwegianColor = Color(0xFFE60A0A);

    return Tooltip(
      message:
          'Mostrando vuelos equivalentes entre Norwegian ($searchedCode) y Norwegian Air International ($equivalentCode)',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: norwegianColor,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          'Showing also $equivalentCode',
          style: const TextStyle(
            fontSize: 11,
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
