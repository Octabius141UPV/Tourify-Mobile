import 'package:tourify_flutter/data/activity.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ActivityTile extends StatelessWidget {
  final Activity activity;
  final bool isSelected;
  final int? pinNum;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onExportMaps;
  final VoidCallback? onExportCalendar;
  final VoidCallback? onReserve;
  final bool canEdit;

  // Campos opcionales de horario provenientes del item de Firestore
  final DateTime? startTime;
  final DateTime? endTime;

  const ActivityTile({
    super.key,
    required this.activity,
    this.isSelected = false,
    this.pinNum,
    this.onEdit,
    this.onDelete,
    this.onExportMaps,
    this.onExportCalendar,
    this.onReserve,
    this.canEdit = false,
    this.startTime,
    this.endTime,
  });

  @override
  Widget build(BuildContext context) {
    final bool descripcionLarga = activity.description.length > 80;
    bool verMas = false;
    return StatefulBuilder(
      builder: (context, setState) {
        return GestureDetector(
          onTap: null, // Se puede parametrizar si se necesita
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: isSelected
                  ? Border.all(color: Color(0xFF2196F3), width: 3)
                  : null,
              boxShadow: [
                BoxShadow(
                  color: isSelected
                      ? Color(0xFF2196F3).withOpacity(0.3)
                      : Colors.black.withOpacity(0.07),
                  blurRadius: isSelected ? 16 : 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Imagen con overlay de duración
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(18),
                        topRight: Radius.circular(18),
                      ),
                      child: activity.images.isNotEmpty
                          ? Image.network(
                              activity.images.first,
                              width: double.infinity,
                              height: 160,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Image.asset(
                                  'assets/images/no-image.png',
                                  width: double.infinity,
                                  height: 160,
                                  fit: BoxFit.cover,
                                );
                              },
                            )
                          : Image.asset(
                              'assets/images/no-image.png',
                              width: double.infinity,
                              height: 160,
                              fit: BoxFit.cover,
                            ),
                    ),
                    // Horario arriba izquierda (sustituye duración)
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.85),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.access_time,
                                size: 16, color: Colors.grey),
                            const SizedBox(width: 4),
                            _buildTimeBadge(activity,
                                startTime: startTime, endTime: endTime),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Título con menú de 3 puntitos
                      Row(
                        children: [
                          const Icon(Icons.location_on,
                              size: 18, color: Color(0xFF2196F3)),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              pinNum != null
                                  ? '$pinNum. ${activity.title}'
                                  : activity.title.isNotEmpty
                                      ? activity.title
                                      : 'Sin título',
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (canEdit)
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert,
                                  color: Colors.black87),
                              onSelected: (value) {
                                if (value == 'edit' && onEdit != null) {
                                  onEdit!();
                                } else if (value == 'delete' &&
                                    onDelete != null) {
                                  onDelete!();
                                } else if (value == 'maps' &&
                                    onExportMaps != null) {
                                  onExportMaps!();
                                } else if (value == 'calendar' &&
                                    onExportCalendar != null) {
                                  onExportCalendar!();
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Row(
                                    children: [
                                      Icon(Icons.edit, size: 18),
                                      SizedBox(width: 8),
                                      Text('Editar'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete,
                                          size: 18, color: Colors.red),
                                      SizedBox(width: 8),
                                      Text('Eliminar'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'maps',
                                  child: Row(
                                    children: [
                                      Icon(Icons.map,
                                          size: 18, color: Colors.green),
                                      SizedBox(width: 8),
                                      Text('Abrir en Maps'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'calendar',
                                  child: Row(
                                    children: [
                                      Icon(Icons.calendar_today,
                                          size: 18, color: Colors.blue),
                                      SizedBox(width: 8),
                                      Text('Añadir a calendario'),
                                    ],
                                  ),
                                ),
                              ],
                              color: Colors.white,
                              elevation: 8,
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        !descripcionLarga || verMas
                            ? activity.description
                            : activity.description.substring(0, 80) + '...',
                        style: const TextStyle(
                            fontSize: 14, color: Colors.black87),
                        maxLines: verMas ? null : 2,
                        overflow: verMas
                            ? TextOverflow.visible
                            : TextOverflow.ellipsis,
                      ),
                      if (activity.googleRating != null) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.star,
                                color: Colors.amber, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              activity.googleRating!.toStringAsFixed(1),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (descripcionLarga && !verMas)
                        GestureDetector(
                          onTap: () => setState(() => verMas = true),
                          child: const Padding(
                            padding: EdgeInsets.only(top: 2),
                            child: Text(
                              'Ver más',
                              style: TextStyle(
                                color: Color(0xFF2196F3),
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),
                      if (activity.category?.toLowerCase() == 'cultural' ||
                          activity.category?.toLowerCase() == 'cultura')
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF2196F3),
                              side: const BorderSide(
                                  color: Color(0xFF2196F3), width: 1.5),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24)),
                              textStyle: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w600),
                            ),
                            icon:
                                const Icon(Icons.confirmation_number, size: 18),
                            label: const Text('Reservar actividad'),
                            onPressed: onReserve,
                          ),
                        ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// Helper para formatear horario de la actividad si existe en Firestore
Widget _buildTimeBadge(Activity activity,
    {DateTime? startTime, DateTime? endTime}) {
  // El `Activity` de mock_activities.dart no tiene startTime; se muestra duración solo si no hay hora.
  // Este widget se usa con datos provenientes de Firestore en `GuideDetailScreen`,
  // donde cada item del día incluye `startTime`/`endTime`. Aquí, como tenemos solo el modelo
  // local de catálogo, mostramos la duración como fallback.
  String text;
  if (startTime != null && endTime != null) {
    String two(int n) => n.toString().padLeft(2, '0');
    final s = '${two(startTime.hour)}:${two(startTime.minute)}';
    final e = '${two(endTime.hour)}:${two(endTime.minute)}';
    text = '$s - $e';
  } else {
    text = '${activity.duration} min';
  }
  return Text(text,
      style: const TextStyle(fontSize: 13, color: Colors.black87));
}
