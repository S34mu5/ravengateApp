import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/flight_formatters.dart';
import '../../../../l10n/app_localizations.dart';
import 'oversize_item_registration_logic.dart';

/// UI para registrar elementos sobredimensionados
class OversizeItemRegistrationUI extends StatefulWidget {
  final String flightId;
  final String documentId;
  final String currentGate;
  final VoidCallback onSuccess;
  final bool showCloseIcon;

  const OversizeItemRegistrationUI({
    required this.flightId,
    required this.documentId,
    required this.currentGate,
    required this.onSuccess,
    this.showCloseIcon = true,
    Key? key,
  }) : super(key: key);

  @override
  State<OversizeItemRegistrationUI> createState() =>
      _OversizeItemRegistrationUIState();
}

class _OversizeItemRegistrationUIState extends State<OversizeItemRegistrationUI>
    with OversizeItemRegistrationLogic {
  final _formKey = GlobalKey<FormState>();

  // Implementación de los getters requeridos por el mixin
  @override
  String get flightId => widget.flightId;

  @override
  String get documentId => widget.documentId;

  @override
  String get currentGate => widget.currentGate;

  @override
  VoidCallback get onSuccess => widget.onSuccess;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
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
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHeader(),
                const SizedBox(height: 16),
                _buildTypeSelector(),
                const SizedBox(height: 16),
                _buildFormRow(),
                const SizedBox(height: 16),
                _buildAdditionalOptions(),
                const SizedBox(height: 24),
                _buildErrorMessage(),
                _buildHistoryToggle(),
                _buildHistorySection(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Construye el header con título e icono de cerrar
  Widget _buildHeader() {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Oversize Baggage Management',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        if (widget.showCloseIcon)
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
      ],
    );
  }

  /// Construye el selector de tipo de elemento
  Widget _buildTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
            final labelText = getTypeLabel(
              type,
              AppLocalizations.of(context)!,
            );

            return ButtonSegment<OversizeItemType>(
              value: type,
              label: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  type == OversizeItemType.spare
                      ? labelText.replaceFirst(' ', '\n')
                      : labelText,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                ),
              ),
              icon: Icon(type.icon, size: 16),
            );
          }).toList(),
          selected: {selectedType},
          onSelectionChanged: (Set<OversizeItemType> selected) {
            changeSelectedType(selected.first);
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
            padding: WidgetStateProperty.all(
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6)),
            visualDensity: VisualDensity.compact,
          ),
        ),
      ],
    );
  }

  /// Construye la fila con campo de cantidad y botón registrar
  Widget _buildFormRow() {
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            controller: countController,
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context)!.enterQuantity,
              prefixIcon: Icon(
                selectedType == OversizeItemType.weap
                    ? Icons.security
                    : Icons.shopping_cart,
                color: Colors.amber,
              ),
              border: const OutlineInputBorder(),
              enabledBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: Colors.amber),
              ),
              focusedBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: Colors.amber, width: 2),
              ),
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            validator: (value) {
              if (value == null || value.isEmpty) {
                return AppLocalizations.of(context)!.pleaseEnterNumber;
              }
              final count = int.tryParse(value);
              if (count == null || count <= 0) {
                return AppLocalizations.of(context)!.pleaseEnterValidNumber;
              }
              return null;
            },
          ),
        ),
        const SizedBox(width: 16),
        ElevatedButton.icon(
          onPressed: isLoading ? null : () => submitForm(_formKey),
          icon: isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.local_shipping, size: 16),
          label: Text(
            AppLocalizations.of(context)!.register,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.amber,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ],
    );
  }

  /// Construye las opciones adicionales (frágil, manejo especial)
  Widget _buildAdditionalOptions() {
    return Column(
      children: [
        CheckboxListTile(
          title: Text(AppLocalizations.of(context)!.fragileLabel),
          value: isFragile,
          onChanged: (bool? value) {
            changeFragileState(value ?? false);
          },
          activeColor: Colors.amber,
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
        ),
        CheckboxListTile(
          title:
              Text(AppLocalizations.of(context)!.requiresSpecialHandlingLabel),
          value: requiresSpecialHandling,
          onChanged: (bool? value) {
            changeSpecialHandlingState(value ?? false);
          },
          activeColor: Colors.amber,
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
        ),
      ],
    );
  }

  /// Construye el mensaje de error si existe
  Widget _buildErrorMessage() {
    if (errorMessage == null) return const SizedBox.shrink();

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          color: Colors.red.shade50,
          child: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red.shade700),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  errorMessage!,
                  style: TextStyle(color: Colors.red.shade700),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  /// Construye el botón para mostrar/ocultar historial
  Widget _buildHistoryToggle() {
    return InkWell(
      onTap: toggleHistory,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            showHistory ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
            size: 16,
            color: Colors.blue,
          ),
          const SizedBox(width: 4),
          Text(
            showHistory
                ? AppLocalizations.of(context)!.hideHistory
                : AppLocalizations.of(context)!.showHistory,
            style: const TextStyle(
              color: Colors.blue,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  /// Construye la sección del historial
  Widget _buildHistorySection() {
    if (!showHistory) return const SizedBox.shrink();

    return Column(
      children: [
        const SizedBox(height: 8),
        isLoadingHistory
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(8.0),
                  child: CircularProgressIndicator(),
                ),
              )
            : itemHistory.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(8.0),
                    child:
                        Text(AppLocalizations.of(context)!.noHistoryAvailable),
                  )
                : _buildHistoryList(),
        const SizedBox(height: 16),
        _buildDeleteAllButton(),
      ],
    );
  }

  /// Construye la lista del historial
  Widget _buildHistoryList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: itemHistory.map((item) => _buildHistoryItem(item)).toList(),
    );
  }

  /// Construye un elemento del historial
  Widget _buildHistoryItem(Map<String, dynamic> item) {
    final ts = item['timestamp'] is Timestamp
        ? (item['timestamp'] as Timestamp).toDate()
        : DateTime.now();

    final String typeStr = item['type'] ?? '';
    IconData icon;
    switch (typeStr) {
      case 'trolley':
        icon = Icons.shopping_cart;
        break;
      case 'spare':
        icon = Icons.inventory;
        break;
      case 'avih':
        icon = Icons.pets;
        break;
      case 'weap':
        icon = Icons.security;
        break;
      default:
        icon = Icons.local_shipping;
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: Icon(icon, size: 20, color: Colors.amber),
        title: Text(
          '${item['count'] ?? 1} ${getTypeLabel(stringToType(item['type']), AppLocalizations.of(context)!)}',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            decoration:
                (item['deleted'] ?? false) ? TextDecoration.lineThrough : null,
            color: (item['deleted'] ?? false) ? Colors.grey : null,
          ),
        ),
        subtitle: Text(FlightFormatters.formatDateTime(ts)),
        trailing: (item['deleted'] ?? false)
            ? null
            : IconButton(
                icon: const Icon(Icons.delete_outline,
                    color: Colors.red, size: 20),
                onPressed: () => showDeleteConfirmation(
                  item['id'],
                  item['count'] ?? 1,
                ),
              ),
      ),
    );
  }

  /// Construye el botón para eliminar todos los registros
  Widget _buildDeleteAllButton() {
    return Center(
      child: TextButton.icon(
        onPressed: showDeleteAllConfirmation,
        icon: const Icon(Icons.delete_forever, color: Colors.red),
        label: const Text(
          'Delete All Registries',
          style: TextStyle(color: Colors.red),
        ),
      ),
    );
  }
}
