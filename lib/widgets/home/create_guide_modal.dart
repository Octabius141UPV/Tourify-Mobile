import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:flutter/cupertino.dart';
import 'dart:io';
import 'package:google_places_flutter/google_places_flutter.dart';
import 'package:google_maps_webservice/places.dart' as places;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:tourify_flutter/screens/discover_screen.dart';

class CreateGuideModal extends StatefulWidget {
  const CreateGuideModal({super.key});

  @override
  State<CreateGuideModal> createState() => _CreateGuideModalState();
}

class _CreateGuideModalState extends State<CreateGuideModal> {
  String? _activeSection = 'where';
  DateTime? _startDate;
  DateTime? _endDate;
  String? _dateWarning;
  int _travelersCount = 1;
  String? _selectedCity;
  Set<String> _selectedModes = <String>{};
  final TextEditingController _destinationSearchController =
      TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _destinationSearchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.95,
      decoration: const BoxDecoration(
        color: Colors.transparent,
      ),
      child: Column(
        children: [
          const SizedBox(height: 70),
          Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Material(
                color: Colors.white,
                shape: const CircleBorder(),
                elevation: 2,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => Navigator.pop(context),
                  child: const Padding(
                    padding: EdgeInsets.all(12.0),
                    child: Icon(Icons.close, size: 24, color: Colors.black),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                child: Column(
                  children: [
                    _buildWhereSection(),
                    const SizedBox(height: 18),
                    _buildWhenSection(),
                    const SizedBox(height: 18),
                    _buildHowSection(),
                    // Espaciado adicional al final del contenido scrollable
                    const SizedBox(height: 120),
                  ],
                ),
              ),
            ),
          ),
          // Espaciado reducido para mover el botón más abajo
          const SizedBox(height: 20),
          _buildBottomButtons(),
        ],
      ),
    );
  }

  Widget _buildWhereSection() {
    final googleMapsApiKey = dotenv.env['GOOGLE_MAPS_API_KEY'];

    final firebaseApiKey = dotenv.env['FIREBASE_API_KEY'];

    if (googleMapsApiKey == null || firebaseApiKey == null) {
      debugPrint('Error: API keys no encontradas en las variables de entorno');
      return const Center(
        child: Text('Error: No se pudieron cargar las API keys necesarias'),
      );
    }

    final bool isInactive = _activeSection != null && _activeSection != 'where';

    return GestureDetector(
      onTap: () {
        setState(() {
          _activeSection = _activeSection == 'where' ? null : 'where';
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.ease,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isInactive ? Colors.grey[100] : Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isInactive ? 0.03 : 0.07),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.place_outlined,
                    color: isInactive ? Colors.grey[400] : Colors.black,
                    size: 28),
                const SizedBox(width: 10),
                Text(
                  '¿Dónde?',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: isInactive ? Colors.grey[600] : Colors.black,
                  ),
                ),
              ],
            ),
            if (_activeSection == 'where') ...[
              const SizedBox(height: 18),
              Row(
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Icon(Icons.search, color: Colors.grey, size: 24),
                  ),
                  Expanded(
                    child: GooglePlaceAutoCompleteTextField(
                      textEditingController: _destinationSearchController,
                      googleAPIKey: googleMapsApiKey,
                      inputDecoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Buscar destinos',
                        hintStyle: TextStyle(fontSize: 17, color: Colors.grey),
                        contentPadding:
                            EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                      ),
                      debounceTime: 400,
                      itemClick: (prediction) {
                        _destinationSearchController.text =
                            prediction.description!;
                        setState(() {
                          _selectedCity = prediction.description;
                        });
                        FocusScope.of(context).unfocus();
                        // Auto-abrir sección de fechas cuando se selecciona un destino
                        _goToSection('when');
                      },
                      language: 'es',
                      isLatLngRequired: true,
                      getPlaceDetailWithLatLng: (prediction) {
                        _destinationSearchController.text =
                            prediction.description!;
                        setState(() {
                          _selectedCity = prediction.description;
                        });
                        FocusScope.of(context).unfocus();
                        // Auto-abrir sección de fechas cuando se selecciona un destino
                        _goToSection('when');
                      },
                      // NOTA: Este widget no permite filtrar solo ciudades desde el frontend. Para mejores resultados, configura la API Key de Google Places para sugerir solo ciudades, o filtra manualmente los resultados.
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                'Sugerencias de destinos',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: isInactive ? Colors.grey[500] : Colors.black87,
                ),
              ),
              const SizedBox(height: 10),
              _buildDestinationSuggestions(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDestinationSuggestions() {
    return Column(
      children: [
        _buildDestinationSuggestion(
          icon: Icons.location_city,
          color: Colors.pink[100]!,
          title: 'París, Francia',
          subtitle: 'Por su ambiente romántico y monumentos icónicos',
        ),
        _buildDestinationSuggestion(
          icon: Icons.account_balance,
          color: Colors.blue[100]!,
          title: 'Berlín, Alemania',
          subtitle: 'Por su historia y vida cultural vibrante',
        ),
        _buildDestinationSuggestion(
          icon: Icons.account_balance,
          color: Colors.green[100]!,
          title: 'Budapest, Hungría',
          subtitle: 'Por lugares de interés como el Bastión de los Pescadores',
        ),
      ],
    );
  }

  Widget _buildDestinationSuggestion({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    return GestureDetector(
      onTap: () {
        _destinationSearchController.text = title;
        setState(() {
          _selectedCity = title;
          FocusScope.of(context).unfocus();
        });
        // Auto-abrir sección de fechas cuando se selecciona un destino
        _goToSection('when');
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.black54, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWhenSection() {
    final bool isInactive = _activeSection != null && _activeSection != 'when';

    return GestureDetector(
      onTap: () {
        setState(() {
          _activeSection = _activeSection == 'when' ? null : 'when';
          if (_activeSection == 'when') {
            Future.delayed(const Duration(milliseconds: 100), () {
              _scrollController.animateTo(
                _scrollController.position.maxScrollExtent * 0.3,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );
            });
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.ease,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isInactive ? Colors.grey[100] : Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isInactive ? 0.03 : 0.07),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.calendar_today_outlined,
                        color: isInactive ? Colors.grey[400] : Colors.black,
                        size: 28),
                    const SizedBox(width: 10),
                    Text(
                      'Fechas',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: isInactive ? Colors.grey[600] : Colors.black,
                      ),
                    ),
                  ],
                ),
                Text(
                  _startDate != null && _endDate != null
                      ? (_startDate!.isAtSameMomentAs(_endDate!)
                          ? '${_startDate!.day}/${_startDate!.month}/${_startDate!.year} (1 día)'
                          : '${_startDate!.day}/${_startDate!.month}/${_startDate!.year} - ${_endDate!.day}/${_endDate!.month}/${_endDate!.year}')
                      : 'Añade fechas',
                  style: TextStyle(
                    fontSize: 16,
                    color: isInactive ? Colors.grey[500] : Colors.black54,
                  ),
                ),
              ],
            ),
            if (_activeSection == 'when') ...[
              const SizedBox(height: 18),
              _buildExactDates(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildExactDates() {
    return Column(
      children: [
        TableCalendar(
          locale: 'es_ES',
          firstDay: DateTime.now(),
          lastDay: DateTime.now().add(const Duration(days: 365)),
          focusedDay: _startDate ?? DateTime.now(),
          selectedDayPredicate: (day) =>
              (_startDate != null && _endDate != null)
                  ? (day.isAtSameMomentAs(_startDate!) ||
                      day.isAtSameMomentAs(_endDate!))
                  : (day.isAtSameMomentAs(_startDate ?? DateTime.now())),
          rangeStartDay: _startDate,
          rangeEndDay: _endDate,
          onDaySelected: (selectedDay, focusedDay) {
            setState(() {
              if (_startDate == null) {
                // Primera selección: asignar fecha de inicio y automáticamente como fecha de fin
                _startDate = selectedDay;
                _endDate = selectedDay;
                _dateWarning = null;
              } else if (_startDate != null && _endDate != null) {
                // Si ya hay fechas seleccionadas
                if (selectedDay.isAtSameMomentAs(_startDate!)) {
                  // Si selecciona la misma fecha de inicio, mantener viaje de un día
                  return;
                } else if (selectedDay.isAtSameMomentAs(_endDate!)) {
                  // Si selecciona la misma fecha de fin, mantener el rango actual
                  return;
                } else if (_startDate!.isAtSameMomentAs(_endDate!)) {
                  // Segunda selección: cuando startDate == endDate (viaje de un día)
                  if (selectedDay.isAfter(_startDate!)) {
                    // Extender el rango hacia adelante
                    final daysSelected =
                        selectedDay.difference(_startDate!).inDays + 1;
                    if (daysSelected > 7) {
                      _dateWarning = 'No puedes seleccionar más de 7 días.';
                      // Mostrar advertencia pero mantener selección actual
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (Platform.isIOS) {
                          showCupertinoDialog(
                            context: context,
                            builder: (context) => CupertinoAlertDialog(
                              title: const Text('Aviso'),
                              content: const Text(
                                  'No puedes seleccionar más de 7 días.'),
                              actions: [
                                CupertinoDialogAction(
                                  isDefaultAction: true,
                                  onPressed: () => Navigator.of(context).pop(),
                                  child: const Text('Aceptar'),
                                ),
                              ],
                            ),
                          );
                        } else {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Aviso'),
                              content: const Text(
                                  'No puedes seleccionar más de 7 días.'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  child: const Text('Aceptar'),
                                ),
                              ],
                            ),
                          );
                        }
                      });
                    } else {
                      _endDate = selectedDay;
                      _dateWarning = null;
                    }
                  } else {
                    // Si selecciona una fecha anterior, reiniciar con esa como nueva fecha única
                    _startDate = selectedDay;
                    _endDate = selectedDay;
                    _dateWarning = null;
                  }
                } else {
                  // Tercera selección: ya hay un rango establecido (startDate != endDate)
                  // Resetear y empezar de nuevo con la nueva fecha seleccionada
                  _startDate = selectedDay;
                  _endDate = selectedDay;
                  _dateWarning = null;
                }
              }
            });
          },
          calendarStyle: CalendarStyle(
            todayDecoration: BoxDecoration(
              color: Colors.transparent,
              border: Border.all(color: Colors.blue, width: 1.5),
              shape: BoxShape.circle,
            ),
            rangeStartDecoration: const BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
            ),
            rangeEndDecoration: const BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
            ),
            withinRangeDecoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            selectedDecoration: const BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
            ),
            defaultDecoration: const BoxDecoration(
              color: Colors.transparent,
              shape: BoxShape.circle,
            ),
            weekendDecoration: const BoxDecoration(
              color: Colors.transparent,
              shape: BoxShape.circle,
            ),
            outsideDecoration: const BoxDecoration(
              color: Colors.transparent,
              shape: BoxShape.circle,
            ),
            todayTextStyle: TextStyle(
              color: Colors.blue[800],
              fontWeight: FontWeight.bold,
            ),
            rangeStartTextStyle: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
            rangeEndTextStyle: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
            withinRangeTextStyle: const TextStyle(
              color: Colors.blue,
              fontWeight: FontWeight.w600,
            ),
            selectedTextStyle: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          headerStyle: const HeaderStyle(
            formatButtonVisible: false,
            titleCentered: true,
            titleTextStyle: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          calendarFormat: CalendarFormat.month,
        ),
        if (_dateWarning != null) ...[
          const SizedBox(height: 16),
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red[300]!, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: Colors.red[700], size: 22),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      _dateWarning!,
                      style: TextStyle(
                        color: Colors.red[700],
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                      textAlign: TextAlign.left,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        if (_startDate != null && _endDate != null) ...[
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _startDate!.isAtSameMomentAs(_endDate!)
                  ? 'Seleccionado: ${_startDate!.day}/${_startDate!.month}/${_startDate!.year} (1 día)'
                  : 'Seleccionado: ${_startDate!.day}/${_startDate!.month}/${_startDate!.year} - ${_endDate!.day}/${_endDate!.month}/${_endDate!.year}',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildHowSection() {
    final bool isInactive = _activeSection != null && _activeSection != 'how';

    return GestureDetector(
      onTap: () {
        setState(() {
          _activeSection = _activeSection == 'how' ? null : 'how';
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.ease,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isInactive ? Colors.grey[100] : Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isInactive ? 0.03 : 0.07),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.psychology_outlined,
                        color: isInactive ? Colors.grey[400] : Colors.black,
                        size: 28),
                    const SizedBox(width: 10),
                    Text(
                      '¿Cómo?',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: isInactive ? Colors.grey[600] : Colors.black,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$_travelersCount ${_travelersCount == 1 ? 'viajero' : 'viajeros'}',
                      style: TextStyle(
                        fontSize: 14,
                        color: isInactive ? Colors.grey[500] : Colors.black54,
                      ),
                    ),
                    if (_selectedModes.isNotEmpty)
                      Text(
                        _selectedModes.join(', '),
                        style: TextStyle(
                          fontSize: 12,
                          color: isInactive ? Colors.grey[400] : Colors.blue,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ],
            ),
            if (_activeSection == 'how') ...[
              const SizedBox(height: 20),
              // Sección de número de viajeros
              Text(
                'Número de viajeros',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isInactive ? Colors.grey[600] : Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline,
                            color: Color(0xFF2563EB)),
                        onPressed: _travelersCount > 1
                            ? () {
                                setState(() {
                                  _travelersCount--;
                                });
                              }
                            : null,
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          '$_travelersCount',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline,
                            color: Color(0xFF2563EB)),
                        onPressed: () {
                          setState(() {
                            _travelersCount++;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Sección de modo de viaje
              Text(
                'Estilo de viaje',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isInactive ? Colors.grey[600] : Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              _buildTravelModes(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTravelModes() {
    final modes = [
      {
        'id': 'cultura',
        'name': 'Cultura',
        'icon': Icons.museum_outlined,
        'color': Colors.purple,
        'description': 'Museos, arte e historia'
      },
      {
        'id': 'fiesta',
        'name': 'Fiesta',
        'icon': Icons.nightlife_outlined,
        'color': Colors.pink,
        'description': 'Vida nocturna y entretenimiento'
      },
    ];

    return Column(
      children: modes.map((mode) {
        final isSelected = _selectedModes.contains(mode['id']);
        final color = mode['color'] as Color;

        return GestureDetector(
          onTap: () {
            setState(() {
              if (isSelected) {
                _selectedModes.remove(mode['id']);
              } else {
                _selectedModes.add(mode['id'] as String);
              }
            });
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected ? color.withOpacity(0.1) : Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? color : Colors.grey[300]!,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isSelected ? color : Colors.grey[400],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    mode['icon'] as IconData,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        mode['name'] as String,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? color : Colors.black87,
                        ),
                      ),
                      Text(
                        mode['description'] as String,
                        style: TextStyle(
                          fontSize: 14,
                          color: isSelected
                              ? color.withOpacity(0.8)
                              : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Icon(
                    Icons.check_circle,
                    color: color,
                    size: 24,
                  ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBottomButtons() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      child: _activeSection == 'how'
          ? _buildFinalButtons()
          : Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF60A5FA), Color(0xFF2563EB)],
                      ),
                    ),
                    child: ElevatedButton.icon(
                      onPressed: () {
                        if (_activeSection == 'where') {
                          _goToSection('when');
                        } else if (_activeSection == 'when') {
                          _goToSection('how');
                        }
                      },
                      icon:
                          const Icon(Icons.arrow_forward, color: Colors.white),
                      label: const Text(
                        'Siguiente',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildFinalButtons() {
    return Column(
      children: [
        // Botón "Crear guía" (principal)
        Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF60A5FA), Color(0xFF2563EB)],
                  ),
                ),
                child: ElevatedButton.icon(
                  onPressed: () {
                    if (!_validateForm()) return;

                    // Navegar al discover para crear guía privada
                    Navigator.push(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (context, animation, secondaryAnimation) =>
                            DiscoverScreen(
                          destination: _selectedCity,
                          startDate: _startDate,
                          endDate: _endDate,
                          travelers: _travelersCount,
                          travelModes: _selectedModes.toList(),
                        ),
                        transitionDuration: Duration.zero,
                        reverseTransitionDuration: Duration.zero,
                      ),
                    );
                  },
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: const Text(
                    'Crear guía',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _goToSection(String section) {
    setState(() {
      _activeSection = section;
    });
    if (section == 'when') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent * 0.3,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      });
    }
  }

  bool _validateForm() {
    // Validar que todos los campos estén rellenados
    if (_selectedCity == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, selecciona un destino'),
          backgroundColor: Colors.red,
        ),
      );
      _goToSection('where');
      return false;
    }

    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, selecciona las fechas'),
          backgroundColor: Colors.red,
        ),
      );
      _goToSection('when');
      return false;
    }

    return true;
  }
}
