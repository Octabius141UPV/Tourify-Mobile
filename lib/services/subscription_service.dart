import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:tourify_flutter/services/analytics_service.dart';

/// Servicio para manejar suscripciones premium con RevenueCat
class SubscriptionService {
  static SubscriptionService? _instance;
  static SubscriptionService get instance =>
      _instance ??= SubscriptionService._();
  SubscriptionService._();

  // StreamController para notificar cambios en el estado premium
  final _premiumStatusController = StreamController<bool>.broadcast();
  Stream<bool> get premiumStatusStream => _premiumStatusController.stream;

  // Estado actual
  bool _isPremium = false;
  bool _isInitialized = false;
  CustomerInfo? _customerInfo;
  Offerings? _offerings;

  // Getters
  bool get isPremium => _isPremium;
  bool get isInitialized => _isInitialized;
  CustomerInfo? get customerInfo => _customerInfo;
  Offerings? get offerings => _offerings;

  /// Inicializa RevenueCat
  Future<void> initialize({required String apiKey, String? userId}) async {
    try {
      debugPrint('🔄 Inicializando RevenueCat...');

      // Configurar RevenueCat
      await Purchases.setLogLevel(LogLevel.debug);

      if (Platform.isIOS) {
        await Purchases.configure(PurchasesConfiguration(apiKey));
      } else if (Platform.isAndroid) {
        await Purchases.configure(PurchasesConfiguration(apiKey));
      }

      // Configurar el usuario si se proporciona
      if (userId != null) {
        await Purchases.logIn(userId);
      }

      // Configurar listener para cambios en el estado del cliente
      Purchases.addCustomerInfoUpdateListener(_handleCustomerInfoUpdate);

      // Obtener información inicial del cliente
      await _updateCustomerInfo();

      // Obtener ofertas disponibles
      await _updateOfferings();

      _isInitialized = true;
      debugPrint('✅ RevenueCat inicializado correctamente');

      // Track inicialización
      AnalyticsService.trackEvent('revenuecat_initialized');
    } catch (e) {
      debugPrint('❌ Error inicializando RevenueCat: $e');
      AnalyticsService.trackError('revenuecat_init_error', e.toString());
      rethrow;
    }
  }

  /// Actualiza la información del cliente
  Future<void> _updateCustomerInfo() async {
    try {
      _customerInfo = await Purchases.getCustomerInfo();
      _updatePremiumStatus();
    } catch (e) {
      debugPrint('❌ Error obteniendo información del cliente: $e');
    }
  }

  /// Actualiza las ofertas disponibles
  Future<void> _updateOfferings() async {
    try {
      _offerings = await Purchases.getOfferings();
      debugPrint('📦 Ofertas obtenidas: ${_offerings?.all.keys}');
    } catch (e) {
      debugPrint('❌ Error obteniendo ofertas: $e');
    }
  }

  /// Maneja actualizaciones en la información del cliente
  void _handleCustomerInfoUpdate(CustomerInfo customerInfo) {
    _customerInfo = customerInfo;
    _updatePremiumStatus();
  }

  /// Actualiza el estado premium basado en la información del cliente
  void _updatePremiumStatus() {
    final wasPremium = _isPremium;
    _isPremium = _customerInfo?.entitlements.all['premium']?.isActive == true;

    if (wasPremium != _isPremium) {
      _premiumStatusController.add(_isPremium);
      debugPrint('🎖️ Estado premium actualizado: $_isPremium');

      // Track cambio de estado
      AnalyticsService.trackEvent('premium_status_changed', parameters: {
        'is_premium': _isPremium,
        'timestamp': DateTime.now().toIso8601String(),
      });
    }
  }

  /// Compra un producto
  Future<bool> purchaseProduct(Package package, {String? source}) async {
    try {
      debugPrint('🛒 Iniciando compra: ${package.storeProduct.identifier}');

      // Track inicio de compra
      AnalyticsService.trackEvent('purchase_started', parameters: {
        'product_id': package.storeProduct.identifier,
        'price': package.storeProduct.priceString,
        'source': source ?? 'unknown',
      });

      final purchaseResult = await Purchases.purchasePackage(package);

      // Verificar si la compra fue exitosa
      final isActive =
          purchaseResult.customerInfo.entitlements.all['premium']?.isActive ==
              true;

      if (isActive) {
        debugPrint('✅ Compra exitosa - Usuario ahora es premium');

        // Track compra exitosa
        AnalyticsService.trackEvent('purchase_completed', parameters: {
          'product_id': package.storeProduct.identifier,
          'price': package.storeProduct.priceString,
          'source': source ?? 'unknown',
          'transaction_id':
              purchaseResult.customerInfo.originalPurchaseDate ?? '',
        });

        return true;
      } else {
        debugPrint('⚠️ Compra procesada pero no activó premium');
        return false;
      }
    } on PlatformException catch (e) {
      debugPrint('❌ Error en compra: ${e.message}');

      // Track error de compra
      AnalyticsService.trackError(
          'purchase_error', e.message ?? 'Unknown error');

      // Manejar diferentes tipos de errores
      final errorCode = PurchasesErrorHelper.getErrorCode(e);
      switch (errorCode) {
        case PurchasesErrorCode.purchaseCancelledError:
          debugPrint('🔄 Compra cancelada por el usuario');
          break;
        case PurchasesErrorCode.productNotAvailableForPurchaseError:
          debugPrint('📦 Producto no disponible');
          break;
        case PurchasesErrorCode.paymentPendingError:
          debugPrint('⏳ Pago pendiente');
          break;
        default:
          debugPrint('❓ Error desconocido: ${e.message}');
      }

      return false;
    } catch (e) {
      debugPrint('❌ Error inesperado en compra: $e');
      AnalyticsService.trackError('purchase_unexpected_error', e.toString());
      return false;
    }
  }

  /// Restaura compras anteriores
  Future<bool> restorePurchases() async {
    try {
      debugPrint('🔄 Restaurando compras...');

      final customerInfo = await Purchases.restorePurchases();

      // Track restauración
      AnalyticsService.trackEvent('purchases_restored', parameters: {
        'is_premium':
            customerInfo.entitlements.all['premium']?.isActive == true,
      });

      return customerInfo.entitlements.all['premium']?.isActive == true;
    } catch (e) {
      debugPrint('❌ Error restaurando compras: $e');
      AnalyticsService.trackError('restore_purchases_error', e.toString());
      return false;
    }
  }

  /// Obtiene el paquete mensual
  Package? getMonthlyPackage() {
    try {
      return _offerings?.current?.monthly;
    } catch (e) {
      debugPrint('❌ Error obteniendo paquete mensual: $e');
      return null;
    }
  }

  /// Obtiene el paquete anual
  Package? getAnnualPackage() {
    try {
      return _offerings?.current?.annual;
    } catch (e) {
      debugPrint('❌ Error obteniendo paquete anual: $e');
      return null;
    }
  }

  /// Obtiene el paquete con trial
  Package? getTrialPackage() {
    try {
      // Buscar un paquete que tenga trial
      final packages = _offerings?.current?.availablePackages ?? [];
      for (final package in packages) {
        if (package.storeProduct.introductoryPrice != null) {
          return package;
        }
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error obteniendo paquete con trial: $e');
      return null;
    }
  }

  /// Obtiene todos los paquetes disponibles
  List<Package> getAvailablePackages() {
    try {
      return _offerings?.current?.availablePackages ?? [];
    } catch (e) {
      debugPrint('❌ Error obteniendo paquetes: $e');
      return [];
    }
  }

  /// Verifica si hay un trial disponible
  bool hasTrialAvailable() {
    try {
      return getTrialPackage() != null;
    } catch (e) {
      debugPrint('❌ Error verificando trial: $e');
      return false;
    }
  }

  /// Configura el usuario identificado
  Future<void> identifyUser(String userId) async {
    try {
      await Purchases.logIn(userId);
      await _updateCustomerInfo();
      debugPrint('👤 Usuario identificado: $userId');
    } catch (e) {
      debugPrint('❌ Error identificando usuario: $e');
    }
  }

  /// Cierra sesión del usuario
  Future<void> logOut() async {
    try {
      await Purchases.logOut();
      _isPremium = false;
      _customerInfo = null;
      _premiumStatusController.add(false);
      debugPrint('👋 Usuario deslogueado');
    } catch (e) {
      debugPrint('❌ Error cerrando sesión: $e');
    }
  }

  /// Limpia recursos
  void dispose() {
    _premiumStatusController.close();
  }

  /// Obtiene información de precios formateada
  String getFormattedPrice(Package package) {
    return package.storeProduct.priceString;
  }

  /// Obtiene información del período de suscripción
  String getSubscriptionPeriod(Package package) {
    final duration = package.packageType;
    switch (duration) {
      case PackageType.monthly:
        return 'mes';
      case PackageType.annual:
        return 'año';
      case PackageType.weekly:
        return 'semana';
      default:
        return 'período';
    }
  }

  /// Verifica si el usuario puede hacer compras
  Future<bool> canMakePayments() async {
    try {
      return await Purchases.canMakePayments();
    } catch (e) {
      debugPrint('❌ Error verificando capacidad de pago: $e');
      return false;
    }
  }
}
