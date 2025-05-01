import 'package:flutter/material.dart';

/// Widgets comunes utilizados en distintas partes de la UI de detalles de vuelo

/// Crea un chip para mostrar el estado del vuelo
class StatusChip extends StatelessWidget {
  final String text;
  final Color color;

  const StatusChip({
    required this.text,
    required this.color,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}

/// Crea una fila de información con icono, etiqueta y valor
class InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? textColor;
  final TextDecoration? textDecoration;

  const InfoRow({
    required this.label,
    required this.value,
    required this.icon,
    this.textColor,
    this.textDecoration,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          Text(
            '$label ',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: textColor,
                decoration: textDecoration,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
