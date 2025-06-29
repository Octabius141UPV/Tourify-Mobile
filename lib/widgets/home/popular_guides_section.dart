import 'package:flutter/material.dart';
import 'package:tourify_flutter/widgets/home/popular_guide_card.dart';
import 'package:tourify_flutter/services/guide_service.dart';
import 'package:tourify_flutter/services/navigation_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PopularGuidesSection extends StatelessWidget {
  final List<Map<String, dynamic>> guides;
  final bool isLoading;

  const PopularGuidesSection({
    super.key,
    required this.guides,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Guías diseñadas por expertos',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Copia cualquiera a tu cuenta personal',
          style: TextStyle(
            fontSize: 14,
            color: Color(0xFF6B7280),
          ),
        ),
        const SizedBox(height: 12),
        isLoading
            ? _buildMinimumHeightContainer(
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              )
            : guides.isEmpty
                ? _buildMinimumHeightContainer(
                    child: const Center(
                      child: Text(
                        'No hay guías disponibles',
                        style: TextStyle(
                          fontSize: 16,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ),
                  )
                : Container(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.4,
                    ),
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 1.1,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: guides.length,
                      itemBuilder: (context, index) {
                        final guide = guides[index];
                        final isPredefined = guide['isPredefined'] == true;

                        // Calcular días
                        String duration = 'Duración no especificada';
                        DateTime? start;
                        DateTime? end;
                        if (guide['startDate'] != null &&
                            guide['endDate'] != null) {
                          try {
                            if (guide['startDate'] is DateTime) {
                              start = guide['startDate'];
                            } else if (guide['startDate'] is Timestamp) {
                              start = guide['startDate'].toDate();
                            }
                            if (guide['endDate'] is DateTime) {
                              end = guide['endDate'];
                            } else if (guide['endDate'] is Timestamp) {
                              end = guide['endDate'].toDate();
                            }
                            if (start != null && end != null) {
                              final days = end.difference(start).inDays + 1;
                              duration = '$days día${days == 1 ? '' : 's'}';
                            }
                          } catch (_) {}
                        } else if (guide['duration'] != null) {
                          duration = guide['duration'].toString();
                        }

                        // Calcular actividades
                        int activities = 0;
                        if (guide['activities'] is int) {
                          activities = guide['activities'];
                        } else if (guide['activities'] is List) {
                          activities = (guide['activities'] as List).length;
                        } else if (guide['selectedActivities'] is List) {
                          activities =
                              (guide['selectedActivities'] as List).length;
                        } else if (guide['totalActivities'] != null) {
                          activities = guide['totalActivities'] as int;
                        }

                        return PopularGuideCard(
                          title: guide['title'] ?? 'Sin título',
                          duration: duration,
                          activities: activities,
                          imageUrl: guide['imageUrl'],
                          city: guide['city'] ?? guide['destination'],
                          isPredefined: isPredefined,
                          onTap: () {
                            Navigator.pushNamed(
                              context,
                              '/guide-detail',
                              arguments: {
                                'guideId': guide['id'],
                                'guideTitle': guide['title'],
                                'isPublic': true,
                              },
                            );
                          },
                          onCopyTap: isPredefined
                              ? () => _copyGuide(context, guide['id'])
                              : null,
                        );
                      },
                    ),
                  ),
        const SizedBox(height: 20),
      ],
    );
  }

  /// Construye un contenedor con altura mínima equivalente a 4 guías
  /// para mantener la consistencia del layout cuando no hay contenido
  Widget _buildMinimumHeightContainer({required Widget child}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculamos la altura para 4 guías en un grid de 2 columnas
        // Obtenemos el ancho disponible y calculamos el ancho de cada columna
        final availableWidth = constraints.maxWidth;
        final crossAxisSpacing = 12.0;
        final itemWidth = (availableWidth - crossAxisSpacing) / 2;

        // Con childAspectRatio: 1.1, la altura de cada item es menor al ancho
        final itemHeight = itemWidth / 1.1;

        // Para 4 guías necesitamos 2 filas + el espacio entre filas
        final mainAxisSpacing = 12.0;
        final totalHeight = (itemHeight * 2) + mainAxisSpacing;

        return SizedBox(
          height: totalHeight,
          width: double.infinity,
          child: child,
        );
      },
    );
  }

  void _copyGuide(BuildContext context, String guideId) async {
    try {
      // Mostrar loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Copiar la guía
      final copiedGuideId = await GuideService.copyPredefinedGuide(guideId);

      // Cerrar loading
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      if (copiedGuideId != null) {
        // Mostrar éxito y navegar a la guía copiada
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Guía copiada a tu cuenta'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );

          // Navegar a la guía copiada
          Navigator.pushNamed(
            context,
            '/guide-detail',
            arguments: {
              'guideId': copiedGuideId,
              'guideTitle': 'Tu guía personalizada',
            },
          );
        }
      } else {
        // Mostrar error
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Error al copiar la guía'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      // Cerrar loading si está abierto
      if (context.mounted) {
        Navigator.of(context).pop();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }
}
