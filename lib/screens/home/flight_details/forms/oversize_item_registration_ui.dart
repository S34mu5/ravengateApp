import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/flight_formatters.dart';
import '../../../../l10n/app_localizations.dart';
import 'oversize_item_registration_logic.dart';
import 'models/oversize_item_types.dart';

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
  void initState() {
    super.initState();
    // Cargar el conteo inicial para el tipo por defecto
    WidgetsBinding.instance.addPostFrameCallback((_) {
      loadCurrentCount();
    });
  }

  /// Maneja el toggle del checkbox de manejo especial
  Future<void> _handleSpecialHandlingToggle() async {
    final result =
        await showSpecialHandlingModal(context, specialHandlingDetails);
    if (result != null) {
      updateSpecialHandlingDetails(result);
    }
  }

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
            AppLocalizations.of(context)!.oversizeBaggageManagement,
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
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Text(
                    type == OversizeItemType.spare
                        ? labelText.replaceFirst(' ', '\n')
                        : labelText,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.1,
                    ),
                  ),
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
                const EdgeInsets.symmetric(horizontal: 8, vertical: 10)),
            visualDensity: VisualDensity.standard,
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
              hintText: isLoadingCurrentCount
                  ? AppLocalizations.of(context)!.loading
                  : '${AppLocalizations.of(context)!.currentLabel}: ${currentCount ?? 0}',
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
            validator: (value) =>
                validateCountField(value, AppLocalizations.of(context)!),
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Flexible(
          flex: 1,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Checkbox(
                value: isFragile,
                onChanged: (bool? value) {
                  changeFragileState(value ?? false);
                },
                activeColor: Colors.amber,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: GestureDetector(
                  onTap: () => changeFragileState(!isFragile),
                  child: Text(
                    AppLocalizations.of(context)!.fragileLabel,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
        Flexible(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Checkbox(
                    value: requiresSpecialHandling,
                    onChanged: (bool? value) {
                      if (value == true) {
                        _handleSpecialHandlingToggle();
                      } else {
                        changeSpecialHandlingState(false);
                      }
                    },
                    activeColor: Colors.amber,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        if (!requiresSpecialHandling) {
                          _handleSpecialHandlingToggle();
                        } else {
                          changeSpecialHandlingState(false);
                        }
                      },
                      child: Text(
                        AppLocalizations.of(context)!
                            .requiresSpecialHandlingLabel,
                        style: TextStyle(
                          color: requiresSpecialHandling
                              ? Colors.amber.shade700
                              : null,
                          fontWeight:
                              requiresSpecialHandling ? FontWeight.w500 : null,
                          fontSize: 14,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
              if (requiresSpecialHandling && specialHandlingDetails.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 24),
                  child: Text(
                    specialHandlingDetails,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
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
    final groupedHistory = groupItemHistory(itemHistory);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: groupedHistory.map((item) => _buildHistoryItem(item)).toList(),
    );
  }

  /// Construye un elemento del historial
  Widget _buildHistoryItem(Map<String, dynamic> item) {
    final ts = processTimestamp(item['timestamp']);
    final bool isConverted = item['converted'] ?? false;
    final bool isDeleted = (item['deleted'] ?? false) && !isConverted;
    final DateTime? deletedAt = item['deleted_at'] != null
        ? processTimestamp(item['deleted_at'])
        : null;
    final String? deletedByEmail = item['deleted_by_user_email'];

    final String typeStr = (item['type'] as String?)?.isNotEmpty == true
        ? item['type'] as String
        : selectedType.name;

    final IconData icon = getIconForType(typeStr);
    final Color iconColor = getIconColor(isConverted, isDeleted);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: Icon(icon, size: 20, color: iconColor),
        title: Text(
          buildItemTitle(item, typeStr, AppLocalizations.of(context)!),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            decoration: isDeleted ? TextDecoration.lineThrough : null,
            color: isDeleted ? Colors.grey : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              buildItemSubtitle(item, ts, AppLocalizations.of(context)!),
              style: TextStyle(
                fontSize: 12,
                color: isDeleted ? Colors.grey : Colors.grey.shade600,
              ),
            ),
            // Mostrar información adicional si existe
            if (item['is_fragile'] == true) ...[
              const SizedBox(height: 2),
              Row(
                children: [
                  Icon(
                    Icons.warning,
                    size: 14,
                    color: isDeleted ? Colors.grey : Colors.orange,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    AppLocalizations.of(context)!.fragileLabel,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDeleted ? Colors.grey : Colors.orange,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
            if (item['requires_special_handling'] == true) ...[
              const SizedBox(height: 2),
              Row(
                children: [
                  Icon(
                    Icons.priority_high,
                    size: 14,
                    color: isDeleted ? Colors.grey : Colors.red,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    AppLocalizations.of(context)!.requiresSpecialHandlingLabel,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDeleted ? Colors.grey : Colors.red,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
            if (item['special_handling_details'] != null &&
                (item['special_handling_details'] as String).isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                '${AppLocalizations.of(context)!.details}: ${item['special_handling_details']}',
                style: TextStyle(
                  fontSize: 11,
                  color: isDeleted ? Colors.grey : Colors.grey.shade700,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            if (isDeleted && deletedAt != null) ...[
              const SizedBox(height: 2),
              Text(
                '${AppLocalizations.of(context)!.deletedLabel}: ${FlightFormatters.formatDateTime(deletedAt)}',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.red,
                  fontStyle: FontStyle.italic,
                ),
              ),
              if (deletedByEmail != null)
                Text(
                  '${AppLocalizations.of(context)!.byLabel}: $deletedByEmail',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.red,
                    fontStyle: FontStyle.italic,
                  ),
                ),
            ],
          ],
        ),
        trailing: isDeleted
            ? Icon(Icons.delete, color: Colors.grey.shade400, size: 20)
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
        label: Text(
          AppLocalizations.of(context)!.deleteAllRegistries,
          style: const TextStyle(color: Colors.red),
        ),
      ),
    );
  }
}
