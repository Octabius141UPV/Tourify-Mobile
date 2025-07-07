import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_places_flutter/google_places_flutter.dart';
import 'package:google_places_flutter/model/prediction.dart';
import 'package:tourify_flutter/services/api_service.dart';
import 'package:tourify_flutter/data/activity.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class AddActivityDialog extends StatefulWidget {
  final int dayNumber;
  final String guideId;
  final String city;
  final Function(Activity) onSave;

  const AddActivityDialog({
    super.key,
    required this.dayNumber,
    required this.guideId,
    required this.city,
    required this.onSave,
  });

  @override
  State<AddActivityDialog> createState() => _AddActivityDialogState();
}

class _AddActivityDialogState extends State<AddActivityDialog> {
  final _searchController = TextEditingController();
  Prediction? _selectedPlace;
  bool _isLoading = false;
  bool _isGeneratingActivity = false;
  bool _showCitySuggestion = false;

  @override
  void initState() {
    super.initState();

    // Listener para detectar cuando mostrar sugerencia de ciudad
    _searchController.addListener(_onSearchTextChanged);
  }

  void _onSearchTextChanged() {
    final text = _searchController.text.trim().toLowerCase();
    final cityLower = widget.city.toLowerCase();

    // Mostrar sugerencia si el usuario escribió algo pero no incluye la ciudad
    final shouldShowSuggestion = text.isNotEmpty &&
        text.length > 2 &&
        !text.contains(cityLower) &&
        !cityLower.contains(text);

    if (shouldShowSuggestion != _showCitySuggestion) {
      setState(() {
        _showCitySuggestion = shouldShowSuggestion;
      });
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchTextChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _generateActivityFromPlace() async {
    if (_selectedPlace == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, selecciona un lugar primero')),
      );
      return;
    }

    setState(() {
      _isGeneratingActivity = true;
    });

    try {
      final apiService = ApiService();

      // Llamar a la API para generar la actividad usando ApiService con autenticación
      final responseData = await apiService.createActivityFromPlace(
        activityName: _selectedPlace!.description ?? _searchController.text,
        cityName: widget.city,
      );

      if (responseData == null) {
        throw Exception('No se pudo obtener información de la actividad');
      }

      // Crear la nueva actividad con los datos de la API
      final newActivity = Activity(
        id: 'activity-${DateTime.now().millisecondsSinceEpoch}-${_selectedPlace!.placeId.hashCode}',
        title: _getSafeTitle(
            responseData, _selectedPlace!, _searchController.text),
        description: responseData['description'] ?? '',
        duration: _parseDuration(responseData['duration']) ?? 60,
        day: widget.dayNumber,
        order: 0, // Se actualizará cuando se añada a la lista
        images: responseData['images'] != null
            ? List<String>.from(responseData['images'])
            : [],
        city: widget.city,
        category: responseData['categoria'] ?? 'other',
        likes: 0,
        startTime: null,
        endTime: null,
        price: null,
        location: _selectedPlace!.lat != null && _selectedPlace!.lng != null
            ? LatLng(double.parse(_selectedPlace!.lat!),
                double.parse(_selectedPlace!.lng!))
            : null, // Usar coordenadas de Google Places
      );

      await widget.onSave(newActivity);

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al generar actividad: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingActivity = false;
        });
      }
    }
  }

  String _getSafeTitle(Map<String, dynamic> responseData,
      Prediction? selectedPlace, String searchText) {
    // Intentar obtener el título de la respuesta de la API
    final apiTitle = responseData['title']?.toString().trim();
    if (apiTitle != null && apiTitle.isNotEmpty) {
      return apiTitle;
    }

    // Si no hay título de la API, usar la descripción del lugar seleccionado
    final placeTitle = selectedPlace?.description?.trim();
    if (placeTitle != null && placeTitle.isNotEmpty) {
      return placeTitle;
    }

    // Como último recurso, usar el texto de búsqueda
    final searchTitle = searchText.trim();
    if (searchTitle.isNotEmpty) {
      return searchTitle;
    }

    // Si todo falla, usar un título por defecto
    return 'Actividad sin título';
  }

  int? _parseDuration(dynamic duration) {
    if (duration == null) return null;

    if (duration is int) return duration;
    if (duration is double) return duration.toInt();

    if (duration is String) {
      // Intentar parsear diferentes formatos de duración
      if (duration.contains(':')) {
        // Formato HH:MM
        final parts = duration.split(':');
        if (parts.length == 2) {
          final hours = int.tryParse(parts[0]) ?? 0;
          final minutes = int.tryParse(parts[1]) ?? 0;
          return hours * 60 + minutes;
        }
      } else {
        // Intentar parsear como número directo
        return int.tryParse(duration);
      }
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
          maxWidth: 600,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 30,
              offset: const Offset(0, 15),
              spreadRadius: 0,
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 5),
              spreadRadius: 0,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header mejorado con gradiente azul
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(28, 28, 28, 32),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF3B82F6),
                      Color(0xFF1E40AF),
                    ],
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: const Icon(
                            Icons.add_location_alt_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Nueva actividad',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'DÍA ${widget.dayNumber}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white.withOpacity(0.9),
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(
                                    Icons.location_city_rounded,
                                    color: Colors.white.withOpacity(0.8),
                                    size: 16,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(
                              Icons.close_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Contenido principal con scroll
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Campo de búsqueda mejorado
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Buscar lugar o actividad',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[800],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.1),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: GooglePlaceAutoCompleteTextField(
                              textEditingController: _searchController,
                              googleAPIKey:
                                  dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '',
                              inputDecoration: InputDecoration(
                                prefixIcon: Container(
                                  margin: const EdgeInsets.all(12),
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.location_on_rounded,
                                    color: Colors.blue[600],
                                    size: 20,
                                  ),
                                ),
                                hintText:
                                    'Ej: Torre Eiffel, Louvre, restaurantes...',
                                hintStyle: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 14,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Colors.grey[200]!,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Colors.grey[200]!,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Colors.blue[400]!,
                                    width: 2,
                                  ),
                                ),
                                filled: true,
                                fillColor: Colors.grey[50],
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 16),
                              ),
                              debounceTime: 600,
                              language: 'es',
                              isLatLngRequired: true,
                              getPlaceDetailWithLatLng:
                                  (Prediction prediction) {
                                setState(() {
                                  _selectedPlace = prediction;
                                });

                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Row(
                                      children: [
                                        const Icon(Icons.check_circle,
                                            color: Colors.white),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                              'Ubicación seleccionada: ${prediction.description}'),
                                        ),
                                      ],
                                    ),
                                    backgroundColor: Colors.green,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(10)),
                                    duration: const Duration(seconds: 3),
                                  ),
                                );
                              },
                              itemClick: (Prediction prediction) {
                                _searchController.text =
                                    prediction.description ?? '';
                                setState(() {
                                  _selectedPlace = prediction;
                                });
                              },
                              seperatedBuilder: const Divider(height: 1),
                              containerHorizontalPadding: 0,
                              itemBuilder:
                                  (context, index, Prediction prediction) {
                                return Container(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Icon(
                                          Icons.location_on_rounded,
                                          color: Colors.grey[600],
                                          size: 18,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              prediction.structuredFormatting
                                                      ?.mainText ??
                                                  prediction.description ??
                                                  '',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w500,
                                                fontSize: 14,
                                              ),
                                            ),
                                            if (prediction.structuredFormatting
                                                    ?.secondaryText !=
                                                null) ...[
                                              const SizedBox(height: 2),
                                              Text(
                                                prediction.structuredFormatting!
                                                    .secondaryText!,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),

                      // Sugerencia para incluir ciudad
                      if (_showCitySuggestion)
                        Container(
                          margin: const EdgeInsets.only(top: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.amber.withOpacity(0.1),
                                Colors.orange.withOpacity(0.05),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Colors.amber.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.lightbulb_outline_rounded,
                                  color: Colors.amber[700],
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Mejora tu búsqueda',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.amber[800],
                                      ),
                                    ),
                                    Text(
                                      'Incluye "${widget.city}" para resultados más precisos',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.amber[700],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  final currentText =
                                      _searchController.text.trim();
                                  _searchController.text =
                                      '$currentText ${widget.city}';
                                  setState(() {
                                    _showCitySuggestion = false;
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.amber[600],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    'Añadir',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Lugar seleccionado
                      if (_selectedPlace != null)
                        Container(
                          margin: const EdgeInsets.only(top: 20),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.green.withOpacity(0.05),
                                Colors.blue.withOpacity(0.05),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Colors.green.withOpacity(0.2)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.check_circle_outline_rounded,
                                  color: Colors.green[600],
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Lugar seleccionado',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.green[700],
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _selectedPlace!
                                              .structuredFormatting?.mainText ??
                                          _selectedPlace!.description ??
                                          '',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w500,
                                        fontSize: 14,
                                      ),
                                    ),
                                    if (_selectedPlace!.structuredFormatting
                                            ?.secondaryText !=
                                        null) ...[
                                      const SizedBox(height: 1),
                                      Text(
                                        _selectedPlace!.structuredFormatting!
                                            .secondaryText!,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Indicador de carga
                      if (_isGeneratingActivity)
                        Container(
                          margin: const EdgeInsets.only(top: 20),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.blue.withOpacity(0.05),
                                Colors.blue.withOpacity(0.10),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border:
                                Border.all(color: Colors.blue.withOpacity(0.2)),
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.blue[600]!),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Creando tu actividad...',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.blue[700],
                                      ),
                                    ),
                                    Text(
                                      'Estamos generando todos los detalles',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.blue[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 32),

                      // Botones de acción mejorados
                      Row(
                        children: [
                          Expanded(
                            flex: 1,
                            child: TextButton(
                              onPressed: (_isGeneratingActivity || _isLoading)
                                  ? null
                                  : () => Navigator.of(context).pop(),
                              style: TextButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                'Cancelar',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              onPressed: (_isGeneratingActivity ||
                                      _isLoading ||
                                      _selectedPlace == null)
                                  ? null
                                  : _generateActivityFromPlace,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue[600],
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                                shadowColor: Colors.transparent,
                              ),
                              child: _isGeneratingActivity
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                                Colors.white),
                                      ),
                                    )
                                  : Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.add_rounded, size: 18),
                                        const SizedBox(width: 8),
                                        const Text(
                                          'Añadir actividad',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
