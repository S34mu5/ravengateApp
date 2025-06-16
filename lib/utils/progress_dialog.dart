import 'package:flutter/material.dart';

/// Tipos de diálogo de progreso
enum ProgressDialogType {
  normal,
  download,
}

/// Diálogo de progreso simple para mostrar durante operaciones largas
class ProgressDialog {
  final BuildContext context;
  final ProgressDialogType type;
  final bool isDismissible;

  BuildContext? _dismissingContext;
  bool _isShowing = false;
  bool _barrierDismissible = true;
  double _dialogElevation = 8.0;
  String _dialogMessage = 'Loading...';
  Widget? _progressWidget;
  Color _backgroundColor = Colors.white;
  Curve _insetAnimCurve = Curves.easeInOut;
  EdgeInsets _dialogPadding = const EdgeInsets.all(8.0);
  double _borderRadius = 8.0;

  /// Constructor
  ProgressDialog(
    this.context, {
    this.type = ProgressDialogType.normal,
    this.isDismissible = true,
  }) {
    _barrierDismissible = isDismissible;
  }

  /// Configurar el estilo del diálogo
  void style({
    String? message,
    Widget? progressWidget,
    double? elevation,
    Color? backgroundColor,
    Curve? insetAnimCurve,
    EdgeInsets? padding,
    double? borderRadius,
  }) {
    _dialogMessage = message ?? _dialogMessage;
    _progressWidget =
        progressWidget ?? _progressWidget ?? const CircularProgressIndicator();
    _dialogElevation = elevation ?? _dialogElevation;
    _backgroundColor = backgroundColor ?? _backgroundColor;
    _insetAnimCurve = insetAnimCurve ?? _insetAnimCurve;
    _dialogPadding = padding ?? _dialogPadding;
    _borderRadius = borderRadius ?? _borderRadius;
  }

  /// Mostrar el diálogo
  Future<bool> show() async {
    try {
      if (_isShowing) {
        return false;
      }

      _isShowing = true;

      showDialog<dynamic>(
        context: context,
        barrierDismissible: _barrierDismissible,
        builder: (BuildContext buildContext) {
          _dismissingContext = buildContext;
          return PopScope<Object?>(
            canPop: isDismissible,
            onPopInvokedWithResult: (_, __) {},
            child: Dialog(
              elevation: _dialogElevation,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(_borderRadius),
              ),
              child: Container(
                padding: _dialogPadding,
                decoration: BoxDecoration(
                  color: _backgroundColor,
                  borderRadius: BorderRadius.circular(_borderRadius),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _progressWidget!,
                    const SizedBox(width: 16),
                    Flexible(
                      child: Text(
                        _dialogMessage,
                        style: Theme.of(context).textTheme.bodyLarge,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );

      return true;
    } catch (e) {
      _isShowing = false;
      debugPrint('Error showing dialog: $e');
      return false;
    }
  }

  /// Ocultar el diálogo
  Future<bool> hide() async {
    try {
      if (!_isShowing) {
        return false;
      }

      _isShowing = false;

      if (_dismissingContext != null) {
        if (_dismissingContext!.mounted) {
          Navigator.of(_dismissingContext!).pop();
        } else {
          debugPrint(
              'Warning: Context was already unmounted when hiding dialog');
        }
        _dismissingContext = null;
      }

      return true;
    } catch (e) {
      debugPrint('Error hiding dialog: $e');
      return false;
    }
  }

  /// Comprobar si el diálogo está mostrándose
  bool get isShowing => _isShowing;
}
