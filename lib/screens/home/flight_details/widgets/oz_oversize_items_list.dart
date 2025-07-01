import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../../utils/logger.dart';

/// Widget para mostrar la lista de elementos sobredimensionados registrados
class OzOversizeItemsList extends StatefulWidget {
  final String documentId;
  final VoidCallback onRefresh;

  const OzOversizeItemsList({
    required this.documentId,
    required this.onRefresh,
    super.key,
  });

  @override
  State<OzOversizeItemsList> createState() => _OzOversizeItemsListState();
}

class _OzOversizeItemsListState extends State<OzOversizeItemsList> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _oversizeItems = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadOversizeItems();
  }

  /// Carga la lista de elementos sobredimensionados desde Firestore
  Future<void> _loadOversizeItems() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Referencia a la colección de elementos sobredimensionados
      final oversizeCollection = FirebaseFirestore.instance
          .collection('flights')
          .doc(widget.documentId)
          .collection('oversize');

      // Obtener los documentos ordenados por fecha de creación (más reciente primero)
      final querySnapshot = await oversizeCollection
          .orderBy('created_at', descending: true)
          .get();

      // Convertir los documentos a una lista de mapas
      final items = querySnapshot.docs.map((doc) {
        final data = doc.data();
        // Añadir el ID del documento al mapa
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();

      if (mounted) {
        setState(() {
          _oversizeItems = items;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error cargando elementos: $e';
          _isLoading = false;
        });
      }
      AppLogger.error('Error cargando elementos sobredimensionados', e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Encabezado
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Elementos registrados',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadOversizeItems,
                  tooltip: 'Actualizar lista',
                ),
              ],
            ),
          ),

          // Contenido
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
                ),
              ),
            )
          else if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                _errorMessage!,
                style: TextStyle(color: Colors.red.shade700),
              ),
            )
          else if (_oversizeItems.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.inbox, size: 48, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      'No hay elementos registrados',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _oversizeItems.length,
              separatorBuilder: (context, index) => const Divider(),
              itemBuilder: (context, index) {
                final item = _oversizeItems[index];
                return _buildOversizeItemTile(item);
              },
            ),
        ],
      ),
    );
  }

  /// Construye un tile para mostrar un elemento sobredimensionado
  Widget _buildOversizeItemTile(Map<String, dynamic> item) {
    // Determinar el icono según el tipo
    IconData icon;
    Color iconColor;
    String typeLabel;

    switch (item['type']) {
      case 'trolley':
        icon = Icons.shopping_cart;
        iconColor = Colors.orange;
        typeLabel = 'Trolley';
        break;
      case 'spare':
        icon = Icons.inventory;
        iconColor = Colors.blue;
        typeLabel = 'Spare Item';
        break;
      case 'avih':
        icon = Icons.pets;
        iconColor = Colors.green;
        typeLabel = 'AVIH';
        break;
      default:
        icon = Icons.luggage;
        iconColor = Colors.grey;
        typeLabel = 'Desconocido';
    }

    // Formatear la fecha
    String formattedDate = 'Fecha desconocida';
    if (item['created_at'] != null) {
      try {
        final timestamp = item['created_at'] as Timestamp;
        formattedDate =
            DateFormat('dd/MM/yyyy HH:mm').format(timestamp.toDate());
      } catch (e) {
        AppLogger.error('Error formateando fecha', e);
        formattedDate = 'Fecha inválida';
      }
    }

    // Construir el subtítulo según el tipo
    String subtitle = '';
    if (item['type'] == 'trolley' || item['type'] == 'spare') {
      subtitle = 'Cantidad: ${item['count'] ?? 1}';
      if (item['reference'] != null &&
          item['reference'].toString().isNotEmpty) {
        subtitle += ' • Ref: ${item['reference']}';
      }
    } else if (item['type'] == 'avih') {
      subtitle = 'Pasajero: ${item['passenger_name'] ?? 'No especificado'}';
      if (item['reference'] != null &&
          item['reference'].toString().isNotEmpty) {
        subtitle += ' • Ref: ${item['reference']}';
      }
    }

    // Construir etiquetas adicionales
    List<Widget> tags = [];
    if (item['is_fragile'] == true) {
      tags.add(
        Chip(
          label: const Text('Frágil'),
          backgroundColor: Colors.red.shade100,
          labelStyle: TextStyle(color: Colors.red.shade800, fontSize: 12),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: EdgeInsets.zero,
        ),
      );
    }
    if (item['requires_special_handling'] == true) {
      tags.add(
        Chip(
          label: const Text('Manejo especial'),
          backgroundColor: Colors.purple.shade100,
          labelStyle: TextStyle(color: Colors.purple.shade800, fontSize: 12),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: EdgeInsets.zero,
        ),
      );
    }

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: iconColor.withValues(alpha: 0.2),
        child: Icon(icon, color: iconColor),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                typeLabel,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                formattedDate,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ],
      ),
      subtitle: item['description'] != null &&
              item['description'].toString().isNotEmpty
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  item['description'],
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                if (tags.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: tags,
                  ),
                ],
              ],
            )
          : tags.isNotEmpty
              ? Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: tags,
                  ),
                )
              : null,
      trailing: PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert),
        onSelected: (value) {
          if (value == 'delete') {
            _showDeleteConfirmation(item);
          }
        },
        itemBuilder: (context) => [
          const PopupMenuItem(
            value: 'delete',
            child: Row(
              children: [
                Icon(Icons.delete, color: Colors.red),
                SizedBox(width: 8),
                Text('Eliminar'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Muestra un diálogo de confirmación para eliminar un elemento
  void _showDeleteConfirmation(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar eliminación'),
        content: const Text(
          '¿Está seguro que desea eliminar este elemento? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCELAR'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteOversizeItem(item['id']);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('ELIMINAR'),
          ),
        ],
      ),
    );
  }

  /// Elimina un elemento sobredimensionado de Firestore
  Future<void> _deleteOversizeItem(String itemId) async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Eliminar el documento de Firestore
      await FirebaseFirestore.instance
          .collection('flights')
          .doc(widget.documentId)
          .collection('oversize')
          .doc(itemId)
          .delete();

      // Recargar la lista después de eliminar
      await _loadOversizeItems();

      // Notificar al padre que debe actualizar
      widget.onRefresh();

      // Mostrar mensaje de éxito
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Elemento eliminado correctamente'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error eliminando elemento: $e';
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error eliminando elemento: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      AppLogger.error('Error eliminando elemento sobredimensionado', e);
    }
  }
}
