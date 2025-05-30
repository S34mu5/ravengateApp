import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../../utils/logger.dart';

/// Tipos de elementos sobredimensionados
enum OversizeItemType {
  trolley('Trolley', Icons.shopping_cart),
  spare('Spare Item', Icons.inventory),
  avih('AVIH', Icons.pets);

  final String label;
  final IconData icon;

  const OversizeItemType(this.label, this.icon);
}

/// Formulario para registrar elementos sobredimensionados
class OversizeItemRegistrationForm extends StatefulWidget {
  final String flightId;
  final String documentId;
  final String currentGate;
  final VoidCallback onSuccess;

  const OversizeItemRegistrationForm({
    required this.flightId,
    required this.documentId,
    required this.currentGate,
    required this.onSuccess,
    Key? key,
  }) : super(key: key);

  @override
  State<OversizeItemRegistrationForm> createState() =>
      _OversizeItemRegistrationFormState();
}

class _OversizeItemRegistrationFormState
    extends State<OversizeItemRegistrationForm> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _errorMessage;

  // Valores del formulario
  OversizeItemType _selectedType = OversizeItemType.trolley;
  final TextEditingController _countController =
      TextEditingController(text: '1');
  final TextEditingController _referenceController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _passengerNameController =
      TextEditingController();
  bool _isFragile = false;
  bool _requiresSpecialHandling = false;

  @override
  void dispose() {
    _countController.dispose();
    _referenceController.dispose();
    _descriptionController.dispose();
    _passengerNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Calculamos el padding para ajustar el teclado
    final keyboardSpace = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.only(
        bottom: keyboardSpace + 16,
        top: 16,
        left: 16,
        right: 16,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Título del formulario
              Row(
                children: [
                  Icon(_selectedType.icon, color: Colors.amber),
                  const SizedBox(width: 8),
                  Text(
                    'Registrar ${_selectedType.label}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Selección de tipo de elemento
              const Text(
                'Tipo de artículo:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              SegmentedButton<OversizeItemType>(
                segments: OversizeItemType.values.map((type) {
                  return ButtonSegment<OversizeItemType>(
                    value: type,
                    label: Text(type.label),
                    icon: Icon(type.icon),
                  );
                }).toList(),
                selected: {_selectedType},
                onSelectionChanged: (Set<OversizeItemType> selected) {
                  setState(() {
                    _selectedType = selected.first;
                  });
                },
                style: ButtonStyle(
                  backgroundColor: MaterialStateProperty.resolveWith<Color>(
                    (Set<MaterialState> states) {
                      if (states.contains(MaterialState.selected)) {
                        return Colors.amber;
                      }
                      return Colors.grey.shade200;
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Cantidad (solo para trolleys y spare items)
              if (_selectedType != OversizeItemType.avih) ...[
                TextFormField(
                  controller: _countController,
                  decoration: const InputDecoration(
                    labelText: 'Cantidad',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.numbers),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor ingrese la cantidad';
                    }
                    final count = int.tryParse(value);
                    if (count == null || count <= 0) {
                      return 'La cantidad debe ser un número positivo';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
              ],

              // Referencia
              TextFormField(
                controller: _referenceController,
                decoration: InputDecoration(
                  labelText: _selectedType == OversizeItemType.avih
                      ? 'Referencia AVIH'
                      : 'Referencia',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.tag),
                ),
                validator: (value) {
                  if (_selectedType == OversizeItemType.avih &&
                      (value == null || value.isEmpty)) {
                    return 'Por favor ingrese la referencia AVIH';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Descripción
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Descripción',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),

              // Nombre del pasajero (solo para AVIH)
              if (_selectedType == OversizeItemType.avih) ...[
                TextFormField(
                  controller: _passengerNameController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre del pasajero',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor ingrese el nombre del pasajero';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
              ],

              // Opciones adicionales
              CheckboxListTile(
                title: const Text('Frágil'),
                value: _isFragile,
                onChanged: (bool? value) {
                  setState(() {
                    _isFragile = value ?? false;
                  });
                },
                activeColor: Colors.amber,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
              ),

              CheckboxListTile(
                title: const Text('Requiere manejo especial'),
                value: _requiresSpecialHandling,
                onChanged: (bool? value) {
                  setState(() {
                    _requiresSpecialHandling = value ?? false;
                  });
                },
                activeColor: Colors.amber,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
              ),

              const SizedBox(height: 24),

              // Mensaje de error si existe
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(8),
                  color: Colors.red.shade50,
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: Colors.red.shade700),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Botón de registro
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitForm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        )
                      : const Text(
                          'REGISTRAR',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Enviar el formulario y registrar el elemento en Firestore
  Future<void> _submitForm() async {
    // Validar el formulario
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Crear referencia a la colección oversize
      final oversizeCollection = FirebaseFirestore.instance
          .collection('flights')
          .doc(widget.documentId)
          .collection('oversize');

      // Datos comunes para todos los tipos
      final Map<String, dynamic> itemData = {
        'type': _selectedType.name,
        'created_at': FieldValue.serverTimestamp(),
        'gate': widget.currentGate,
        'flight_id': widget.flightId,
        'description': _descriptionController.text.trim(),
        'is_fragile': _isFragile,
        'requires_special_handling': _requiresSpecialHandling,
        'reference': _referenceController.text.trim(),
      };

      // Datos específicos según el tipo
      switch (_selectedType) {
        case OversizeItemType.trolley:
        case OversizeItemType.spare:
          itemData['count'] = int.parse(_countController.text);
          break;
        case OversizeItemType.avih:
          itemData['passenger_name'] = _passengerNameController.text.trim();
          break;
      }

      // Guardar en Firestore
      await oversizeCollection.add(itemData);

      // Mostrar mensaje de éxito y cerrar
      if (mounted) {
        // Llamar al callback de éxito
        widget.onSuccess();
      }
    } catch (e) {
      // Manejar errores
      setState(() {
        _errorMessage = 'Error al registrar: $e';
        _isLoading = false;
      });
      AppLogger.error('Error registrando elemento sobredimensionado', e);
    }
  }
}
