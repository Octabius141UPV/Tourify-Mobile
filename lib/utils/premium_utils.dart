import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import 'package:tourify_flutter/providers/premium_provider.dart';
import 'package:tourify_flutter/widgets/premium_feature_modal.dart';
import 'package:tourify_flutter/screens/other/premium_subscription_screen.dart';
import 'package:tourify_flutter/services/analytics_service.dart';

/// Utilidades para manejar el estado premium en toda la aplicación
class PremiumUtils {
  /// Verifica si el usuario es premium
  static bool isPremium(BuildContext context) {
    try {
      return context.read<PremiumProvider>().isPremium;
    } catch (e) {
      debugPrint('Error verificando estado premium: $e');
      return false;
    }
  }

  /// Muestra el modal de características premium
  static void showPremiumModal(BuildContext context, {String? source}) {
    showDialog(
      context: context,
      builder: (context) => PremiumFeatureModal(source: source),
    );
  }

  /// Muestra el paywall con prueba gratuita (offering: default)
  static Future<void> showTrialPaywall(
    BuildContext context, {
    String? source,
    VoidCallback? onSuccess,
  }) async {
    try {
      // Track evento
      AnalyticsService.trackEvent('paywall_trial_opened', parameters: {
        'source': source ?? 'unknown',
      });

      // Obtener la offering específica
      final offering = await _getOffering('default');
      if (offering == null) {
        debugPrint('❌ No se pudo obtener offering "default"');
        if (context.mounted) {
          showRevenueCatUnavailableDialog(context);
        }
        return;
      }

      final result = await RevenueCatUI.presentPaywall(
        offering: offering,
        displayCloseButton: true,
      );

      _handlePaywallResult(result, source: source, onSuccess: onSuccess);
    } catch (e) {
      debugPrint('Error mostrando paywall con trial: $e');
      // Fallback a pantalla de suscripción
      if (context.mounted) {
        showPremiumScreen(context);
      }
    }
  }

  /// Muestra el paywall predeterminado (offering: default)
  static Future<void> showDirectPaywall(
    BuildContext context, {
    String? source,
    VoidCallback? onSuccess,
  }) async {
    try {
      // Track evento
      AnalyticsService.trackEvent('paywall_direct_opened', parameters: {
        'source': source ?? 'unknown',
      });

      // Obtener la offering específica - SIEMPRE usar 'default' (Paywall Tourify)
      final offering = await _getOffering('default');
      if (offering == null) {
        debugPrint('❌ No se pudo obtener offering "default"');
        if (context.mounted) {
          showRevenueCatUnavailableDialog(context);
        }
        return;
      }

      final result = await RevenueCatUI.presentPaywall(
        offering: offering,
        displayCloseButton: true,
      );

      _handlePaywallResult(result, source: source, onSuccess: onSuccess);
    } catch (e) {
      debugPrint('Error mostrando paywall predeterminado: $e');
      // Fallback a pantalla de suscripción
      if (context.mounted) {
        showPremiumScreen(context);
      }
    }
  }

  /// Muestra el paywall predeterminado (Paywall Tourify)
  static Future<void> showSmartPaywall(
    BuildContext context, {
    String? source,
    VoidCallback? onSuccess,
    bool preferTrial = true,
  }) async {
    try {
      final premiumProvider = context.read<PremiumProvider>();

      // Si ya es premium, no mostrar paywall
      if (premiumProvider.isPremium) {
        onSuccess?.call();
        return;
      }

      // SIEMPRE usar el paywall predeterminado 'default' (Paywall Tourify)
      const String offeringId = 'default';
      debugPrint('✨ Mostrando paywall predeterminado (Paywall Tourify)');

      // Track evento
      AnalyticsService.trackEvent('paywall_smart_opened', parameters: {
        'source': source ?? 'unknown',
        'offering_id': offeringId,
        'prefer_trial': preferTrial,
      });

      // Obtener la offering específica
      final offering = await _getOffering(offeringId);
      if (offering == null) {
        debugPrint('❌ No se pudo obtener offering "$offeringId"');
        if (context.mounted) {
          showRevenueCatUnavailableDialog(context);
        }
        return;
      }

      final result = await RevenueCatUI.presentPaywall(
        offering: offering,
        displayCloseButton: true,
      );

      _handlePaywallResult(result, source: source, onSuccess: onSuccess);
    } catch (e) {
      debugPrint('Error mostrando smart paywall: $e');
      // Fallback a pantalla de suscripción
      if (context.mounted) {
        showPremiumScreen(context);
      }
    }
  }

  /// Maneja el resultado del paywall de RevenueCat
  static void _handlePaywallResult(
    PaywallResult result, {
    String? source,
    VoidCallback? onSuccess,
  }) {
    switch (result) {
      case PaywallResult.purchased:
        debugPrint('✅ Usuario completó compra desde paywall');
        AnalyticsService.trackEvent('paywall_purchase_completed', parameters: {
          'source': source ?? 'unknown',
        });
        onSuccess?.call();
        break;
      case PaywallResult.cancelled:
        debugPrint('❌ Usuario canceló paywall');
        AnalyticsService.trackEvent('paywall_cancelled', parameters: {
          'source': source ?? 'unknown',
        });
        break;
      case PaywallResult.restored:
        debugPrint('🔄 Usuario restauró compras desde paywall');
        AnalyticsService.trackEvent('paywall_restored', parameters: {
          'source': source ?? 'unknown',
        });
        onSuccess?.call();
        break;
      case PaywallResult.error:
        debugPrint('❌ Error en paywall');
        AnalyticsService.trackEvent('paywall_error', parameters: {
          'source': source ?? 'unknown',
        });
        break;
      case PaywallResult.notPresented:
        debugPrint('⚠️ Paywall no se pudo presentar');
        AnalyticsService.trackEvent('paywall_not_presented', parameters: {
          'source': source ?? 'unknown',
        });
        break;
    }
  }

  /// Obtiene una offering específica de RevenueCat
  static Future<Offering?> _getOffering(String identifier) async {
    try {
      final offerings = await Purchases.getOfferings();
      final offering = offerings.getOffering(identifier);

      if (offering == null) {
        debugPrint('⚠️ Offering "$identifier" no encontrado en RevenueCat');
        // Intentar obtener el offering por defecto de la lista
        if (offerings.current != null) {
          debugPrint(
              '🔄 Usando offering por defecto: ${offerings.current!.identifier}');
          return offerings.current;
        }
      }

      return offering;
    } catch (e) {
      debugPrint('❌ Error obteniendo offering "$identifier": $e');

      // Detectar diferentes tipos de errores de configuración
      final errorString = e.toString().toLowerCase();

      if (errorString.contains('configuration_error') ||
          errorString.contains('configuration error')) {
        if (errorString.contains('ios 18.4 simulator')) {
          debugPrint('🚨 Problema conocido del simulador iOS 18.4 detectado');
          debugPrint('💡 Solución: Usa un simulador con iOS diferente a 18.4');
        } else {
          debugPrint('🚨 Error de configuración de RevenueCat detectado');
          debugPrint('💡 Posibles soluciones:');
          debugPrint('   • Verificar productos en App Store Connect');
          debugPrint('   • Crear StoreKit Configuration file para testing');
          debugPrint('   • Probar en dispositivo físico');
          debugPrint('   • Verificar configuración en RevenueCat dashboard');
        }
      }

      return null;
    }
  }

  /// Verifica si el usuario ya ha usado una prueba gratuita
  static Future<bool> _hasUserUsedTrial() async {
    try {
      final customerInfo = await Purchases.getCustomerInfo();

      // Verificar si hay entitlements activos o expirados que indiquen uso de trial
      final entitlements = customerInfo.entitlements.all;

      for (final entitlement in entitlements.values) {
        // Si encuentra un entitlement que fue adquirido con trial
        if (entitlement.billingIssueDetectedAt != null ||
            entitlement.unsubscribeDetectedAt != null ||
            entitlement.expirationDate != null) {
          debugPrint('🔍 Usuario ya usó trial: encontrado entitlement usado');
          return true;
        }
      }

      // También verificar si tiene productos activos o en historial
      final activeSubscriptions = customerInfo.activeSubscriptions;
      if (activeSubscriptions.isNotEmpty) {
        debugPrint('🔍 Usuario ya usó trial: tiene suscripciones activas');
        return true;
      }

      // Verificar fecha de primera compra
      if (customerInfo.firstSeen != customerInfo.requestDate) {
        debugPrint(
            '🔍 Usuario ya usó trial: fechas de primera vista vs request diferentes');
        return true;
      }

      debugPrint('✨ Usuario nuevo: no hay evidencia de trial usado');
      return false;
    } catch (e) {
      debugPrint('❌ Error verificando uso de trial: $e');
      // En caso de error, asumir que no ha usado trial (ser conservador)
      return false;
    }
  }

  /// Navega a la pantalla de suscripción premium
  static void showPremiumScreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const PremiumSubscriptionScreen(),
      ),
    );
  }

  /// Muestra instrucciones para configurar StoreKit para desarrollo local
  static void showStoreKitConfigurationHelp(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🛠️ Configuración de StoreKit'),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Para probar suscripciones en el simulador:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 12),
              Text(
                  '1. En Xcode, ve a: Editor → Add Configuration → StoreKit Configuration File'),
              SizedBox(height: 8),
              Text(
                  '2. Crea productos con los mismos IDs que tienes en RevenueCat:'),
              Text('   • com.tourify.monthly'),
              Text('   • com.tourify.yearly'),
              SizedBox(height: 8),
              Text(
                  '3. En el scheme del proyecto, selecciona el archivo .storekit'),
              SizedBox(height: 8),
              Text(
                  '4. Rebuild la app y las suscripciones funcionarán en el simulador'),
              SizedBox(height: 12),
              Text(
                'Mientras tanto, las funciones premium están deshabilitadas en el simulador.',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  /// Muestra un diálogo cuando RevenueCat no está disponible
  static void showRevenueCatUnavailableDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🚧 Simulador - Servicios limitados'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Los servicios de suscripción no están disponibles en el simulador por problemas de configuración.',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 12),
            Text(
              '💡 Soluciones:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('• Probar en un dispositivo físico'),
            Text('• Crear archivo StoreKit Configuration'),
            Text('• Configurar productos en App Store Connect'),
            SizedBox(height: 12),
            Text(
              'En dispositivos reales funcionará correctamente.',
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendido'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              showStoreKitConfigurationHelp(context);
            },
            child: const Text('Guía configuración'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              showPremiumScreen(context);
            },
            child: const Text('Ver opciones básicas'),
          ),
        ],
      ),
    );
  }

  /// Verifica si una característica requiere premium y muestra el modal si es necesario
  static bool requiresPremium(BuildContext context, {String? source}) {
    if (!isPremium(context)) {
      showPremiumModal(context, source: source);
      return true;
    }
    return false;
  }

  /// Métodos de conveniencia para diferentes contextos

  /// Para nuevos usuarios en onboarding (prefiere trial)
  static Future<void> showOnboardingPaywall(BuildContext context) async {
    await showTrialPaywall(context, source: 'onboarding');
  }

  /// Para usuarios que han alcanzado límites de función gratuita
  static Future<void> showFeatureLimitPaywall(
      BuildContext context, String featureName) async {
    // Decidir entre modal o paywall según la importancia
    final premiumProvider = context.read<PremiumProvider>();

    if (premiumProvider.hasTrialAvailable()) {
      await showTrialPaywall(context, source: 'feature_limit_$featureName');
    } else {
      // Si no hay trial, mostrar primero modal pequeño
      showPremiumModal(context, source: 'feature_limit_$featureName');
    }
  }

  /// Para campañas de marketing - usa paywall predeterminado
  static Future<void> showMarketingPaywall(
      BuildContext context, String campaignId) async {
    await showDirectPaywall(context, source: 'marketing_$campaignId');
  }

  /// Para usuarios cuyo trial ha expirado - usa paywall predeterminado
  static Future<void> showTrialExpiredPaywall(BuildContext context) async {
    await showDirectPaywall(context, source: 'trial_expired');
  }

  /// Para mostrar paywall - siempre usa paywall predeterminado
  static Future<void> showContextualPaywall(
    BuildContext context, {
    required bool isNewUser,
    String? source,
  }) async {
    // Siempre usar el paywall predeterminado independientemente del tipo de usuario
    await showTrialPaywall(context,
        source: source ?? (isNewUser ? 'new_user' : 'returning_user'));
  }

  /// Método principal recomendado: Muestra el paywall predeterminado
  /// Siempre usa el paywall "Paywall Tourify" (offering: default)
  static Future<void> showAppropriatePaywall(
    BuildContext context, {
    String? source,
    VoidCallback? onSuccess,
  }) async {
    await showSmartPaywall(
      context,
      source: source ?? 'auto',
      onSuccess: onSuccess,
    );
  }

  /// Verifica si el usuario ya usó trial (método público para usar en lógica de app)
  static Future<bool> hasUserUsedTrial() async {
    return await _hasUserUsedTrial();
  }

  /// Widget que envuelve contenido que requiere premium
  static Widget premiumGate({
    required BuildContext context,
    required Widget child,
    required Widget fallback,
    String? source,
  }) {
    return Consumer<PremiumProvider>(
      builder: (context, premiumProvider, _) {
        if (premiumProvider.isPremium) {
          return child;
        } else {
          return GestureDetector(
            onTap: () => showPremiumModal(context, source: source),
            child: fallback,
          );
        }
      },
    );
  }

  /// Widget que muestra un badge premium en elementos que lo requieren
  static Widget premiumBadge({
    Color color = const Color(0xFFFFC107),
    double size = 16,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.workspace_premium,
            size: size * 0.8,
            color: Colors.white,
          ),
          const SizedBox(width: 2),
          Text(
            'PRO',
            style: TextStyle(
              fontSize: size * 0.6,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  /// Widget overlay que se muestra sobre contenido premium para usuarios gratuitos
  static Widget premiumOverlay({
    required String featureName,
    String? source,
  }) {
    return Builder(
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.lock,
                color: Colors.white,
                size: 48,
              ),
              const SizedBox(height: 12),
              Text(
                featureName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Solo para usuarios Premium',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => showPremiumModal(context, source: source),
                icon: const Icon(Icons.workspace_premium),
                label: const Text('Obtener Premium'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFC107),
                  foregroundColor: Colors.black,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Wrapper que automáticamente identifica al usuario en RevenueCat cuando se autentica
  static void identifyUser(BuildContext context, String userId) {
    try {
      context.read<PremiumProvider>().identifyUser(userId);
    } catch (e) {
      debugPrint('Error identificando usuario en RevenueCat: $e');
    }
  }

  /// Cierra sesión del usuario en RevenueCat
  static void logOut(BuildContext context) {
    try {
      context.read<PremiumProvider>().logOut();
    } catch (e) {
      debugPrint('Error cerrando sesión en RevenueCat: $e');
    }
  }

  /// Obtiene información formateada del estado de suscripción
  static String getSubscriptionStatus(BuildContext context) {
    try {
      final premiumProvider = context.read<PremiumProvider>();
      if (premiumProvider.isPremium) {
        return 'Usuario Premium Activo';
      } else {
        return 'Usuario Gratuito';
      }
    } catch (e) {
      debugPrint('Error obteniendo estado de suscripción: $e');
      return 'Estado Desconocido';
    }
  }

  /// Verifica si hay ofertas especiales disponibles (como trials)
  static bool hasSpecialOffers(BuildContext context) {
    try {
      return context.read<PremiumProvider>().hasTrialAvailable();
    } catch (e) {
      debugPrint('Error verificando ofertas especiales: $e');
      return false;
    }
  }

  /// Muestra un SnackBar cuando el usuario intenta usar una función premium
  static void showPremiumRequired(BuildContext context, String featureName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.workspace_premium, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Text('$featureName requiere Tourify Premium'),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF0062FF),
        action: SnackBarAction(
          label: 'Ver Premium',
          textColor: Colors.white,
          onPressed: () => showPremiumModal(context),
        ),
      ),
    );
  }
}
