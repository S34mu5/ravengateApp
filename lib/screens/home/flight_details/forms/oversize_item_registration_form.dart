import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import '../../../../utils/logger.dart';
import '../../../../l10n/app_localizations.dart';

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
                    '${AppLocalizations.of(context)!.register} ${_getTypeLabel(_selectedType, AppLocalizations.of(context)!)}',
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
              Text(
                AppLocalizations.of(context)!.itemTypeLabel,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              SegmentedButton<OversizeItemType>(
                segments: OversizeItemType.values.map((type) {
                  return ButtonSegment<OversizeItemType>(
                    value: type,
                    label: Text(
                        _getTypeLabel(type, AppLocalizations.of(context)!)),
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
                  backgroundColor: WidgetStateProperty.resolveWith<Color>(
                    (Set<WidgetState> states) {
                      if (states.contains(WidgetState.selected)) {
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
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context)!.enterQuantity,
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.numbers),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return AppLocalizations.of(context)!.pleaseEnterNumber;
                    }
                    final count = int.tryParse(value);
                    if (count == null || count <= 0) {
                      return AppLocalizations.of(context)!
                          .pleaseEnterValidNumber;
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
                      ? AppLocalizations.of(context)!.avihReferenceLabel
                      : AppLocalizations.of(context)!.referenceLabel,
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.tag),
                ),
                validator: (value) {
                  if (_selectedType == OversizeItemType.avih &&
                      (value == null || value.isEmpty)) {
                    return AppLocalizations.of(context)!
                        .pleaseEnterAvihReference;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Descripción
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.descriptionLabel,
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.description),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),

              // Nombre del pasajero (solo para AVIH)
              if (_selectedType == OversizeItemType.avih) ...[
                TextFormField(
                  controller: _passengerNameController,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context)!.passengerNameLabel,
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.person),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return AppLocalizations.of(context)!
                          .pleaseEnterPassengerName;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
              ],

              // Opciones adicionales
              CheckboxListTile(
                title: Text(AppLocalizations.of(context)!.fragileLabel),
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
                title: Text(
                    AppLocalizations.of(context)!.requiresSpecialHandlingLabel),
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
                      : Text(
                          AppLocalizations.of(context)!.register.toUpperCase(),
                          style: const TextStyle(
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
        _errorMessage = '${AppLocalizations.of(context)!.errorSaving} $e';
        _isLoading = false;
      });
      AppLogger.error('Error registrando elemento sobredimensionado', e);
    }
  }

  String _getTypeLabel(OversizeItemType type, AppLocalizations l10n) {
    switch (type) {
      case OversizeItemType.trolley:
        return l10n.trolley;
      case OversizeItemType.spare:
        return l10n.spareItem;
      case OversizeItemType.avih:
        return l10n.avih;
    }
  }
}
