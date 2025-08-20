import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Utilidades para mostrar diálogos de confirmación con estilo Cupertino en
/// todas las plataformas. Devuelve `true` si el usuario confirma, `false` si
/// cancela o cierra.
class DialogUtils {
  static Future<bool?> showCupertinoConfirmation({
    required BuildContext context,
    required String title,
    required String content,
    String cancelLabel = 'Cancelar',
    String confirmLabel = 'Confirmar',
    Color? confirmColor,
  }) {
    return showCupertinoDialog<bool>(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(cancelLabel),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(true),
            isDefaultAction: true,
            isDestructiveAction: confirmColor == Colors.red,
            child: Text(
              confirmLabel,
              style:
                  confirmColor != null ? TextStyle(color: confirmColor) : null,
            ),
          ),
        ],
      ),
    );
  }
}
