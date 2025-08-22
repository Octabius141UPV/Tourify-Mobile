import 'package:flutter/material.dart';
import 'package:tourify_flutter/utils/premium_utils.dart';

/// Ejemplos de cómo usar los paywalls nativos de RevenueCat en distintos contextos
class PaywallExamples {
  /// Ejemplo 1: Mostrar paywall con prueba gratuita para nuevos usuarios
  static Future<void> showTrialForNewUsers(BuildContext context) async {
    await PremiumUtils.showTrialPaywall(
      context,
      source: 'new_user_onboarding',
      onSuccess: () {
        // Usuario completó la suscripción con trial
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('¡Bienvenido a Premium! Tu prueba gratuita ha comenzado.'),
            backgroundColor: Colors.green,
          ),
        );
      },
    );
  }

  /// Ejemplo 2: Mostrar paywall directo para usuarios que ya usaron el trial
  static Future<void> showDirectForExistingUsers(BuildContext context) async {
    await PremiumUtils.showDirectPaywall(
      context,
      source: 'returning_user',
      onSuccess: () {
        // Usuario completó la suscripción directa
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Bienvenido de vuelta a Premium!'),
            backgroundColor: Colors.blue,
          ),
        );
      },
    );
  }

  /// Ejemplo 3: Usar el paywall inteligente que decide automáticamente
  /// Lógica: Si ya usó trial → Sin trial, Si no ha usado trial → Con trial
  static Future<void> showSmartPaywallExample(BuildContext context) async {
    await PremiumUtils.showAppropriatePaywall(
      context,
      source: 'feature_gate',
      onSuccess: () {
        // Se adapta automáticamente según si ya usó trial
        debugPrint('Usuario se suscribió exitosamente');
      },
    );
  }

  /// Ejemplo 3b: Verificar si el usuario ya usó trial antes de mostrar paywall
  static Future<void> showPaywallBasedOnTrialHistory(
      BuildContext context) async {
    final hasUsedTrial = await PremiumUtils.hasUserUsedTrial();

    debugPrint('Usuario ya usó trial: $hasUsedTrial');

    if (hasUsedTrial) {
      await PremiumUtils.showDirectPaywall(context, source: 'returning_user');
    } else {
      await PremiumUtils.showTrialPaywall(context,
          source: 'new_user_with_trial');
    }
  }

  /// Ejemplo 4: Mostrar paywall cuando se intenta usar una función premium
  static void showPaywallOnFeatureAccess(
      BuildContext context, String featureName) {
    // Verificar si requiere premium
    if (PremiumUtils.requiresPremium(context, source: 'feature_$featureName')) {
      return; // requiresPremium ya mostró el modal
    }

    // Si ya es premium, ejecutar la función
    debugPrint('Ejecutando función premium: $featureName');
  }

  /// Ejemplo 5: Diferentes contextos para diferentes paywalls nativos de RevenueCat
  static Future<void> showContextualPaywall(
      BuildContext context, PaywallContext contextType) async {
    switch (contextType) {
      case PaywallContext.onboarding:
        // Para onboarding: mostrar paywall con trial (offering: default)
        await PremiumUtils.showOnboardingPaywall(context);
        _handleOnboardingSuccess(context);
        break;

      case PaywallContext.featureLimit:
        // Para límites de función: decidir automáticamente
        await PremiumUtils.showFeatureLimitPaywall(context, 'general');
        break;

      case PaywallContext.settingsMenu:
        // Desde configuración: pantalla completa con opciones
        PremiumUtils.showPremiumScreen(context);
        break;

      case PaywallContext.marketingCampaign:
        // Para campañas: paywall sin trial (offering: NoFreeTrial)
        await PremiumUtils.showMarketingPaywall(context, 'general');
        _handleMarketingSuccess(context);
        break;

      case PaywallContext.trialExpired:
        // Trial expirado: paywall sin trial con enfoque en valor
        await PremiumUtils.showTrialExpiredPaywall(context);
        _handleTrialExpiredSuccess(context);
        break;
    }
  }

  /// Ejemplo 6: Uso con lógica condicional basada en usuario
  static Future<void> showUserSpecificPaywall(
    BuildContext context, {
    required bool isNewUser,
    bool hasUsedTrial = false,
  }) async {
    if (isNewUser && !hasUsedTrial) {
      // Nuevo usuario sin trial usado -> mostrar offering con trial
      await PremiumUtils.showTrialPaywall(context, source: 'new_user');
    } else {
      // Usuario existente o que ya usó trial -> mostrar offering sin trial
      await PremiumUtils.showDirectPaywall(context, source: 'returning_user');
    }
  }

  static void _handleOnboardingSuccess(BuildContext context) {
    // Continuar con el onboarding
    debugPrint('Usuario premium, continuar onboarding');
  }

  static void _handleMarketingSuccess(BuildContext context) {
    // Registrar conversión de campaña
    debugPrint('Conversión exitosa desde campaña marketing');
  }

  static void _handleTrialExpiredSuccess(BuildContext context) {
    // Reactivar funciones premium
    debugPrint('Usuario reactivó premium después de trial expirado');
  }
}

/// Contextos diferentes donde se puede mostrar un paywall
enum PaywallContext {
  onboarding, // Durante el proceso de registro/onboarding
  featureLimit, // Cuando se alcanza un límite de función gratuita
  settingsMenu, // Desde el menú de configuración
  marketingCampaign, // Desde una campaña de marketing
  trialExpired, // Cuando expira el trial
}

/// Widget de demostración que muestra cómo implementar los paywalls
class PaywallDemoScreen extends StatelessWidget {
  const PaywallDemoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Demo Paywalls'),
        backgroundColor: const Color(0xFF0062FF),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Ejemplos de Paywalls',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),

            // Paywall con prueba
            ElevatedButton.icon(
              onPressed: () => PaywallExamples.showTrialForNewUsers(context),
              icon: const Icon(Icons.card_giftcard),
              label: const Text('Paywall con Prueba Gratuita'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(16),
              ),
            ),

            const SizedBox(height: 12),

            // Paywall directo
            ElevatedButton.icon(
              onPressed: () =>
                  PaywallExamples.showDirectForExistingUsers(context),
              icon: const Icon(Icons.workspace_premium),
              label: const Text('Paywall Directo (Sin Trial)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0062FF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(16),
              ),
            ),

            const SizedBox(height: 12),

            // Paywall inteligente
            ElevatedButton.icon(
              onPressed: () => PaywallExamples.showSmartPaywallExample(context),
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Paywall Inteligente'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(16),
              ),
            ),

            const SizedBox(height: 12),

            // Paywall basado en historial de trial
            ElevatedButton.icon(
              onPressed: () =>
                  PaywallExamples.showPaywallBasedOnTrialHistory(context),
              icon: const Icon(Icons.history),
              label: const Text('Paywall por Historial Trial'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(16),
              ),
            ),

            const SizedBox(height: 20),

            const Text(
              'Contextos de Uso:',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 12),

            // Diferentes contextos
            ...PaywallContext.values.map((contextType) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: OutlinedButton(
                    onPressed: () => PaywallExamples.showContextualPaywall(
                      context,
                      contextType,
                    ),
                    child: Text(_getContextTitle(contextType)),
                  ),
                )),

            const Spacer(),

            // Modal pequeño
            OutlinedButton.icon(
              onPressed: () =>
                  PremiumUtils.showPremiumModal(context, source: 'demo'),
              icon: const Icon(Icons.info_outline),
              label: const Text('Mostrar Modal Premium'),
            ),
          ],
        ),
      ),
    );
  }

  String _getContextTitle(PaywallContext context) {
    switch (context) {
      case PaywallContext.onboarding:
        return 'Contexto: Onboarding';
      case PaywallContext.featureLimit:
        return 'Contexto: Límite de Función';
      case PaywallContext.settingsMenu:
        return 'Contexto: Menú Configuración';
      case PaywallContext.marketingCampaign:
        return 'Contexto: Campaña Marketing';
      case PaywallContext.trialExpired:
        return 'Contexto: Trial Expirado';
    }
  }
}
