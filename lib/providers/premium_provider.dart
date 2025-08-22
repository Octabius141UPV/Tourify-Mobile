import 'dart:async';
import 'package:flutter/material.dart';
import 'package:tourify_flutter/services/subscription_service.dart';

/// Provider para gestionar el estado premium en toda la aplicación
class PremiumProvider extends ChangeNotifier {
  final SubscriptionService _subscriptionService = SubscriptionService.instance;
  late StreamSubscription _premiumStatusSubscription;

  bool _isPremium = false;
  bool _isLoading = false;
  String? _error;

  // Getters
  bool get isPremium => _isPremium;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isInitialized => _subscriptionService.isInitialized;

  PremiumProvider() {
    _initialize();
  }

  /// Inicializa el provider
  void _initialize() {
    // Escuchar cambios en el estado premium
    _premiumStatusSubscription =
        _subscriptionService.premiumStatusStream.listen(
      (isPremium) {
        _isPremium = isPremium;
        _error = null;
        notifyListeners();
      },
    );

    // Establecer estado inicial
    _isPremium = _subscriptionService.isPremium;
  }

  /// Inicializa RevenueCat (llamar desde main.dart)
  Future<void> initializeRevenueCat({
    required String apiKey,
    String? userId,
  }) async {
    _setLoading(true);
    try {
      await _subscriptionService.initialize(apiKey: apiKey, userId: userId);
      _isPremium = _subscriptionService.isPremium;
      _error = null;
    } catch (e) {
      _error = 'Error inicializando suscripciones: $e';
      debugPrint('❌ Error en PremiumProvider: $_error');
    }
    _setLoading(false);
  }

  /// Compra un producto
  Future<bool> purchaseProduct(dynamic package, {String? source}) async {
    _setLoading(true);
    try {
      final success =
          await _subscriptionService.purchaseProduct(package, source: source);
      if (success) {
        _isPremium = true;
        _error = null;
      }
      return success;
    } catch (e) {
      _error = 'Error en la compra: $e';
      debugPrint('❌ Error comprando producto: $_error');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Restaura compras
  Future<bool> restorePurchases() async {
    _setLoading(true);
    try {
      final success = await _subscriptionService.restorePurchases();
      if (success) {
        _isPremium = true;
        _error = null;
      }
      return success;
    } catch (e) {
      _error = 'Error restaurando compras: $e';
      debugPrint('❌ Error restaurando compras: $_error');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Identifica un usuario
  Future<void> identifyUser(String userId) async {
    try {
      await _subscriptionService.identifyUser(userId);
      _isPremium = _subscriptionService.isPremium;
      _error = null;
      notifyListeners();
    } catch (e) {
      _error = 'Error identificando usuario: $e';
      debugPrint('❌ Error identificando usuario: $_error');
      notifyListeners();
    }
  }

  /// Cierra sesión del usuario
  Future<void> logOut() async {
    try {
      await _subscriptionService.logOut();
      _isPremium = false;
      _error = null;
      notifyListeners();
    } catch (e) {
      _error = 'Error cerrando sesión: $e';
      debugPrint('❌ Error cerrando sesión: $_error');
      notifyListeners();
    }
  }

  /// Obtiene paquetes disponibles
  List<dynamic> getAvailablePackages() {
    return _subscriptionService.getAvailablePackages();
  }

  /// Obtiene paquete mensual
  dynamic getMonthlyPackage() {
    return _subscriptionService.getMonthlyPackage();
  }

  /// Obtiene paquete anual
  dynamic getAnnualPackage() {
    return _subscriptionService.getAnnualPackage();
  }

  /// Obtiene paquete con trial
  dynamic getTrialPackage() {
    return _subscriptionService.getTrialPackage();
  }

  /// Verifica si hay trial disponible
  bool hasTrialAvailable() {
    return _subscriptionService.hasTrialAvailable();
  }

  /// Obtiene precio formateado
  String getFormattedPrice(dynamic package) {
    return _subscriptionService.getFormattedPrice(package);
  }

  /// Obtiene período de suscripción
  String getSubscriptionPeriod(dynamic package) {
    return _subscriptionService.getSubscriptionPeriod(package);
  }

  /// Verifica si puede hacer pagos
  Future<bool> canMakePayments() async {
    return await _subscriptionService.canMakePayments();
  }

  /// Establece estado de carga
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  /// Limpia errores
  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _premiumStatusSubscription.cancel();
    super.dispose();
  }
}
