import 'package:flutter/material.dart';
import 'dart:async';

/// Widget que muestra la hora de actualización y se actualiza automáticamente cada segundo
class TimeAgoWidget extends StatefulWidget {
  final DateTime? lastUpdated;
  final TextStyle? textStyle;
  final EdgeInsetsGeometry? padding;

  const TimeAgoWidget({
    this.lastUpdated,
    this.textStyle,
    this.padding,
    Key? key,
  }) : super(key: key);

  @override
  State<TimeAgoWidget> createState() => _TimeAgoWidgetState();
}

class _TimeAgoWidgetState extends State<TimeAgoWidget> {
  // Timer para actualizar el texto
  Timer? _updateTimeAgoTimer;

  @override
  void initState() {
    super.initState();

    // Iniciar timer para actualizar el texto cada segundo
    _updateTimeAgoTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && widget.lastUpdated != null) {
        setState(() {
          // Solo actualizar este widget específico
        });
      }
    });
  }

  @override
  void dispose() {
    _updateTimeAgoTimer?.cancel();
    super.dispose();
  }

  /// Obtener una representación legible del tiempo transcurrido
  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'hace ${difference.inSeconds} ${difference.inSeconds == 1 ? 'segundo' : 'segundos'}';
    } else if (difference.inMinutes < 60) {
      return 'hace ${difference.inMinutes} ${difference.inMinutes == 1 ? 'minuto' : 'minutos'}';
    } else if (difference.inHours < 24) {
      return 'hace ${difference.inHours} ${difference.inHours == 1 ? 'hora' : 'horas'}';
    } else {
      return 'hace ${difference.inDays} ${difference.inDays == 1 ? 'día' : 'días'}';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.lastUpdated == null) {
      return const SizedBox.shrink();
    }

    final defaultTextStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Colors.grey,
          fontSize: 12,
        );

    return Padding(
      padding:
          widget.padding ?? const EdgeInsets.only(left: 20, top: 2, bottom: 2),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          'Actualizado: ${_getTimeAgo(widget.lastUpdated!)}',
          style: widget.textStyle ?? defaultTextStyle,
        ),
      ),
    );
  }
}
