import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tourify_flutter/services/user_service.dart';
import 'package:tourify_flutter/services/analytics_service.dart';
import 'package:tourify_flutter/config/app_colors.dart';
import 'package:tourify_flutter/utils/dialog_utils.dart';

class PreferencesScreen extends StatefulWidget {
  const PreferencesScreen({super.key});

  @override
  State<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends State<PreferencesScreen> {
  bool _isLoading = false;
  bool _isSaving = false;

  // Preferencias del usuario
  List<String> _travelStyles = [];
  List<String> _budgets = [];
  String _travelIntensity = 'Moderado';
  int _citiesGoal = 0; // Objetivo de racha

  // Opciones disponibles
  final List<String> _availableTravelStyles = ['Cultural', 'Fiesta'];
  final List<String> _availableBudgets = [
    'Económico',
    'Moderado',
    'Premium',
    'Lujo'
  ];
  final List<String> _availableIntensities = ['Relajado', 'Moderado', 'Activo'];

  @override
  void initState() {
    super.initState();
    _loadUserPreferences();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadUserPreferences() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userData = await UserService.getUserData(user.uid);
        if (userData != null) {
          setState(() {
            // Solo cargar las preferencias que se pueden configurar
            // Intentar obtener los estilos de viaje desde diferentes campos posibles
            final stylesFromTravelStyles = userData['travel_styles'];
            final stylesFromTravelModes = userData['travelModes'];

            _travelStyles = List<String>.from(stylesFromTravelStyles ??
                stylesFromTravelModes ??
                ['Cultural']);

            // Debug: imprimir valores para verificar
            print(
                'Estilos cargados: travel_styles=$stylesFromTravelStyles, travelModes=$stylesFromTravelModes -> $_travelStyles');
            _budgets = List<String>.from(userData['budgets'] ?? ['Moderado']);
            // Intentar obtener la intensidad desde diferentes campos posibles
            final intensityFromActivities =
                userData['activities_per_day']?.toString();
            final intensityFromTravel = userData['travelIntensity']?.toString();
            final intensityFromTravelIntensity =
                userData['travel_intensity']?.toString();

            // Mapear la intensidad correctamente
            final intensityValue = intensityFromTravel ??
                intensityFromTravelIntensity ??
                intensityFromActivities;
            _travelIntensity = _mapIntensityFromDatabase(intensityValue);

            // Debug: imprimir valores para verificar
            print('Intensidad cargada: $intensityValue -> $_travelIntensity');

            // Cargar objetivo de racha
            _citiesGoal = userData['citiesGoal'] ?? 0;
            print('Objetivo de racha cargado: $_citiesGoal');
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar preferencias: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _savePreferences() async {
    setState(() {
      _isSaving = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final preferences = {
          'travel_styles': _travelStyles,
          'budgets': _budgets,
          'travelIntensity': _travelIntensity, // Usar el campo correcto
          'activities_per_day': _getIntensityText(
              _travelIntensity), // También guardar la descripción
          'citiesGoal': _citiesGoal, // Objetivo de racha
        };

        final success = await UserService.updateUserData(user.uid, preferences);

        if (success) {
          // Analytics: Usuario actualiza preferencias
          await AnalyticsService.trackEvent('user_preferences_updated',
              parameters: {
                'travel_styles': _travelStyles,
                'budgets': _budgets,
                'intensity': _travelIntensity,
                'cities_goal': _citiesGoal,
              });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Preferencias guardadas correctamente'),
                ],
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error al guardar las preferencias'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al guardar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  String _getIntensityText(String intensity) {
    switch (intensity) {
      case 'Relajado':
        return '3 actividades por día';
      case 'Moderado':
        return '5 actividades por día';
      case 'Activo':
        return '7 actividades por día';
      default:
        return '5 actividades por día';
    }
  }

  String _getCitiesGoalText(int goal) {
    switch (goal) {
      case 1:
        return '1 ciudad cada dos meses';
      case 2:
        return '1 ciudad al mes';
      case 3:
        return '2 ciudades al mes';
      case 4:
        return '4 ciudades al mes';
      default:
        return 'Sin objetivo';
    }
  }

  String _mapIntensityFromDatabase(String? intensity) {
    // Mapear desde el valor de la base de datos a nuestro formato
    switch (intensity) {
      case 'Relajado':
      case '3 actividades por día':
      case '3-4 actividades':
        return 'Relajado';
      case 'Moderado':
      case '5 actividades por día':
      case '5-6 actividades':
        return 'Moderado';
      case 'Activo':
      case '7 actividades por día':
      case '7-8 actividades':
        return 'Activo';
      default:
        return 'Moderado';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text(
          'Preferencias de Viaje',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            TextButton(
              onPressed: _savePreferences,
              child: const Text(
                'Guardar',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Estilos de viaje
                  _buildSectionCard(
                    title: 'Estilos de Viaje',
                    subtitle: '¿Qué te gusta hacer cuando viajas?',
                    icon: Icons.explore,
                    child: Column(
                      children: _availableTravelStyles.map((style) {
                        final isSelected = _travelStyles.contains(style);
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() {
                                if (isSelected) {
                                  _travelStyles.remove(style);
                                } else {
                                  _travelStyles.add(style);
                                }
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.primary.withOpacity(0.1)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.primary
                                      : Colors.grey.shade300,
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    isSelected
                                        ? Icons.check_circle
                                        : Icons.radio_button_unchecked,
                                    color: isSelected
                                        ? AppColors.primary
                                        : Colors.grey,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    style,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                      color: isSelected
                                          ? AppColors.primary
                                          : Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Objetivo de racha
                  _buildSectionCard(
                    title: 'Objetivo de Racha',
                    subtitle: '¿Qué tipo de viajero eres?',
                    icon: Icons.local_fire_department,
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Colors.orange.withOpacity(0.3)),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.flag,
                                    color: Colors.orange[700],
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Objetivo actual: $_citiesGoal',
                                    style: TextStyle(
                                      color: Colors.orange[700],
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _getCitiesGoalText(_citiesGoal),
                                style: TextStyle(
                                  color: Colors.orange[600],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 200,
                          child: CupertinoPicker(
                            scrollController: FixedExtentScrollController(
                              initialItem:
                                  _citiesGoal > 0 ? _citiesGoal - 1 : 0,
                            ),
                            itemExtent: 50,
                            onSelectedItemChanged: (int index) {
                              setState(() {
                                _citiesGoal = index + 1;
                              });
                            },
                            children: [
                              // Opción 1: 1 cada dos meses
                              Container(
                                alignment: Alignment.center,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      '1 cada dos meses',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                        color: _citiesGoal == 1
                                            ? Colors.orange[700]
                                            : Colors.grey[700],
                                      ),
                                    ),
                                    Text(
                                      'Relajado',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: _citiesGoal == 1
                                            ? Colors.orange[600]
                                            : Colors.grey[500],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Opción 2: 1 al mes
                              Container(
                                alignment: Alignment.center,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      '1 al mes',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                        color: _citiesGoal == 2
                                            ? Colors.orange[700]
                                            : Colors.grey[700],
                                      ),
                                    ),
                                    Text(
                                      'Moderado',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: _citiesGoal == 2
                                            ? Colors.orange[600]
                                            : Colors.grey[500],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Opción 3: 2 al mes
                              Container(
                                alignment: Alignment.center,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      '2 al mes',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                        color: _citiesGoal == 3
                                            ? Colors.orange[700]
                                            : Colors.grey[700],
                                      ),
                                    ),
                                    Text(
                                      'Activo',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: _citiesGoal == 3
                                            ? Colors.orange[600]
                                            : Colors.grey[500],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Opción 4: 4 al mes
                              Container(
                                alignment: Alignment.center,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      '4 al mes',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                        color: _citiesGoal == 4
                                            ? Colors.orange[700]
                                            : Colors.grey[700],
                                      ),
                                    ),
                                    Text(
                                      'Intenso',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: _citiesGoal == 4
                                            ? Colors.orange[600]
                                            : Colors.grey[500],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Presupuestos
                  _buildSectionCard(
                    title: 'Rangos de Presupuesto',
                    subtitle: '¿Qué rangos de presupuesto prefieres?',
                    icon: Icons.attach_money,
                    child: Column(
                      children: _availableBudgets.map((budget) {
                        final isSelected = _budgets.contains(budget);
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() {
                                if (isSelected) {
                                  _budgets.remove(budget);
                                } else {
                                  _budgets.add(budget);
                                }
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.primary.withOpacity(0.1)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.primary
                                      : Colors.grey.shade300,
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    isSelected
                                        ? Icons.check_circle
                                        : Icons.radio_button_unchecked,
                                    color: isSelected
                                        ? AppColors.primary
                                        : Colors.grey,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    budget,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                      color: isSelected
                                          ? AppColors.primary
                                          : Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Intensidad del viaje
                  _buildSectionCard(
                    title: 'Intensidad del Viaje',
                    subtitle: '¿Cuántas actividades prefieres por día?',
                    icon: Icons.speed,
                    child: Column(
                      children: _availableIntensities.map((intensity) {
                        final isSelected = _travelIntensity == intensity;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() {
                                _travelIntensity = intensity;
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.primary.withOpacity(0.1)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.primary
                                      : Colors.grey.shade300,
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    isSelected
                                        ? Icons.check_circle
                                        : Icons.radio_button_unchecked,
                                    color: isSelected
                                        ? AppColors.primary
                                        : Colors.grey,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          intensity,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: isSelected
                                                ? FontWeight.w600
                                                : FontWeight.normal,
                                            color: isSelected
                                                ? AppColors.primary
                                                : Colors.black87,
                                          ),
                                        ),
                                        Text(
                                          _getIntensityText(intensity),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isSelected
                                                ? AppColors.primary
                                                    .withOpacity(0.7)
                                                : Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Botón de guardar
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _savePreferences,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: _isSaving
                          ? const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white),
                                  ),
                                ),
                                SizedBox(width: 12),
                                Text('Guardando...'),
                              ],
                            )
                          : const Text(
                              'Guardar Preferencias',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}
