import 'package:flutter/material.dart';

/// Un widget de barra de búsqueda reutilizable para las pantallas de vuelos
class FlightSearchBar extends StatelessWidget {
  /// Controlador del campo de texto
  final TextEditingController controller;

  /// Función llamada cuando el texto de búsqueda cambia
  final Function(String) onSearch;

  /// Texto mostrado como placeholder cuando el campo está vacío
  final String hintText;

  /// Función llamada cuando se presiona el botón de limpiar
  final VoidCallback onClear;

  /// Color del icono de búsqueda
  final Color searchIconColor;

  /// Si es true, limpiará también el controlador al limpiar la búsqueda
  final bool clearController;

  const FlightSearchBar({
    required this.controller,
    required this.onSearch,
    required this.onClear,
    this.hintText = 'Search by flight number or destination',
    this.searchIconColor = Colors.blue,
    this.clearController = true,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          const EdgeInsets.only(left: 16.0, right: 16.0, top: 4.0, bottom: 8.0),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          hintText: hintText,
          prefixIcon: Icon(Icons.search, color: searchIconColor),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          contentPadding:
              const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          filled: true,
          fillColor: Colors.white,
          // Añadir botón para limpiar si hay texto
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear, color: Colors.grey.shade600),
                  onPressed: () {
                    // Limpiar la búsqueda
                    if (clearController) {
                      controller.clear();
                    }
                    onClear();
                  },
                )
              : null,
        ),
        onChanged: onSearch,
      ),
    );
  }
}
