import 'package:flutter/material.dart';

class CivitatisSvgLogo extends StatelessWidget {
  final double width;
  final double height;
  final Color color;

  const CivitatisSvgLogo({
    super.key,
    this.width = 28,
    this.height = 28,
    this.color = const Color(0xFFFF0055),
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: CivitatisPainter(color: color),
      ),
    );
  }
}

class CivitatisPainter extends CustomPainter {
  final Color color;

  CivitatisPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final whitePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    // Círculo de fondo
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.width / 2,
      paint,
    );

    // Letra "t" de Civitatis en blanco (basado en el SVG original)
    final path = Path();

    // Normalizar coordenadas basándose en el tamaño del widget (viewBox 0 0 28 28)
    final scaleX = size.width / 28;
    final scaleY = size.height / 28;

    // Path de la "t" de Civitatis:
    // "M19.5 19.1C18.7 19.7 17.7 20.1 16.6 20.1C14.2 20.1 12.3 18.2 12.3 15.8V10.5H15.1V8.5H12.3V6.5H10.3V8.5H8.5V10.5H10.3V15.8C10.3 18.9 12.9 21.5 16 21.5C17.4 21.5 18.7 21 19.7 20.2L19.5 19.1Z"

    path.moveTo(19.5 * scaleX, 19.1 * scaleY);
    path.cubicTo(18.7 * scaleX, 19.7 * scaleY, 17.7 * scaleX, 20.1 * scaleY,
        16.6 * scaleX, 20.1 * scaleY);
    path.cubicTo(14.2 * scaleX, 20.1 * scaleY, 12.3 * scaleX, 18.2 * scaleY,
        12.3 * scaleX, 15.8 * scaleY);
    path.lineTo(12.3 * scaleX, 10.5 * scaleY);
    path.lineTo(15.1 * scaleX, 10.5 * scaleY);
    path.lineTo(15.1 * scaleX, 8.5 * scaleY);
    path.lineTo(12.3 * scaleX, 8.5 * scaleY);
    path.lineTo(12.3 * scaleX, 6.5 * scaleY);
    path.lineTo(10.3 * scaleX, 6.5 * scaleY);
    path.lineTo(10.3 * scaleX, 8.5 * scaleY);
    path.lineTo(8.5 * scaleX, 8.5 * scaleY);
    path.lineTo(8.5 * scaleX, 10.5 * scaleY);
    path.lineTo(10.3 * scaleX, 10.5 * scaleY);
    path.lineTo(10.3 * scaleX, 15.8 * scaleY);
    path.cubicTo(10.3 * scaleX, 18.9 * scaleY, 12.9 * scaleX, 21.5 * scaleY,
        16 * scaleX, 21.5 * scaleY);
    path.cubicTo(17.4 * scaleX, 21.5 * scaleY, 18.7 * scaleX, 21 * scaleY,
        19.7 * scaleX, 20.2 * scaleY);
    path.lineTo(19.5 * scaleX, 19.1 * scaleY);
    path.close();

    canvas.drawPath(path, whitePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
