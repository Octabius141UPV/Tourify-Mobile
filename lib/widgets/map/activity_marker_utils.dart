import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:tourify_flutter/data/activity.dart';
import 'package:tourify_flutter/config/app_colors.dart';

/// Configuración global: usar pines "clásicos numerados" (aspecto estándar con número).
const bool kUseClassicNumberedPins = true;

/// Tamaño base en píxeles del pin clásico numerado.
const double _kClassicPinSize = 150.0; // más grande para mejor legibilidad
const double _kClassicPinWidth = 72.0; // diámetro del círculo
const double _kClassicPinHeight = 110.0; // hasta la punta

/// Genera un pin clásico con número centrado.
Future<BitmapDescriptor> _createClassicNumberedPin(
    int number, Color color) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final Canvas canvas = Canvas(recorder);

  const double size = 180.0; // Más grande aún
  const double centerX = size / 2;
  const double centerY = size / 2;
  const double borderWidth = 5.0; // Borde un poco más grueso

  // ----- BORDE BLANCO -----
  final Paint borderPaint = Paint()
    ..color = Colors.white
    ..style = PaintingStyle.fill;

  // Círculo del borde blanco (más grande)
  canvas.drawCircle(
    Offset(centerX, centerY - 12),
    44.0 + borderWidth,
    borderPaint,
  );

  // Punta del borde blanco (triángulo más grande)
  final Path borderPath = Path();
  borderPath.moveTo(centerX - 22 - borderWidth, centerY + 20);
  borderPath.lineTo(centerX, centerY + 50);
  borderPath.lineTo(centerX + 22 + borderWidth, centerY + 20);
  borderPath.close();
  canvas.drawPath(borderPath, borderPaint);

  // ----- PIN DE COLOR -----
  final Paint pinPaint = Paint()
    ..color = color
    ..style = PaintingStyle.fill;

  // Círculo principal
  canvas.drawCircle(
    Offset(centerX, centerY - 12),
    44.0,
    pinPaint,
  );

  // Punta del pin (triángulo)
  final Path pinPath = Path();
  pinPath.moveTo(centerX - 22, centerY + 20);
  pinPath.lineTo(centerX, centerY + 45);
  pinPath.lineTo(centerX + 22, centerY + 20);
  pinPath.close();
  canvas.drawPath(pinPath, pinPaint);

  // ----- CÍRCULO BLANCO PARA EL NÚMERO -----
  final Paint numberBgPaint = Paint()
    ..color = Colors.white
    ..style = PaintingStyle.fill;

  canvas.drawCircle(
    Offset(centerX, centerY - 12),
    28.0, // Círculo más grande para el número
    numberBgPaint,
  );

  // ----- NÚMERO -----
  final textPainter = TextPainter(
    text: TextSpan(
      text: number.toString(),
      style: TextStyle(
        color: color,
        fontSize: 32.0, // Texto más grande
        fontWeight: FontWeight.bold,
      ),
    ),
    textDirection: TextDirection.ltr,
  );

  textPainter.layout();
  final textOffset = Offset(
    centerX - textPainter.width / 2,
    centerY - 12 - textPainter.height / 2,
  );
  textPainter.paint(canvas, textOffset);

  // Convertir a imagen
  final ui.Picture picture = recorder.endRecording();
  final ui.Image image = await picture.toImage(size.toInt(), size.toInt());
  final ByteData? byteData =
      await image.toByteData(format: ui.ImageByteFormat.png);
  final Uint8List bytes = byteData!.buffer.asUint8List();

  return BitmapDescriptor.fromBytes(bytes);
}

String limpiarNombreActividad(String nombre) {
  final palabrasProhibidas = [
    'tour',
    'paseo',
    'nocturno',
    'ruta',
    'visita',
    'recorrido',
    'guía',
    'guiado',
    'experiencia',
    'descubrimiento',
    'exploración',
    'actividad',
    'evento',
    'cultural',
    'histórico',
    'gastronómico',
    'deportivo',
    'familiar',
    'divertido',
    'panorámico',
    'temático',
    'por',
    'en',
    'de',
    'del',
    'la',
    'el',
    'los',
    'las'
  ];
  var limpio = nombre;
  for (final palabra in palabrasProhibidas) {
    limpio =
        limpio.replaceAll(RegExp('\\b$palabra\\b', caseSensitive: false), '');
  }
  limpio = limpio.replaceAll(RegExp(' +'), ' ').trim();
  return limpio;
}

/// Crea un marcador tradicional en forma de pin de mapa con número
Future<BitmapDescriptor> createNumberedMarker(int number,
    {bool selected = true, Color? color, Activity? activity}) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final Canvas canvas = Canvas(recorder);
  const double size = 100.0;
  const double pinWidth = 60.0;
  const double pinHeight = 80.0;
  const double centerX = size / 2;
  const double startY = 10.0;

  // Color del marcador
  final Color pinColor =
      color ?? (selected ? const Color(0xFF0062FF) : const Color(0xFFB0B0B0));

  // Sombra del pin
  final Paint shadowPaint = Paint()
    ..color = Colors.black.withOpacity(0.3)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8.0);

  // Dibujar sombra del pin
  final Path shadowPath = Path();
  shadowPath.addOval(Rect.fromCenter(
    center: Offset(centerX + 2, startY + 25 + 2),
    width: pinWidth - 8,
    height: pinWidth - 8,
  ));
  shadowPath.moveTo(centerX + 2, startY + pinHeight - 10 + 2);
  shadowPath.lineTo(centerX + 2, startY + pinHeight + 10 + 2);
  canvas.drawPath(shadowPath, shadowPaint);

  // Borde blanco del pin
  final Paint borderPaint = Paint()
    ..color = Colors.white
    ..style = PaintingStyle.fill;

  // Círculo superior con borde blanco
  canvas.drawCircle(
    Offset(centerX, startY + 25),
    (pinWidth / 2) + 2,
    borderPaint,
  );

  // Punta del pin con borde blanco
  final Path borderPinPath = Path();
  borderPinPath.moveTo(centerX - 15, startY + 45);
  borderPinPath.lineTo(centerX, startY + pinHeight);
  borderPinPath.lineTo(centerX + 15, startY + 45);
  borderPinPath.close();
  canvas.drawPath(borderPinPath, borderPaint);

  // Crear colores más claros y más oscuros para un degradado más rico
  final hsl = HSLColor.fromColor(pinColor);
  final lighter =
      hsl.withLightness((hsl.lightness + 0.18).clamp(0.0, 1.0)).toColor();
  final darker =
      hsl.withLightness((hsl.lightness - 0.18).clamp(0.0, 1.0)).toColor();

  // Círculo principal del pin con degradado realista (de arriba a abajo)
  final Paint pinPaint = Paint()
    ..shader = ui.Gradient.linear(
      Offset(centerX, startY),
      Offset(centerX, startY + 50),
      [lighter, pinColor, darker],
      [0.0, 0.5, 1.0],
    )
    ..style = PaintingStyle.fill;

  canvas.drawCircle(
    Offset(centerX, startY + 25),
    pinWidth / 2,
    pinPaint,
  );

  // Punta del pin
  final Path pinPath = Path();
  pinPath.moveTo(centerX - 12, startY + 43);
  pinPath.lineTo(centerX, startY + pinHeight - 3);
  pinPath.lineTo(centerX + 12, startY + 43);
  pinPath.close();
  canvas.drawPath(pinPath, pinPaint);

  // Círculo interior translúcido para un borde suave
  final Paint innerCirclePaint = Paint()
    ..color = Colors.white.withOpacity(0.9)
    ..style = PaintingStyle.fill;

  canvas.drawCircle(
    Offset(centerX, startY + 25),
    (pinWidth / 2) - 8,
    innerCirclePaint,
  );

  // Brillo superior (efecto glossy)
  final glossPaint = Paint()
    ..shader = ui.Gradient.linear(
      Offset(centerX, startY + 8),
      Offset(centerX, startY + 25),
      [Colors.white.withOpacity(0.6), Colors.white.withOpacity(0.0)],
    );
  canvas.drawCircle(
    Offset(centerX, startY + 25),
    (pinWidth / 2) - 8,
    glossPaint,
  );

  // Número en el centro
  final textStyle = TextStyle(
    fontSize: 24,
    color: Colors.white,
    fontWeight: FontWeight.w900,
    fontFamily: 'Roboto',
    shadows: [
      const Shadow(offset: Offset(0, 1), blurRadius: 2, color: Colors.black45),
    ],
  );

  final textSpan = TextSpan(text: number.toString(), style: textStyle);
  final textPainter = TextPainter(
    text: textSpan,
    textDirection: TextDirection.ltr,
    textAlign: TextAlign.center,
  );

  textPainter.layout();
  textPainter.paint(
    canvas,
    Offset(
      centerX - (textPainter.width / 2),
      startY + 25 - (textPainter.height / 2),
    ),
  );

  // Indicador de duración en la parte inferior (opcional)
  if (activity != null && selected) {
    final durationText = '${activity.duration}min';
    final durationStyle = TextStyle(
      fontSize: 10,
      color: Colors.white,
      fontWeight: FontWeight.w700,
      shadows: [
        Shadow(
          offset: const Offset(1, 1),
          blurRadius: 2,
          color: Colors.black.withOpacity(0.8),
        ),
      ],
    );

    final durationSpan = TextSpan(text: durationText, style: durationStyle);
    final durationPainter = TextPainter(
      text: durationSpan,
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    durationPainter.layout();

    // Fondo para la duración
    final durationBgPaint = Paint()..color = pinColor.withOpacity(0.9);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(centerX, size - 8),
          width: durationPainter.width + 8,
          height: 14,
        ),
        const Radius.circular(7),
      ),
      durationBgPaint,
    );

    durationPainter.paint(
      canvas,
      Offset(
        centerX - (durationPainter.width / 2),
        size - 15,
      ),
    );
  }

  final img = await recorder.endRecording().toImage(size.toInt(), size.toInt());
  final data = await img.toByteData(format: ui.ImageByteFormat.png);
  return BitmapDescriptor.fromBytes(data!.buffer.asUint8List());
}

/// Crea un marcador temático basado en la categoría de la actividad
Future<BitmapDescriptor> createCategoryMarker(Activity activity, int number,
    {bool selected = true, Color? baseColor}) async {
  // Colores por categoría
  final categoryInfo = _getCategoryInfo(activity.category);
  // Si baseColor está definido, se usa para el pin (por ejemplo, para colorear por día)
  final color = baseColor ?? categoryInfo['color'] as Color;

  // Si se ha activado el modo clásico numerado, generar pin sencillo con número
  if (kUseClassicNumberedPins) {
    return _createClassicNumberedPin(number, color);
  }

  return createNumberedMarker(
    number,
    selected: selected,
    color: color,
    activity: activity,
  );
}

/// Obtiene información de categoría (color e icono)
Map<String, dynamic> _getCategoryInfo(String? category) {
  switch (category?.toLowerCase()) {
    case 'cultura':
    case 'cultural':
      return {'color': const Color(0xFF8E24AA), 'icon': Icons.museum};
    case 'gastronomia':
    case 'gastronómico':
    case 'comida':
      return {'color': const Color(0xFFFF5722), 'icon': Icons.restaurant};
    case 'naturaleza':
    case 'parque':
      return {'color': const Color(0xFF4CAF50), 'icon': Icons.park};
    case 'entretenimiento':
    case 'diversión':
      return {'color': const Color(0xFFFF9800), 'icon': Icons.celebration};
    case 'compras':
    case 'shopping':
      return {'color': const Color(0xFFE91E63), 'icon': Icons.shopping_bag};
    case 'religioso':
    case 'religión':
      return {'color': const Color(0xFF795548), 'icon': Icons.church};
    case 'deporte':
    case 'deportivo':
      return {'color': const Color(0xFF2196F3), 'icon': Icons.sports};
    case 'transporte':
      return {'color': const Color(0xFF607D8B), 'icon': Icons.directions};
    default:
      return {'color': const Color(0xFF0062FF), 'icon': Icons.place};
  }
}

/// Información para diferentes tipos de POI
Map<String, dynamic> _getPOIInfo(String type) {
  switch (type.toLowerCase()) {
    case 'hotel':
    case 'alojamiento':
      return {
        'icon': Icons.hotel,
        'color': const Color(0xFF673AB7),
        'label': 'Hotel',
      };
    case 'aeropuerto':
    case 'airport':
      return {
        'icon': Icons.flight,
        'color': const Color(0xFF607D8B),
        'label': 'Aeropuerto',
      };
    case 'estacion':
    case 'train':
      return {
        'icon': Icons.train,
        'color': const Color(0xFF795548),
        'label': 'Estación',
      };
    case 'parking':
    case 'aparcamiento':
      return {
        'icon': Icons.local_parking,
        'color': const Color(0xFF9E9E9E),
        'label': 'Parking',
      };
    case 'informacion':
    case 'info':
      return {
        'icon': Icons.info,
        'color': const Color(0xFF2196F3),
        'label': 'Info',
      };
    default:
      return {
        'icon': Icons.place,
        'color': const Color(0xFF0062FF),
        'label': null,
      };
  }
}

/// Crea un marcador con pulso animado (para ubicación activa)
Future<BitmapDescriptor> createPulsingMarker(
    Activity activity, int number) async {
  return createNumberedMarker(
    number,
    selected: true,
    color: const Color(0xFFFF4444), // Rojo llamativo
    activity: activity,
  );
}

/// Crea un pin especial para ubicaciones importantes
Future<BitmapDescriptor> createSpecialPin({
  required String text,
  required Color color,
  IconData? icon,
  bool withShadow = true,
}) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final Canvas canvas = Canvas(recorder);
  const double size = 100.0;
  const double pinWidth = 60.0;
  const double pinHeight = 80.0;
  const double centerX = size / 2;
  const double startY = 10.0;

  if (withShadow) {
    // Sombra del pin
    final Paint shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8.0);

    final Path shadowPath = Path();
    shadowPath.addOval(Rect.fromCenter(
      center: Offset(centerX + 2, startY + 25 + 2),
      width: pinWidth - 8,
      height: pinWidth - 8,
    ));
    shadowPath.moveTo(centerX + 2, startY + pinHeight - 10 + 2);
    shadowPath.lineTo(centerX + 2, startY + pinHeight + 10 + 2);
    canvas.drawPath(shadowPath, shadowPaint);
  }

  // Borde blanco del pin
  final Paint borderPaint = Paint()
    ..color = Colors.white
    ..style = PaintingStyle.fill;

  canvas.drawCircle(
    Offset(centerX, startY + 25),
    (pinWidth / 2) + 2,
    borderPaint,
  );

  final Path borderPinPath = Path();
  borderPinPath.moveTo(centerX - 15, startY + 45);
  borderPinPath.lineTo(centerX, startY + pinHeight);
  borderPinPath.lineTo(centerX + 15, startY + 45);
  borderPinPath.close();
  canvas.drawPath(borderPinPath, borderPaint);

  // Pin principal
  final Paint pinPaint = Paint()
    ..color = color
    ..style = PaintingStyle.fill;

  canvas.drawCircle(
    Offset(centerX, startY + 25),
    pinWidth / 2,
    pinPaint,
  );

  final Path pinPath = Path();
  pinPath.moveTo(centerX - 12, startY + 43);
  pinPath.lineTo(centerX, startY + pinHeight - 3);
  pinPath.lineTo(centerX + 12, startY + 43);
  pinPath.close();
  canvas.drawPath(pinPath, pinPaint);

  // Contenido del pin
  if (icon != null) {
    // Mostrar icono
    final textPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontFamily: icon.fontFamily,
          fontSize: 28,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        centerX - (textPainter.width / 2),
        startY + 25 - (textPainter.height / 2),
      ),
    );
  } else {
    // Mostrar texto
    final textStyle = TextStyle(
      fontSize: text.length > 2 ? 16 : 24,
      color: Colors.white,
      fontWeight: FontWeight.w900,
      fontFamily: 'Roboto',
    );

    final textSpan = TextSpan(text: text, style: textStyle);
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        centerX - (textPainter.width / 2),
        startY + 25 - (textPainter.height / 2),
      ),
    );
  }

  final img = await recorder.endRecording().toImage(size.toInt(), size.toInt());
  final data = await img.toByteData(format: ui.ImageByteFormat.png);
  return BitmapDescriptor.fromBytes(data!.buffer.asUint8List());
}

/// Crea un pin para la ubicación actual del usuario
Future<BitmapDescriptor> createUserLocationPin() async {
  return createSpecialPin(
    text: 'TÚ',
    color: const Color(0xFF4285F4), // Azul Google
    withShadow: true,
  );
}

/// Crea un pin de punto de interés
Future<BitmapDescriptor> createPOIPin(String type) async {
  final info = _getPOIInfo(type);
  return createSpecialPin(
    text: '',
    color: info['color'] as Color,
    icon: info['icon'] as IconData,
  );
}
