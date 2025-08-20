import 'package:tourify_flutter/services/analytics_service.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:clarity_flutter/clarity_flutter.dart';

class PremiumFeatureModal extends StatelessWidget {
  final String? source;

  const PremiumFeatureModal({
    super.key,
    this.source,
  });

  @override
  Widget build(BuildContext context) {
    // 📊 TRACKING: Registrar vista del modal premium
    AnalyticsService.trackEvent('premium_modal_opened', parameters: {
      'source': source ?? 'unknown',
    }).catchError((e) => debugPrint('Error tracking premium modal: $e'));

    // 📊 CLARITY: Enviar evento personalizado para modal premium
    try {
      Clarity.sendCustomEvent('premium_modal_opened');
      debugPrint(
          '🔍 Clarity: premium_modal_opened sent from ${source ?? 'unknown'}');
    } catch (e) {
      debugPrint('⚠️ Error sending Clarity event: $e');
    }

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0062FF), Color(0xFF0046CC)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.rocket_launch,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              '¡Hazte Premium!',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0062FF),
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Color(0xFFFFC107),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Column(
              children: [
                Text(
                  'Solo 5 €/mes',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Accede a todas las funciones premium',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Ventajas de ser Premium:',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0062FF),
            ),
          ),
          const SizedBox(height: 12),
          _PremiumFeature(
            icon: Icons.smart_toy,
            title: 'Asistente de viaje',
            description: 'Ayuda instantánea durante tu viaje',
          ),
          const SizedBox(height: 8),
          _PremiumFeature(
            icon: Icons.cloud_off,
            title: 'Uso sin conexión',
            description: 'Accede a tus guías sin internet',
          ),
          const SizedBox(height: 8),
          _PremiumFeature(
            icon: Icons.map,
            title: 'Exportación a Google Maps',
            description: 'Exporta tu itinerario directamente a Maps',
          ),
          const SizedBox(height: 8),
          _PremiumFeature(
            icon: Icons.calendar_today,
            title: 'Sincronización con calendar',
            description: 'Conecta tus viajes con tu agenda',
          ),
        ],
      ),
      actions: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: TextButton(
                onPressed: () {
                  // 📊 CLARITY: Enviar evento personalizado para cerrar modal
                  try {
                    Clarity.sendCustomEvent('premium_modal_dismissed');
                    debugPrint('🔍 Clarity: premium_modal_dismissed sent');
                  } catch (e) {
                    debugPrint('⚠️ Error sending Clarity dismiss event: $e');
                  }

                  Navigator.pop(context);
                },
                child: const Text(
                  'Entendido',
                  style: TextStyle(
                    color: Color(0xFF0062FF),
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFFFFC107),
                  foregroundColor: Colors.black,
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(10)),
                  ),
                  textStyle: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.bold),
                ),
                onPressed: () {
                  // 📊 TRACKING: Registrar clic en botón de pagar
                  AnalyticsService.trackPremiumPaymentClick(
                          source ?? 'feature_modal')
                      .catchError((e) =>
                          debugPrint('Error tracking payment click: $e'));

                  // 📊 CLARITY: Enviar evento personalizado para clic en pagar
                  try {
                    Clarity.sendCustomEvent('premium_payment_click');
                    if (source != null) {
                      Clarity.setCustomTag('premium_click_source', source!);
                    }
                    debugPrint(
                        '🔍 Clarity: premium_payment_click sent from ${source ?? 'feature_modal'}');
                  } catch (e) {
                    debugPrint(
                        '⚠️ Error sending Clarity payment click event: $e');
                  }

                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('¡Próximamente!'),
                      content: const Text(
                          'La funcionalidad de pago aún no está desarrollada. Cuando esté disponible, tendrás un mes gratis para probar todas las funciones premium.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cerrar'),
                        ),
                      ],
                    ),
                  );
                },
                icon: const Icon(Icons.payment, size: 18),
                label: const Text(
                  'Pagar 5 €/mes',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PremiumFeature extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _PremiumFeature({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          color: Colors.black,
          size: 24,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.black,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
