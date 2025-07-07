import 'package:flutter/material.dart';
import 'package:tourify_flutter/data/activity.dart';

class EditActivityDialog extends StatefulWidget {
  final Activity activity;
  final Function(Activity) onSave;

  const EditActivityDialog({
    super.key,
    required this.activity,
    required this.onSave,
  });

  @override
  State<EditActivityDialog> createState() => _EditActivityDialogState();
}

class _EditActivityDialogState extends State<EditActivityDialog> {
  late TextEditingController _durationController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _durationController =
        TextEditingController(text: widget.activity.duration.toString());
  }

  @override
  void dispose() {
    _durationController.dispose();
    super.dispose();
  }

  void _handleSave() async {
    final duration = int.tryParse(_durationController.text);
    if (duration == null || duration <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('La duración debe ser un número válido mayor a 0')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final updatedActivity = Activity(
        id: widget.activity.id,
        title: widget.activity.title, // Mantener título original
        description:
            widget.activity.description, // Mantener descripción original
        duration: duration, // Solo actualizar duración
        day: widget.activity.day,
        order: widget.activity.order,
        images: widget.activity.images,
        city: widget.activity.city,
        category: widget.activity.category,
        likes: widget.activity.likes,
        startTime: widget.activity.startTime,
        endTime: widget.activity.endTime,
        price: widget.activity.price,
        location: widget.activity.location, // PRESERVAR ubicación existente
      );

      await widget.onSave(updatedActivity);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(
                  Icons.edit,
                  color: Colors.blue,
                  size: 24,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Editar duración',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed:
                      _isLoading ? null : () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Información de la actividad (solo lectura)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.location_on,
                          size: 18, color: Colors.grey),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.activity.title.isNotEmpty
                              ? widget.activity.title
                              : 'Sin título',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (widget.activity.description.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      widget.activity.description,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Duration field (editable)
            TextField(
              controller: _durationController,
              enabled: !_isLoading,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Duración (minutos) *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.access_time),
                helperText: 'Solo puedes modificar la duración de la actividad',
              ),
            ),
            const SizedBox(height: 24),

            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed:
                      _isLoading ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Guardar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
