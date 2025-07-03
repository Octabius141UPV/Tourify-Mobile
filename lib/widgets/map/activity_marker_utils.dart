import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

String limpiarNombreActividad(String nombre) {
  final palabrasProhibidas = [
    'tour', 'paseo', 'nocturno', 'ruta', 'visita', 'recorrido', 'guía', 'guiado',
    'experiencia', 'descubrimiento', 'exploración', 'actividad', 'evento',
    'cultural', 'histórico', 'gastronómico', 'deportivo', 'familiar', 'divertido',
    'panorámico', 'temático', 'por', 'en', 'de', 'del', 'la', 'el', 'los', 'las'
  ];
  var limpio = nombre;
  for (final palabra in palabrasProhibidas) {
    limpio = limpio.replaceAll(RegExp('\\b$palabra\\b', caseSensitive: false), '');
  }
  limpio = limpio.replaceAll(RegExp(' +'), ' ').trim();
  return limpio;
}

Future<BitmapDescriptor> createNumberedMarker(int number, {bool selected = true}) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final Canvas canvas = Canvas(recorder);
  const double size = 90.0;
  final Paint paint = Paint()..color = selected ? const Color(0xFF0062FF) : const Color(0xFFB0B0B0);
  canvas.drawCircle(const Offset(size/2, size/2), size/2, paint);
  final textPainter = TextPainter(
    text: TextSpan(
      text: number.toString(),
      style: const TextStyle(
        fontSize: 40,
        color: Colors.white,
        fontWeight: FontWeight.bold,
      ),
    ),
    textDirection: TextDirection.ltr,
  );
  textPainter.layout();
  textPainter.paint(
    canvas,
    Offset((size - textPainter.width) / 2, (size - textPainter.height) / 2),
  );
  final img = await recorder.endRecording().toImage(size.toInt(), size.toInt());
  final data = await img.toByteData(format: ui.ImageByteFormat.png);
  return BitmapDescriptor.fromBytes(data!.buffer.asUint8List());
} 