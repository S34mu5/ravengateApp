import 'package:flutter/material.dart';

/// Widget para controles de selección de vuelos y acciones en masa
class FlightSelectionControls extends StatelessWidget {
  /// Si hay vuelos seleccionados
  final int selectedCount;

  /// Número total de vuelos disponibles
  final int totalFlights;

  /// Función para seleccionar todos los vuelos
  final VoidCallback onSelectAll;

  /// Función para deseleccionar todos los vuelos
  final VoidCallback onDeselectAll;

  /// Función para salir del modo selección
  final VoidCallback onExit;

  /// Función para realizar la acción principal
  final VoidCallback onAction;

  /// Etiqueta para el botón de acción
  final String actionLabel;

  /// Color para el botón de acción
  final Color actionColor;

  /// Color del texto del botón de acción
  final Color actionTextColor;

  /// Icono para el botón de acción
  final IconData actionIcon;

  const FlightSelectionControls({
    required this.selectedCount,
    required this.totalFlights,
    required this.onSelectAll,
    required this.onDeselectAll,
    required this.onExit,
    required this.onAction,
    required this.actionLabel,
    required this.actionColor,
    this.actionTextColor = Colors.black87,
    this.actionIcon = Icons.save,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Botón para guardar los vuelos seleccionados
        FloatingActionButton.extended(
          heroTag: 'actionButton',
          onPressed: selectedCount > 0 ? onAction : null,
          backgroundColor: selectedCount > 0 ? actionColor : Colors.grey,
          foregroundColor: actionTextColor,
          elevation: 4,
          label: Row(
            children: [
              Icon(actionIcon),
              const SizedBox(width: 8),
              Text(
                '$actionLabel ($selectedCount)',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Botón para seleccionar todos los vuelos
        FloatingActionButton(
          heroTag: 'selectAll',
          onPressed: totalFlights > 0
              ? () {
                  if (selectedCount == totalFlights) {
                    onDeselectAll();
                  } else {
                    onSelectAll();
                  }
                }
              : null,
          backgroundColor:
              totalFlights > 0 ? Colors.white : Colors.grey.shade200,
          foregroundColor: Colors.black87,
          elevation: 3,
          mini: true,
          child: Icon(
            selectedCount == totalFlights && totalFlights > 0
                ? Icons.deselect
                : Icons.select_all,
          ),
        ),
        const SizedBox(height: 12),
        // Botón para salir del modo selección
        FloatingActionButton(
          heroTag: 'exitSelection',
          onPressed: onExit,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 3,
          mini: true,
          child: const Icon(Icons.close),
        ),
      ],
    );
  }
}
