import 'package:tourify_flutter/services/analytics_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:clarity_flutter/clarity_flutter.dart';
import 'package:tourify_flutter/providers/premium_provider.dart';
import 'package:tourify_flutter/utils/premium_utils.dart';

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

    return Consumer<PremiumProvider>(
      builder: (context, premiumProvider, child) {
        // Si ya es premium, mostrar mensaje diferente
        if (premiumProvider.isPremium) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    '¡Ya eres Premium!',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ),
              ],
            ),
            content: const Text(
              'Ya tienes acceso a todas las funciones premium de Tourify. ¡Disfrútalas!',
              style: TextStyle(fontSize: 16),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Continuar'),
              ),
            ],
          );
        }

        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
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
              // Precio dinámico basado en RevenueCat
              _buildPriceContainer(premiumProvider),
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
                        debugPrint(
                            '⚠️ Error sending Clarity dismiss event: $e');
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
                  child: _buildPurchaseButton(context, premiumProvider),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildPriceContainer(PremiumProvider premiumProvider) {
    final monthlyPackage = premiumProvider.getMonthlyPackage();
    final hasTrialPackage = premiumProvider.getTrialPackage() != null;

    String priceText = '5 €/mes'; // Precio por defecto
    String subtitleText = 'Accede a todas las funciones premium';

    if (monthlyPackage != null) {
      priceText = premiumProvider.getFormattedPrice(monthlyPackage) + '/mes';
    }

    if (hasTrialPackage) {
      subtitleText = 'Prueba gratis, luego $priceText';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFC107),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                priceText,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              if (hasTrialPackage) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'PRUEBA',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            subtitleText,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPurchaseButton(
      BuildContext context, PremiumProvider premiumProvider) {
    if (premiumProvider.isLoading) {
      return ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFFC107),
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(10)),
          ),
        ),
        onPressed: null,
        child: const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    // Intentar compra rápida si hay paquetes disponibles
    final packages = premiumProvider.getAvailablePackages();
    final hasPackages = packages.isNotEmpty;

    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFFFC107),
        foregroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
        ),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
      ),
      onPressed: () =>
          _handlePurchaseClick(context, premiumProvider, hasPackages),
      icon: const Icon(Icons.payment, size: 18),
      label: Text(
        hasPackages ? 'Suscribirse' : 'Ver opciones',
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    );
  }

  void _handlePurchaseClick(
      BuildContext context, PremiumProvider premiumProvider, bool hasPackages) {
    // 📊 TRACKING: Registrar clic en botón de pagar
    AnalyticsService.trackPremiumPaymentClick(source ?? 'feature_modal')
        .catchError((e) => debugPrint('Error tracking payment click: $e'));

    // 📊 CLARITY: Enviar evento personalizado para clic en pagar
    try {
      Clarity.sendCustomEvent('premium_payment_click');
      if (source != null) {
        Clarity.setCustomTag('premium_click_source', source!);
      }
      debugPrint(
          '🔍 Clarity: premium_payment_click sent from ${source ?? 'feature_modal'}');
    } catch (e) {
      debugPrint('⚠️ Error sending Clarity payment click event: $e');
    }

    if (hasPackages) {
      // Intentar compra rápida del primer paquete disponible (normalmente el monthly)
      final packages = premiumProvider.getAvailablePackages();
      final preferredPackage = premiumProvider.getTrialPackage() ??
          premiumProvider.getMonthlyPackage() ??
          packages.first;

      _attemptQuickPurchase(context, premiumProvider, preferredPackage);
    } else {
      // Cerrar modal y mostrar paywall de RevenueCat
      Navigator.pop(context);
      _showRevenueCatPaywall(context);
    }
  }

  Future<void> _attemptQuickPurchase(
    BuildContext context,
    PremiumProvider premiumProvider,
    Package package,
  ) async {
    try {
      final success = await premiumProvider.purchaseProduct(
        package,
        source: source ?? 'feature_modal',
      );

      if (!context.mounted) return;

      if (success) {
        // Cerrar modal y mostrar éxito
        Navigator.pop(context);
        _showSuccessDialog(context);
      } else {
        // Cerrar modal y mostrar paywall de RevenueCat
        Navigator.pop(context);
        _showRevenueCatPaywall(context);
      }
    } catch (e) {
      if (!context.mounted) return;

      // Cerrar modal y mostrar paywall de RevenueCat
      Navigator.pop(context);
      _showRevenueCatPaywall(context);
    }
  }

  Future<void> _showRevenueCatPaywall(BuildContext context) async {
    try {
      await PremiumUtils.showTrialPaywall(
        context,
        source: source ?? 'feature_modal',
      );
    } catch (e) {
      debugPrint('Error mostrando paywall desde modal: $e');
      if (context.mounted) {
        PremiumUtils.showRevenueCatUnavailableDialog(context);
      }
    }
  }

  void _showSuccessDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¡Bienvenido a Premium!'),
        content: const Text(
          'Tu suscripción se ha activado correctamente. ¡Disfruta de todas las funciones premium!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Continuar'),
          ),
        ],
      ),
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
