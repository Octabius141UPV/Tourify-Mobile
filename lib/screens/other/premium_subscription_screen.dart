import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:tourify_flutter/services/analytics_service.dart';
import 'package:tourify_flutter/providers/premium_provider.dart';

class PremiumSubscriptionScreen extends StatelessWidget {
  const PremiumSubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // 📊 TRACKING: Registrar vista de pantalla premium
    AnalyticsService.trackScreenView('premium_subscription_screen')
        .catchError((e) => debugPrint('Error tracking screen view: $e'));

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Tourify Premium'),
        backgroundColor: const Color(0xFF0062FF),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icono principal
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF0062FF).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.workspace_premium,
                  size: 80,
                  color: Color(0xFF0062FF),
                ),
              ),
              const SizedBox(height: 24),

              // Título
              const Text(
                '¡Desbloquea todo el potencial de Tourify!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Subtítulo
              const Text(
                'Accede a funciones premium para crear mejores guías de viaje',
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF666666),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // Lista de beneficios
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Con Premium tendrás:',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildBenefit('🎯', 'Guías ilimitadas'),
                    _buildBenefit('🤝', 'Colaboración en tiempo real'),
                    _buildBenefit('📍', 'Actividades sin límite'),
                    _buildBenefit('⚡', 'Sincronización rápida'),
                    _buildBenefit('🎨', 'Personalización avanzada'),
                    _buildBenefit('💾', 'Respaldo en la nube'),
                    _buildBenefit('📱', 'Soporte prioritario'),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Botones de suscripción con RevenueCat
              Consumer<PremiumProvider>(
                builder: (context, premiumProvider, child) {
                  if (premiumProvider.isPremium) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.shade300),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle,
                              color: Colors.green.shade700),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '¡Ya eres usuario Premium!',
                              style: TextStyle(
                                color: Colors.green.shade700,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final packages = premiumProvider.getAvailablePackages();
                  if (packages.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(16),
                      child: const Column(
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 8),
                          Text(
                            'Cargando opciones de suscripción...',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    );
                  }

                  return Column(
                    children: [
                      // Opciones de suscripción
                      ...packages.map((package) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _buildSubscriptionOption(
                              context,
                              premiumProvider,
                              package,
                            ),
                          )),

                      const SizedBox(height: 16),

                      // Botón para restaurar compras
                      TextButton(
                        onPressed: premiumProvider.isLoading
                            ? null
                            : () => _restorePurchases(context, premiumProvider),
                        child: const Text(
                          'Restaurar compras',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),

              // Botón para cerrar
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text(
                    'Volver',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey.shade300,
                    foregroundColor: Colors.black87,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBenefit(String emoji, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Text(
            emoji,
            style: const TextStyle(fontSize: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 16,
                color: Color(0xFF333333),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionOption(
    BuildContext context,
    PremiumProvider premiumProvider,
    Package package,
  ) {
    final isLoading = premiumProvider.isLoading;
    final hasIntroPrice = package.storeProduct.introductoryPrice != null;
    final period = premiumProvider.getSubscriptionPeriod(package);
    final price = premiumProvider.getFormattedPrice(package);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(
          color: hasIntroPrice ? Colors.orange : const Color(0xFF0062FF),
          width: 2,
        ),
        borderRadius: BorderRadius.circular(12),
        color: hasIntroPrice
            ? Colors.orange.shade50
            : const Color(0xFF0062FF).withOpacity(0.05),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: isLoading
              ? null
              : () => _purchasePackage(context, premiumProvider, package),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                price,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1A1A1A),
                                ),
                              ),
                              Text(
                                '/$period',
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Color(0xFF666666),
                                ),
                              ),
                              if (hasIntroPrice) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
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
                          if (hasIntroPrice) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Prueba gratis, luego $price/$period',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.orange,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (isLoading)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      Icon(
                        Icons.arrow_forward,
                        color: hasIntroPrice
                            ? Colors.orange
                            : const Color(0xFF0062FF),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _purchasePackage(
    BuildContext context,
    PremiumProvider premiumProvider,
    Package package,
  ) async {
    try {
      // 📊 TRACKING: Registrar inicio de compra
      AnalyticsService.trackPremiumPaymentClick('subscription_screen')
          .catchError((e) => debugPrint('Error tracking payment click: $e'));

      final success = await premiumProvider.purchaseProduct(
        package,
        source: 'subscription_screen',
      );

      if (!context.mounted) return;

      if (success) {
        // Mostrar éxito
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('¡Bienvenido a Premium!'),
            content: const Text(
              'Tu suscripción se ha activado correctamente. ¡Disfruta de todas las funciones premium!',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Cerrar diálogo
                  Navigator.pop(context); // Volver a pantalla anterior
                },
                child: const Text('Continuar'),
              ),
            ],
          ),
        );
      } else {
        // Mostrar error
        _showErrorDialog(
            context, 'No se pudo completar la compra. Inténtalo de nuevo.');
      }
    } catch (e) {
      if (!context.mounted) return;
      _showErrorDialog(context, 'Error inesperado: $e');
    }
  }

  Future<void> _restorePurchases(
    BuildContext context,
    PremiumProvider premiumProvider,
  ) async {
    try {
      final success = await premiumProvider.restorePurchases();

      if (!context.mounted) return;

      if (success) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('¡Compras restauradas!'),
            content: const Text(
                'Tu suscripción premium se ha restaurado correctamente.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Continuar'),
              ),
            ],
          ),
        );
      } else {
        _showErrorDialog(context, 'No se encontraron compras anteriores.');
      }
    } catch (e) {
      if (!context.mounted) return;
      _showErrorDialog(context, 'Error restaurando compras: $e');
    }
  }

  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }
}
