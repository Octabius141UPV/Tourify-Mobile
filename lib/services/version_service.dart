import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io' show Platform;

/// Información sobre el resultado de la verificación de versión
class VersionCheckResult {
  final bool needsUpdate; // Necesita actualización (cualquier tipo)
  final bool isForced; // Es actualización forzada (< mínima)
  final bool hasRecommendedUpdate; // Hay actualización recomendada disponible
  final String? minimumVersion;
  final String? recommendedVersion;
  final String? currentVersion;
  final String? message;
  final String? storeUrl;

  VersionCheckResult({
    required this.needsUpdate,
    required this.isForced,
    this.hasRecommendedUpdate = false,
    this.minimumVersion,
    this.recommendedVersion,
    this.currentVersion,
    this.message,
    this.storeUrl,
  });
}

/// Servicio para manejar la verificación de versiones de la aplicación
class VersionService {
  static final VersionService _instance = VersionService._internal();
  factory VersionService() => _instance;
  VersionService._internal();

  static const String _lastVersionCheckKey = 'last_version_check';
  static const String _skipVersionKey = 'skip_version_update';
  static const String _firebaseVersionCollection = 'app_versions';
  static const String _firebaseVersionDocument = 'config';
  static const Duration _checkInterval =
      Duration(hours: 6); // Verificar cada 6 horas

  /// Verifica si la aplicación necesita actualización
  Future<VersionCheckResult> checkVersion() async {
    try {
      debugPrint('🔍 Verificando versión de la aplicación...');

      // Obtener información del paquete
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      final buildNumber = packageInfo.buildNumber;

      debugPrint('📱 Versión actual: $currentVersion ($buildNumber)');

      // Siempre realizamos la verificación, sin importar cuándo fue la última vez.

      // Obtener configuración de versiones desde Firebase
      final versionConfig = await _getVersionConfig();

      if (versionConfig == null) {
        debugPrint('⚠️ No se pudo obtener configuración de versiones');
        await _updateLastVersionCheck();
        return VersionCheckResult(
          needsUpdate: false,
          isForced: false,
          currentVersion: currentVersion,
        );
      }

      // Verificar si las verificaciones están activas
      if (versionConfig['active'] == false) {
        debugPrint('⚠️ Verificaciones de versión deshabilitadas');
        await _updateLastVersionCheck();
        return VersionCheckResult(
          needsUpdate: false,
          isForced: false,
          currentVersion: currentVersion,
        );
      }

      // Determinar tipos de actualización
      final belowMinimum =
          _compareVersions(currentVersion, versionConfig['minimumVersion']);
      final belowRecommended =
          _compareVersions(currentVersion, versionConfig['recommendedVersion']);

      // Lógica clara:
      // - isForced = true solo si está por debajo de la versión mínima
      // - needsUpdate = true si hay cualquier actualización disponible
      // - hasRecommendedUpdate = true si hay actualización recomendada (pero no forzada)

      final isForced = belowMinimum || versionConfig['forceUpdate'] == true;
      final needsUpdate = belowMinimum || belowRecommended;
      final hasRecommendedUpdate = belowRecommended && !belowMinimum;

      // Nota: si quieres volver a implementar un intervalo, hazlo aquí, pero
      // teniendo en cuenta que las actualizaciones recomendadas deben seguir
      // mostrándose siempre.

      debugPrint('🎯 Resultado verificación:');
      debugPrint('   - Versión actual: $currentVersion');
      debugPrint('   - Versión mínima: ${versionConfig['minimumVersion']}');
      debugPrint(
          '   - Versión recomendada: ${versionConfig['recommendedVersion']}');
      debugPrint('   - Por debajo de mínima: $belowMinimum');
      debugPrint('   - Por debajo de recomendada: $belowRecommended');
      debugPrint('   - Necesita actualización: $needsUpdate');
      debugPrint('   - Es forzada: $isForced');
      debugPrint('   - Tiene actualización recomendada: $hasRecommendedUpdate');

      await _updateLastVersionCheck();

      // Determinar URL de la tienda según la plataforma
      String? storeUrl;
      if (Platform.isIOS) {
        storeUrl = versionConfig['iosStoreUrl'];
      } else if (Platform.isAndroid) {
        storeUrl = versionConfig['androidStoreUrl'];

        // Si no hay URL para Android, no mostrar actualización
        if (storeUrl == null || storeUrl.isEmpty) {
          debugPrint(
              '⚠️ No hay URL configurada para Android, saltando verificación');
          await _updateLastVersionCheck();
          return VersionCheckResult(
            needsUpdate: false,
            isForced: false,
            currentVersion: currentVersion,
            message: 'Esta aplicación solo está disponible en iOS',
          );
        }
      }

      return VersionCheckResult(
        needsUpdate: needsUpdate,
        isForced: isForced,
        hasRecommendedUpdate: hasRecommendedUpdate,
        minimumVersion: versionConfig['minimumVersion'],
        recommendedVersion: versionConfig['recommendedVersion'],
        currentVersion: currentVersion,
        message: versionConfig['message'],
        storeUrl: storeUrl,
      );
    } catch (e) {
      debugPrint('❌ Error verificando versión: $e');
      return VersionCheckResult(
        needsUpdate: false,
        isForced: false,
        currentVersion: 'unknown',
      );
    }
  }

  /// Obtiene la configuración de versiones desde Firebase
  Future<Map<String, dynamic>?> _getVersionConfig() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection(_firebaseVersionCollection)
          .doc(_firebaseVersionDocument)
          .get();

      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error obteniendo configuración de versiones: $e');
      return null;
    }
  }

  /// Compara dos versiones (retorna true si la current es menor que la required)
  bool _compareVersions(String currentVersion, String? requiredVersion) {
    if (requiredVersion == null) return false;

    try {
      final currentParts =
          currentVersion.split('.').map((e) => int.parse(e)).toList();
      final requiredParts =
          requiredVersion.split('.').map((e) => int.parse(e)).toList();

      // Asegurar que ambas listas tengan la misma longitud
      while (currentParts.length < requiredParts.length) {
        currentParts.add(0);
      }
      while (requiredParts.length < currentParts.length) {
        requiredParts.add(0);
      }

      // Comparar cada parte
      for (int i = 0; i < currentParts.length; i++) {
        if (currentParts[i] < requiredParts[i]) {
          return true; // Necesita actualización
        } else if (currentParts[i] > requiredParts[i]) {
          return false; // Ya está actualizado
        }
      }

      return false; // Son iguales
    } catch (e) {
      debugPrint('❌ Error comparando versiones: $e');
      return false;
    }
  }

  /// Determina si la actualización debe ser forzada basándose en versionado semántico
  ///
  /// Reglas:
  /// - Cambios en x (major) o y (minor) → Actualización forzosa
  /// - Cambios en z (patch) → Actualización voluntaria
  ///
  /// Ejemplos:
  /// - 1.0.0 → 2.0.0 (major change) → FORZADA
  /// - 1.0.0 → 1.1.0 (minor change) → FORZADA
  /// - 1.0.0 → 1.0.1 (patch change) → VOLUNTARIA
  bool _shouldForceUpdateBySemanticVersioning(
      String currentVersion, String? newVersion) {
    if (newVersion == null) return false;

    try {
      final currentParts =
          currentVersion.split('.').map((e) => int.parse(e)).toList();
      final newParts = newVersion.split('.').map((e) => int.parse(e)).toList();

      // Asegurar que ambas listas tengan al menos 3 elementos (major.minor.patch)
      while (currentParts.length < 3) {
        currentParts.add(0);
      }
      while (newParts.length < 3) {
        newParts.add(0);
      }

      final currentMajor = currentParts[0];
      final currentMinor = currentParts[1];
      final currentPatch = currentParts[2];

      final newMajor = newParts[0];
      final newMinor = newParts[1];
      final newPatch = newParts[2];

      // Si hay cambio en major version → FORZADA
      if (newMajor != currentMajor) {
        debugPrint(
            '🔄 Cambio en major version detectado ($currentMajor → $newMajor) → FORZADA');
        return true;
      }

      // Si hay cambio en minor version → FORZADA
      if (newMinor != currentMinor) {
        debugPrint(
            '🔄 Cambio en minor version detectado ($currentMinor → $newMinor) → FORZADA');
        return true;
      }

      // Solo hay cambio en patch version → VOLUNTARIA
      if (newPatch != currentPatch) {
        debugPrint(
            '🔄 Solo cambio en patch version detectado ($currentPatch → $newPatch) → VOLUNTARIA');
        return false;
      }

      // No hay cambios de versión
      return false;
    } catch (e) {
      debugPrint('❌ Error determinando forzado automático: $e');
      // En caso de error, aplicar principio de precaución
      return false;
    }
  }

  /// Verifica si debe saltar la verificación por tiempo
  Future<bool> _shouldSkipVersionCheck() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastCheck = prefs.getInt(_lastVersionCheckKey) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;

      return (now - lastCheck) < _checkInterval.inMilliseconds;
    } catch (e) {
      return false;
    }
  }

  /// Actualiza la marca de tiempo de la última verificación
  Future<void> _updateLastVersionCheck() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
          _lastVersionCheckKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('❌ Error actualizando última verificación: $e');
    }
  }

  /// Marca una versión como "saltar" (solo para actualizaciones no forzadas)
  Future<void> skipVersionUpdate(String version) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_skipVersionKey, version);
      debugPrint('⏭️ Saltando actualización para versión: $version');
    } catch (e) {
      debugPrint('❌ Error saltando actualización: $e');
    }
  }

  /// Verifica si una versión fue marcada para saltar
  Future<bool> isVersionSkipped(String version) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final skippedVersion = prefs.getString(_skipVersionKey);
      return skippedVersion == version;
    } catch (e) {
      return false;
    }
  }

  /// Fuerza una verificación inmediata (ignora el tiempo)
  Future<VersionCheckResult> forceVersionCheck() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_lastVersionCheckKey);
      return await checkVersion();
    } catch (e) {
      debugPrint('❌ Error en verificación forzada: $e');
      return VersionCheckResult(
        needsUpdate: false,
        isForced: false,
        currentVersion: 'unknown',
      );
    }
  }

  /// Limpia los datos de versión almacenados (útil para testing)
  Future<void> clearVersionData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_lastVersionCheckKey);
      await prefs.remove(_skipVersionKey);
      debugPrint('🧹 Datos de versión limpiados');
    } catch (e) {
      debugPrint('❌ Error limpiando datos de versión: $e');
    }
  }
}
