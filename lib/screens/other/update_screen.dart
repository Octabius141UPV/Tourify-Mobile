import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'dart:io' show Platform;
import 'package:tourify_flutter/config/app_colors.dart';
import 'package:tourify_flutter/services/version_service.dart';
import 'package:tourify_flutter/utils/safe_area_helper.dart';

class UpdateScreen extends StatefulWidget {
  final VersionCheckResult versionResult;
  final VoidCallback? onSkip;
  final VoidCallback? onContinue;

  const UpdateScreen({
    super.key,
    required this.versionResult,
    this.onSkip,
    this.onContinue,
  });

  @override
  State<UpdateScreen> createState() => _UpdateScreenState();
}

class _UpdateScreenState extends State<UpdateScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _openStore() async {
    setState(() {
      _isUpdating = true;
    });

    try {
      final storeUrl = widget.versionResult.storeUrl;
      if (storeUrl != null && storeUrl.isNotEmpty) {
        final uri = Uri.parse(storeUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          await _openDefaultStore();
        }
      } else {
        await _openDefaultStore();
      }
    } catch (e) {
      debugPrint('❌ Error abriendo tienda: $e');
      await _openDefaultStore();
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }

  Future<void> _openDefaultStore() async {
    try {
      String defaultUrl;
      if (Platform.isIOS) {
        defaultUrl =
            'https://apps.apple.com/us/app/tourify/id6747407603'; // Reemplaza con tu App Store ID
      } else {
        defaultUrl =
            'https://play.google.com/store/apps/details?id=com.mycompany.tourify';
      }

      final uri = Uri.parse(defaultUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('❌ Error abriendo tienda por defecto: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo abrir la tienda de aplicaciones'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _handleSkip() {
    if (widget.versionResult.recommendedVersion != null) {
      VersionService()
          .skipVersionUpdate(widget.versionResult.recommendedVersion!);
    }
    widget.onSkip?.call();
  }

  void _handleContinue() {
    widget.onContinue?.call();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Prevenir que el usuario cierre la pantalla si es una actualización forzada
        if (widget.versionResult.isForced) {
          return false;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: AppColors.primary,
        body: SafeArea(
          child: AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Icono de actualización
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                              width: 2,
                            ),
                          ),
                          child: Icon(
                            widget.versionResult.isForced
                                ? Icons.system_update_alt
                                : Icons.update,
                            size: 60,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Título
                        Text(
                          widget.versionResult.isForced
                              ? '¡Actualización Requerida!'
                              : '¡Nueva versión disponible!',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),

                        // Mensaje personalizado o por defecto
                        Text(
                          widget.versionResult.message ??
                              (widget.versionResult.isForced
                                  ? 'Para continuar usando Tourify, necesitas actualizar a la versión más reciente.'
                                  : 'Descubre las nuevas funcionalidades y mejoras en la última versión de Tourify.'),
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),

                        // Botón de actualizar
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isUpdating ? null : _openStore,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: _isUpdating
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        AppColors.primary,
                                      ),
                                    ),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Platform.isIOS
                                            ? Icons.apple
                                            : Icons.android,
                                        size: 24,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        Platform.isIOS
                                            ? 'Abrir App Store'
                                            : 'Abrir Play Store',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Botón de saltar (solo si no es forzada)
                        if (!widget.versionResult.isForced) ...[
                          SizedBox(
                            width: double.infinity,
                            child: TextButton(
                              onPressed: _handleSkip,
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.white70,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                              ),
                              child: const Text(
                                'Recordar más tarde',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ],

                        // Botón de continuar sin actualizar (solo si no es forzada)
                        if (!widget.versionResult.isForced) ...[
                          SizedBox(
                            width: double.infinity,
                            child: TextButton(
                              onPressed: _handleContinue,
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.white54,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: const Text(
                                'Continuar sin actualizar',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildVersionRow(String label, String version) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white70,
            ),
          ),
          Text(
            version,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
