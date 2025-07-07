import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../data/activity.dart';

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

  // Círculo principal del pin
  final Paint pinPaint = Paint()
    ..color = pinColor
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

  // Círculo interior blanco
  final Paint innerCirclePaint = Paint()
    ..color = Colors.white
    ..style = PaintingStyle.fill;

  canvas.drawCircle(
    Offset(centerX, startY + 25),
    (pinWidth / 2) - 8,
    innerCirclePaint,
  );

  // Número en el centro
  final textStyle = TextStyle(
    fontSize: 24,
    color: pinColor,
    fontWeight: FontWeight.w900,
    fontFamily: 'Roboto',
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
