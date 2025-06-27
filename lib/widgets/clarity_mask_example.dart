import 'package:flutter/material.dart';
import 'package:clarity_flutter/clarity_flutter.dart';

/// Ejemplo de cómo usar los widgets de enmascaramiento de Clarity
/// para proteger información sensible en las grabaciones
class ClarityMaskExample extends StatelessWidget {
  const ClarityMaskExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ejemplo de Enmascaramiento Clarity'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Información visible en grabaciones:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
                'Esta información será visible en las grabaciones de Clarity.'),

            const SizedBox(height: 30),

            const Text(
              'Información sensible (enmascarada):',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            // Ejemplo de enmascaramiento - información sensible
            ClarityMask(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.red),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Email: usuario@ejemplo.com'),
                    Text('Teléfono: +34 123 456 789'),
                    Text('Tarjeta: **** **** **** 1234'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 30),

            const Text(
              'Área enmascarada con contenido específico visible:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            // Ejemplo de área enmascarada con contenido específico desenmascarado
            ClarityMask(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.orange),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Esta información está enmascarada'),
                    const Text('Datos sensibles: XXXX-XXXX-XXXX'),
                    const SizedBox(height: 10),
                    // Desenmascarar información específica no sensible
                    ClarityUnmask(
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Esta parte específica SÍ será visible en las grabaciones',
                          style: TextStyle(
                              color: Colors.green, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 30),

            const Text(
              'Notas importantes:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 5),
            const Text(
              '• ClarityMask: Enmascara contenido sensible\n'
              '• ClarityUnmask: Revela contenido específico dentro de un área enmascarada\n'
              '• Úsalos para proteger datos personales, financieros o confidenciales',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
