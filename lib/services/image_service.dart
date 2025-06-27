class ImageService {
  /// URLs de respaldo más estables (Picsum Photos como alternativa)
  static const Map<String, String> _fallbackImages = {
    'berlin': 'https://picsum.photos/800/600?random=1',
    'budapest': 'https://picsum.photos/800/600?random=2',
    'roma': 'https://picsum.photos/800/600?random=3',
    'milan': 'https://picsum.photos/800/600?random=4',
    'paris': 'https://picsum.photos/800/600?random=5',
    'london': 'https://picsum.photos/800/600?random=6',
    'amsterdam': 'https://picsum.photos/800/600?random=7',
    'barcelona': 'https://picsum.photos/800/600?random=8',
    'valencia': 'https://picsum.photos/800/600?random=9',
    'madrid': 'https://picsum.photos/800/600?random=10',
    'sevilla': 'https://picsum.photos/800/600?random=11',
    'default': 'https://picsum.photos/800/600?random=12',
  };

  /// URLs alternativas con Pexels (más estables)
  static const Map<String, String> _pexelsImages = {
    'berlin':
        'https://images.pexels.com/photos/109630/pexels-photo-109630.jpeg?auto=compress&cs=tinysrgb&w=800&h=600&fit=crop',
    'budapest':
        'https://images.unsplash.com/photo-1622115469132-124ec9f88fca?auto=compress&w=800&h=600&fit=crop',
    'roma':
        'https://images.pexels.com/photos/2064827/pexels-photo-2064827.jpeg?auto=compress&cs=tinysrgb&w=800&h=600&fit=crop',
    'milan':
        'https://images.unsplash.com/photo-1610016302534-6f67f1c968d8?auto=compress&w=800&h=600&fit=crop',
    'paris':
        'https://images.pexels.com/photos/161853/eiffel-tower-paris-france-tower-161853.jpeg?auto=compress&cs=tinysrgb&w=800&h=600&fit=crop',
    'london':
        'https://images.pexels.com/photos/460672/pexels-photo-460672.jpeg?auto=compress&cs=tinysrgb&w=800&h=600&fit=crop',
    'amsterdam':
        'https://images.pexels.com/photos/2031706/pexels-photo-2031706.jpeg?auto=compress&cs=tinysrgb&w=800&h=600&fit=crop',
    'barcelona':
        'https://images.pexels.com/photos/1388030/pexels-photo-1388030.jpeg?auto=compress&cs=tinysrgb&w=800&h=600&fit=crop',
    'valencia':
        'https://images.pexels.com/photos/3586966/pexels-photo-3586966.jpeg?auto=compress&cs=tinysrgb&w=800&h=600&fit=crop',
    'madrid':
        'https://images.pexels.com/photos/1388030/pexels-photo-1388030.jpeg?auto=compress&cs=tinysrgb&w=800&h=600&fit=crop',
    'sevilla':
        'https://images.pexels.com/photos/3586966/pexels-photo-3586966.jpeg?auto=compress&cs=tinysrgb&w=800&h=600&fit=crop',
    'default':
        'https://images.pexels.com/photos/290595/pexels-photo-290595.jpeg?auto=compress&cs=tinysrgb&w=800&h=600&fit=crop',
  };

  /// Obtiene una imagen específica para una ciudad (ahora usa URLs más estables)
  static String getCityImage(String city, {bool useFallback = false}) {
    final cityKey =
        city.toLowerCase().replaceAll('á', 'a').replaceAll('í', 'i');

    if (useFallback) {
      return _fallbackImages[cityKey] ?? _fallbackImages['default']!;
    }

    // Primero intenta con Pexels (más estable)
    if (_pexelsImages.containsKey(cityKey)) {
      return _pexelsImages[cityKey]!;
    }

    // Fallback a URLs de Unsplash simplificadas
    switch (cityKey) {
      case 'berlin':
        return 'https://images.unsplash.com/photo-1566911753692-9cef1de4d5b4?w=800&h=600&fit=crop&crop=center';
      case 'budapest':
        return 'https://images.unsplash.com/photo-1622115469132-124ec9f88fca?w=800&h=600&fit=crop&crop=center';
      case 'roma':
      case 'rome':
        return 'https://images.unsplash.com/photo-1515542622106-78bda8ba0e5b?w=800&h=600&fit=crop&crop=center';
      case 'milan':
        return 'https://images.unsplash.com/photo-1610016302534-6f67f1c968d8?w=800&h=600&fit=crop&crop=center';
      case 'paris':
        return 'https://images.unsplash.com/photo-1502602898657-3e91760cbb34?w=800&h=600&fit=crop&crop=center';
      case 'london':
        return 'https://images.unsplash.com/photo-1513635269975-59663e0ac1ad?w=800&h=600&fit=crop&crop=center';
      case 'amsterdam':
        return 'https://images.unsplash.com/photo-1534351590666-13e3e96b5017?w=800&h=600&fit=crop&crop=center';
      case 'barcelona':
        return 'https://images.unsplash.com/photo-1539037116277-4db20889f2d4?w=800&h=600&fit=crop&crop=center';
      case 'valencia':
        return 'https://images.unsplash.com/photo-1559827260-dc66d52bef19?w=800&h=600&fit=crop&crop=center';
      case 'madrid':
        return 'https://images.unsplash.com/photo-1539037116277-4db20889f2d4?w=800&h=600&fit=crop&crop=center';
      case 'sevilla':
        return 'https://images.unsplash.com/photo-1570298043882-2471d4eb3a67?w=800&h=600&fit=crop&crop=center';
      default:
        return _fallbackImages['default']!;
    }
  }

  /// Método simple que garantiza imágenes funcionales usando Picsum
  static String getReliableCityImage(String city) {
    return getCityImage(city, useFallback: true);
  }

  /// Obtiene una imagen específica para una actividad según su título y ciudad
  static String getActivityImage(
      String activityTitle, String city, String category) {
    // Primero, intentamos buscar por título específico
    final titleKey = '${city.toLowerCase()}_${activityTitle.toLowerCase()}';

    // Si tenemos una imagen específica para esta actividad, la devolvemos
    if (popularGuidesImages.containsKey(titleKey)) {
      return popularGuidesImages[titleKey]!;
    }

    // Si no, devolvemos una imagen por categoría y ciudad
    return getCategoryImage(category, city);
  }

  /// Obtiene una imagen por categoría y ciudad
  static String getCategoryImage(String category, String city) {
    switch (category.toLowerCase()) {
      case 'cultural':
      case 'museum':
      case 'monument':
        return 'https://images.unsplash.com/photo-1529260830199-42c24126f198?w=800&h=600&fit=crop&crop=center';
      case 'food':
      case 'restaurant':
      case 'comida':
        return 'https://images.unsplash.com/photo-1555939594-58d7cb561ad1?w=800&h=600&fit=crop&crop=center';
      case 'nightlife':
      case 'fiesta':
      case 'bar':
        return 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=800&h=600&fit=crop&crop=center';
      case 'tour':
      case 'sightseeing':
        return 'https://images.unsplash.com/photo-1539650116574-75c0c6d73d0e?w=800&h=600&fit=crop&crop=center';
      case 'shopping':
        return 'https://images.unsplash.com/photo-1441986300917-64674bd600d8?w=800&h=600&fit=crop&crop=center';
      case 'outdoor':
      case 'nature':
        return 'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=800&h=600&fit=crop&crop=center';
      default:
        return getCityImage(city);
    }
  }

  /// Lista de URLs de imágenes de alta calidad para ciudades específicas
  static Map<String, String> get citySpecificImages => {
        // Berlín - Puerta de Brandenburgo
        'berlin':
            'https://images.unsplash.com/photo-1566911753692-9cef1de4d5b4?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80',

        // Budapest - Parlamento húngaro al atardecer (vista icónica)
        'budapest':
            'https://images.unsplash.com/photo-1622115469132-124ec9f88fca?q=80&w=1073&auto=format&fit=crop&ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',

        // Roma - Coliseo
        'roma':
            'https://images.unsplash.com/photo-1515542622106-78bda8ba0e5b?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80',
        'rome':
            'https://images.unsplash.com/photo-1515542622106-78bda8ba0e5b?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80',

        // Milán - Duomo (catedral icónica de Milán)
        'milan':
            'https://images.unsplash.com/photo-1610016302534-6f67f1c968d8?q=80&w=1075&auto=format&fit=crop&ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
        'milán':
            'https://images.unsplash.com/photo-1610016302534-6f67f1c968d8?q=80&w=1075&auto=format&fit=crop&ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',

        // París - Torre Eiffel
        'paris':
            'https://images.unsplash.com/photo-1502602898657-3e91760cbb34?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80',
        'parís':
            'https://images.unsplash.com/photo-1502602898657-3e91760cbb34?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80',

        // Londres - Big Ben
        'london':
            'https://images.unsplash.com/photo-1513635269975-59663e0ac1ad?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80',
        'londres':
            'https://images.unsplash.com/photo-1513635269975-59663e0ac1ad?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80',

        // Amsterdam - Canales
        'amsterdam':
            'https://images.unsplash.com/photo-1534351590666-13e3e96b5017?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80',

        // Barcelona - Sagrada Familia
        'barcelona':
            'https://images.unsplash.com/photo-1539037116277-4db20889f2d4?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80',
      };

  /// Mapeo completo de todas las imágenes de las actividades de las guías populares
  static Map<String, String> get popularGuidesImages => {
        // ============================================================================
        // BERLÍN - Todas las actividades de la guía "Berlín en 3 días"
        // ============================================================================

        // Día 1 - Berlín - URLs verificadas
        'berlín_puerta de brandenburgo':
            'https://images.unsplash.com/photo-1638873443476-8e3f1e789d6c?q=80&w=735&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
        'berlin_puerta de brandenburgo':
            'https://images.unsplash.com/photo-1638873443476-8e3f1e789d6c?q=80&w=735&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
        'berlín_reichstag':
            'https://images.unsplash.com/photo-1749976638266-8c0225faf3cb?q=80&w=1170&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
        'berlin_reichstag':
            'https://images.unsplash.com/photo-1749976638266-8c0225faf3cb?q=80&w=1170&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
        'berlín_unter den linden':
            'https://images.unsplash.com/photo-1675935227009-dac2f276cfbd?w=500&auto=format&fit=crop&q=60&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxzZWFyY2h8MTN8fEJlcmxpbiUyMFVudGVyJTIwZGVuJTIwTGluZGVufGVufDB8fDB8fHwy',
        'berlin_unter den linden':
            'https://images.unsplash.com/photo-1675935227009-dac2f276cfbd?w=500&auto=format&fit=crop&q=60&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxzZWFyY2h8MTN8fEJlcmxpbiUyMFVudGVyJTIwZGVuJTIwTGluZGVufGVufDB8fDB8fHwy',

        // Día 2 - Berlín - URLs verificadas
        'berlín_muro de berlín':
            'https://images.unsplash.com/photo-1561617398-f5b36165c26a?q=80&w=1374&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
        'berlin_muro de berlín':
            'https://images.unsplash.com/photo-1561617398-f5b36165c26a?q=80&w=1374&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
        'berlín_checkpoint charlie':
            'https://images.unsplash.com/photo-1559116284-9c57b7a01f7a?q=80&w=1170&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
        'berlin_checkpoint charlie':
            'https://images.unsplash.com/photo-1559116284-9c57b7a01f7a?q=80&w=1170&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
        'berlín_isla de los museos':
            'https://images.unsplash.com/photo-1649717233552-54a6564d442b?q=80&w=735&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
        'berlin_isla de los museos':
            'https://images.unsplash.com/photo-1649717233552-54a6564d442b?q=80&w=735&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',

        // Día 3 - Berlín - URLs verificadas
        'berlín_torre de tv de berlín':
            'https://images.unsplash.com/photo-1560930950-5cc20e80e392?q=80&w=1170&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
        'berlin_torre de tv de berlín':
            'https://images.unsplash.com/photo-1560930950-5cc20e80e392?q=80&w=1170&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
        'berlín_alexanderplatz':
            'https://images.unsplash.com/photo-1684059732179-7710fbb2688b?q=80&w=1170&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
        'berlin_alexanderplatz':
            'https://images.unsplash.com/photo-1684059732179-7710fbb2688b?q=80&w=1170&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
        'berlín_barrio de prenzlauer berg':
            'https://images.unsplash.com/photo-1719451795806-0d45af6de439?q=80&w=1074&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
        'berlin_barrio de prenzlauer berg':
            'https://images.unsplash.com/photo-1719451795806-0d45af6de439?q=80&w=1074&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',

        // ============================================================================
        // BUDAPEST - Todas las actividades de la guía "Budapest, la perla del Danubio"
        // ============================================================================

        // Día 1 - Budapest - URLs verificadas
        'budapest_parlamento húngaro':
            'https://images.unsplash.com/photo-1622115469132-124ec9f88fca?q=80&w=1073&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
        'budapest_basílica de san esteban':
            'https://images.unsplash.com/photo-1622616350599-39a5a32cef40?q=80&w=1170&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
        'budapest_mercado central':
            'https://images.unsplash.com/photo-1736056338252-ea0dca186862?q=80&w=1170&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',

        // Día 2 - Budapest - URLs verificadas
        'budapest_castillo de buda':
            'https://images.unsplash.com/photo-1711545577698-47234a605fd6?q=80&w=914&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
        'budapest_bastión de los pescadores':
            'https://images.unsplash.com/photo-1634313858445-e0880d75f49d?q=80&w=1170&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
        'budapest_iglesia de matías':
            'https://images.unsplash.com/photo-1610961595311-0d596322c01c?q=80&w=1170&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',

        // Día 3 - Budapest - URLs verificadas
        'budapest_balneario széchenyi':
            'https://images.unsplash.com/photo-1733485358262-80c717a9fb2a?q=80&w=1175&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
        'budapest_avenida váci':
            'https://images.unsplash.com/photo-1697799313360-fe4830ad533c?q=80&w=1171&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',

        // Día 4 - Budapest - URLs verificadas
        'budapest_crucero por el danubio':
            'https://images.unsplash.com/photo-1663857040527-13f00d0a2d5d?q=80&w=1170&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
        'budapest_ruin bars':
            'https://images.unsplash.com/photo-1664312848897-75c0d20f23fa?q=80&w=1170&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',

        // ============================================================================
        // ROMA - Todas las actividades de la guía "Roma eterna"
        // ============================================================================

        // Día 1 - Roma - URLs verificadas
        'roma_coliseo romano':
            'https://images.unsplash.com/photo-1627673989543-af63ca11a0a0?q=80&w=1170&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
        'rome_coliseo romano':
            'https://images.unsplash.com/photo-1627673989543-af63ca11a0a0?q=80&w=1170&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
        'roma_foro romano':
            'https://images.unsplash.com/photo-1634535441358-4b8fa9a2d0cb?q=80&w=1074&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
        'rome_foro romano':
            'https://images.unsplash.com/photo-1634535441358-4b8fa9a2d0cb?q=80&w=1074&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
        'roma_monte palatino':
            'https://images.unsplash.com/photo-1661960106336-1996b21d02e0?q=80&w=1032&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
        'rome_monte palatino':
            'https://images.unsplash.com/photo-1661960106336-1996b21d02e0?q=80&w=1032&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',

        // Día 2 - Roma - URLs verificadas
        'roma_ciudad del vaticano':
            'https://images.unsplash.com/photo-1546946590-5d739771abc4?q=80&w=1176&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
        'rome_ciudad del vaticano':
            'https://images.unsplash.com/photo-1546946590-5d739771abc4?q=80&w=1176&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
        'roma_basílica de san pedro':
            'https://images.unsplash.com/photo-1672950972884-7cf700885593?q=80&w=1170&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
        'rome_basílica de san pedro':
            'https://images.unsplash.com/photo-1672950972884-7cf700885593?q=80&w=1170&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
        'roma_castel sant\'angelo':
            'https://images.unsplash.com/photo-1565537616283-221109348b0d?q=80&w=1110&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
        'rome_castel sant\'angelo':
            'https://images.unsplash.com/photo-1565537616283-221109348b0d?q=80&w=1110&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',

        // Día 3 - Roma - URLs verificadas
        'roma_fontana de trevi':
            'https://images.unsplash.com/photo-1720224048012-812d18a7960d?q=80&w=1074&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
        'rome_fontana de trevi':
            'https://images.unsplash.com/photo-1720224048012-812d18a7960d?q=80&w=1074&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
        'roma_plaza de españa':
            'https://images.unsplash.com/photo-1654606543461-414aa90ff838?q=80&w=1195&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
        'rome_plaza de españa':
            'https://images.unsplash.com/photo-1654606543461-414aa90ff838?q=80&w=1195&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
        'roma_panteón':
            'https://images.unsplash.com/photo-1684275507407-28032196faeb?q=80&w=1170&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
        'rome_panteón':
            'https://images.unsplash.com/photo-1684275507407-28032196faeb?q=80&w=1170&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',

        // Día 4 - Roma - URLs verificadas
        'roma_villa borghese':
            'https://images.unsplash.com/photo-1710107365687-fa90a6f2eb35?q=80&w=1074&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
        'rome_villa borghese':
            'https://images.unsplash.com/photo-1710107365687-fa90a6f2eb35?q=80&w=1074&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
        'roma_trastevere':
            'https://images.unsplash.com/photo-1708628934823-a37e3fe0bb4e?q=80&w=1170&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
        'rome_trastevere':
            'https://images.unsplash.com/photo-1708628934823-a37e3fe0bb4e?q=80&w=1170&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
        'roma_campo de\' fiori':
            'https://images.unsplash.com/photo-1616362434905-02ee87df771d?q=80&w=1170&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
        'rome_campo de\' fiori':
            'https://images.unsplash.com/photo-1616362434905-02ee87df771d?q=80&w=1170&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',

        // Día 5 - Roma - URLs verificadas
        'roma_termas de caracalla':
            'https://images.unsplash.com/photo-1559220758-8e0a0b24a707?q=80&w=1032&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
        'rome_termas de caracalla':
            'https://images.unsplash.com/photo-1559220758-8e0a0b24a707?q=80&w=1032&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
        'roma_plaza navona':
            'https://images.unsplash.com/photo-1662398885856-cf2ab6e981b2?q=80&w=1174&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
        'rome_plaza navona':
            'https://images.unsplash.com/photo-1662398885856-cf2ab6e981b2?q=80&w=1174&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
        'roma_aventino y ojo de la cerradura':
            'https://images.unsplash.com/photo-1721481954096-ad9be199f87d?q=80&w=1173&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
        'rome_aventino y ojo de la cerradura':
            'https://images.unsplash.com/photo-1721481954096-ad9be199f87d?q=80&w=1173&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',

        // ============================================================================
        // MILÁN - Todas las actividades de la guía "Milán, moda y cultura"
        // ============================================================================

        // Día 1 - Milán
        // Día 1 - Milán - URLs verificadas
        'milán_duomo de milán':
            'https://images.unsplash.com/photo-1610016302534-6f67f1c968d8?q=80&w=1075&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
        'milan_duomo de milán':
            'https://images.unsplash.com/photo-1610016302534-6f67f1c968d8?q=80&w=1075&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
        'milán_galleria vittorio emanuele ii':
            'https://images.unsplash.com/photo-1716793165604-6466a820ecfa?q=80&w=1170&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
        'milan_galleria vittorio emanuele ii':
            'https://images.unsplash.com/photo-1716793165604-6466a820ecfa?q=80&w=1170&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
        'milán_teatro la scala':
            'https://images.unsplash.com/photo-1635886630467-a1b8e34a10c1?q=80&w=1077&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
        'milan_teatro la scala':
            'https://images.unsplash.com/photo-1635886630467-a1b8e34a10c1?q=80&w=1077&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',

        // Día 2 - Milán - URLs verificadas
        'milán_castillo sforzesco':
            'https://images.unsplash.com/photo-1602059201105-276c01c1b657?q=80&w=1170&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
        'milan_castillo sforzesco':
            'https://images.unsplash.com/photo-1602059201105-276c01c1b657?q=80&w=1170&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
        'milán_parque sempione':
            'https://images.unsplash.com/photo-1651995859199-2b0695c07ce3?q=80&w=1170&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
        'milan_parque sempione':
            'https://images.unsplash.com/photo-1651995859199-2b0695c07ce3?q=80&w=1170&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
        'milán_barrio de brera':
            'https://images.unsplash.com/photo-1699107968492-36846521377a?q=80&w=1170&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
        'milan_barrio de brera':
            'https://images.unsplash.com/photo-1699107968492-36846521377a?q=80&w=1170&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',

        // Día 3 - Milán - URLs verificadas
        'milán_quadrilatero della moda':
            'https://images.unsplash.com/photo-1720540545257-dc21cebf5b4e?q=80&w=1170&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
        'milan_quadrilatero della moda':
            'https://images.unsplash.com/photo-1720540545257-dc21cebf5b4e?q=80&w=1170&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
        'milán_navigli':
            'https://images.unsplash.com/photo-1694453722395-f4c9400a35d5?q=80&w=1079&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
        'milan_navigli':
            'https://images.unsplash.com/photo-1694453722395-f4c9400a35d5?q=80&w=1079&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',

        // ============================================================================
        // ACTIVIDADES ADICIONALES DEL GUIDE_SERVICE
        // ============================================================================

        // URLs originales que están en guide_service.dart sin actualizar
        'berlín_fernsehturm':
            'https://images.unsplash.com/photo-1566639473150-a6d2c9b87b1d?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80',
        'berlin_fernsehturm':
            'https://images.unsplash.com/photo-1566639473150-a6d2c9b87b1d?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80',

        // Imágenes genéricas para actividades que no tienen imagen específica
        'berlín_generic':
            'https://images.unsplash.com/photo-1566911753692-9cef1de4d5b4?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80',
        'budapest_generic':
            'https://images.unsplash.com/photo-1541849546-216549ae216d?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80',
        'roma_generic':
            'https://images.unsplash.com/photo-1515542622106-78bda8ba0e5b?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80',
        'milan_generic':
            'https://images.unsplash.com/photo-1513581166391-887a96ddeafd?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80',
      };

  /// Obtiene todas las imágenes de las guías populares organizadas por ciudad
  static Map<String, Map<String, String>> get popularGuidesByCity => {
        'berlin': berlinImages,
        'budapest': budapestImages,
        'roma': romaImages,
        'milan': milanImages,
      };

  /// Imágenes específicas de Berlín - URLs verificadas
  static Map<String, String> get berlinImages => {
        'puerta de brandenburgo':
            'https://images.unsplash.com/photo-1638873443476-8e3f1e789d6c?q=80&w=735&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
        'reichstag':
            'https://images.unsplash.com/photo-1749976638266-8c0225faf3cb?q=80&w=1170&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
        'unter den linden':
            'https://images.unsplash.com/photo-1675935227009-dac2f276cfbd?w=500&auto=format&fit=crop&q=60&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxzZWFyY2h8MTN8fEJlcmxpbiUyMFVudGVyJTIwZGVuJTIwTGluZGVufGVufDB8fDB8fHwy',
        'muro de berlín':
            'https://images.unsplash.com/photo-1675935227009-dac2f276cfbd?w=500&auto=format&fit=crop&q=60&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxzZWFyY2h8MTN8fEJlcmxpbiUyMFVudGVyJTIwZGVuJTIwTGluZGVufGVufDB8fDB8fHwy',
        'checkpoint charlie':
            'https://images.unsplash.com/photo-1559116284-9c57b7a01f7a?q=80&w=1170&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
        'isla de los museos':
            'https://images.unsplash.com/photo-1649717233552-54a6564d442b?q=80&w=735&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
        'torre de tv de berlín':
            'https://images.unsplash.com/photo-1560930950-5cc20e80e392?q=80&w=1170&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
        'alexanderplatz':
            'https://images.unsplash.com/photo-1684059732179-7710fbb2688b?q=80&w=1170&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
        'barrio de prenzlauer berg':
            'https://images.unsplash.com/photo-1719451795806-0d45af6de439?q=80&w=1074&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHhwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
      };

  /// Imágenes específicas de Budapest - URLs verificadas
  static Map<String, String> get budapestImages => {
        'parlamento húngaro':
            'https://images.unsplash.com/photo-1622115469132-124ec9f88fca?q=80&w=1073&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
        'basílica de san esteban':
            'https://images.unsplash.com/photo-1622616350599-39a5a32cef40?q=80&w=1170&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
        'mercado central':
            'https://images.unsplash.com/photo-1736056338252-ea0dca186862?q=80&w=1170&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
        'castillo de buda':
            'https://images.unsplash.com/photo-1711545577698-47234a605fd6?q=80&w=914&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
        'bastión de los pescadores':
            'https://images.unsplash.com/photo-1634313858445-e0880d75f49d?q=80&w=1170&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
        'iglesia de matías':
            'https://images.unsplash.com/photo-1610961595311-0d596322c01c?q=80&w=1170&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
        'balneario széchenyi':
            'https://images.unsplash.com/photo-1733485358262-80c717a9fb2a?q=80&w=1175&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
        'avenida váci':
            'https://images.unsplash.com/photo-1697799313360-fe4830ad533c?q=80&w=1171&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
        'crucero por el danubio':
            'https://images.unsplash.com/photo-1663857040527-13f00d0a2d5d?q=80&w=1170&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
        'ruin bars':
            'https://images.unsplash.com/photo-1664312848897-75c0d20f23fa?q=80&w=1170&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
      };

  /// Imágenes específicas de Roma - URLs verificadas
  static Map<String, String> get romaImages => {
        'coliseo romano':
            'https://images.unsplash.com/photo-1627673989543-af63ca11a0a0?q=80&w=1170&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
        'foro romano':
            'https://images.unsplash.com/photo-1634535441358-4b8fa9a2d0cb?q=80&w=1074&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
        'monte palatino':
            'https://images.unsplash.com/photo-1661960106336-1996b21d02e0?q=80&w=1032&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
        'ciudad del vaticano':
            'https://images.unsplash.com/photo-1546946590-5d739771abc4?q=80&w=1176&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
        'basílica de san pedro':
            'https://images.unsplash.com/photo-1672950972884-7cf700885593?q=80&w=1170&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
        'castel sant\'angelo':
            'https://images.unsplash.com/photo-1565537616283-221109348b0d?q=80&w=1110&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
        'fontana de trevi':
            'https://images.unsplash.com/photo-1720224048012-812d18a7960d?q=80&w=1074&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
        'plaza de españa':
            'https://images.unsplash.com/photo-1654606543461-414aa90ff838?q=80&w=1195&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
        'panteón':
            'https://images.unsplash.com/photo-1684275507407-28032196faeb?q=80&w=1170&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
        'villa borghese':
            'https://images.unsplash.com/photo-1710107365687-fa90a6f2eb35?q=80&w=1074&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
        'trastevere':
            'https://images.unsplash.com/photo-1708628934823-a37e3fe0bb4e?q=80&w=1170&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
        'campo de\' fiori':
            'https://images.unsplash.com/photo-1616362434905-02ee87df771d?q=80&w=1170&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
        'termas de caracalla':
            'https://images.unsplash.com/photo-1559220758-8e0a0b24a707?q=80&w=1032&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
        'plaza navona':
            'https://images.unsplash.com/photo-1662398885856-cf2ab6e981b2?q=80&w=1174&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
        'aventino y ojo de la cerradura':
            'https://images.unsplash.com/photo-1721481954096-ad9be199f87d?q=80&w=1173&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
      };

  /// Imágenes específicas de Milán - URLs verificadas
  static Map<String, String> get milanImages => {
        'duomo de milán':
            'https://images.unsplash.com/photo-1610016302534-6f67f1c968d8?q=80&w=1075&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
        'galleria vittorio emanuele ii':
            'https://images.unsplash.com/photo-1716793165604-6466a820ecfa?q=80&w=1170&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
        'teatro la scala':
            'https://images.unsplash.com/photo-1635886630467-a1b8e34a10c1?q=80&w=1077&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
        'castillo sforzesco':
            'https://images.unsplash.com/photo-1602059201105-276c01c1b657?q=80&w=1170&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
        'parque sempione':
            'https://images.unsplash.com/photo-1651995859199-2b0695c07ce3?q=80&w=1170&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
        'barrio de brera':
            'https://images.unsplash.com/photo-1699107968492-36846521377a?q=80&w=1170&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
        'quadrilatero della moda':
            'https://images.unsplash.com/photo-1720540545257-dc21cebf5b4e?q=80&w=1170&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
        'navigli':
            'https://images.unsplash.com/photo-1694453722395-f4c9400a35d5?q=80&w=1079&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
      };

  /// Obtiene la imagen de una actividad específica por ID de actividad
  static String getImageByActivityId(String activityId) {
    // Mapeo específico por ID de actividad de las guías populares
    final activityImages = {
      // IDs de Berlín
      'berlin_1_1':
          'https://images.unsplash.com/photo-1587330979470-3595b84de63e?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80',
      'berlin_1_2':
          'https://images.unsplash.com/photo-1590736969955-71cc94901144?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80',
      'berlin_1_3':
          'https://images.unsplash.com/photo-1571019613454-1cb2f99b2d8b?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80',
      'berlin_2_1':
          'https://images.unsplash.com/photo-1566911753692-9cef1de4d5b4?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80',
      'berlin_2_2':
          'https://images.unsplash.com/photo-1562832135-14a35d25edef?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80',
      'berlin_2_3':
          'https://images.unsplash.com/photo-1529260830199-42c24126f198?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80',
      'berlin_3_1':
          'https://images.unsplash.com/photo-1566639473150-a6d2c9b87b1d?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80',
      'berlin_3_2':
          'https://images.unsplash.com/photo-1571019613454-1cb2f99b2d8b?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80',
      'berlin_3_3':
          'https://images.unsplash.com/photo-1527838832700-5059252407fa?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80',

      // IDs de Budapest
      'budapest_1_1':
          'https://images.unsplash.com/photo-1541849546-216549ae216d?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80',
      'budapest_1_2':
          'https://images.unsplash.com/photo-1578915503866-63ce536c5e73?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80',
      'budapest_1_3':
          'https://images.unsplash.com/photo-1620416692900-e2c7c2d5cd5e?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80',
      'budapest_2_1':
          'https://images.unsplash.com/photo-1569870512308-5c8e4dd65a60?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80',
      'budapest_2_2':
          'https://images.unsplash.com/photo-1578915503866-63ce536c5e73?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80',
      'budapest_2_3':
          'https://images.unsplash.com/photo-1541880310-ca3ed1cc8e69?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80',
      'budapest_3_1':
          'https://images.unsplash.com/photo-1570215171932-6dcc7296a6fd?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80',
      'budapest_3_2':
          'https://images.unsplash.com/photo-1578915503866-63ce536c5e73?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80',
      'budapest_4_1':
          'https://images.unsplash.com/photo-1541849546-216549ae216d?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80',
      'budapest_4_2':
          'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80',

      // IDs de Roma
      'rome_1_1':
          'https://images.unsplash.com/photo-1515542622106-78bda8ba0e5b?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80',
      'rome_1_2':
          'https://images.unsplash.com/photo-1515542622106-78bda8ba0e5b?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80',
      'rome_1_3':
          'https://images.unsplash.com/photo-1529260830199-42c24126f198?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80',
      'rome_2_1':
          'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80',
      'rome_2_2':
          'https://images.unsplash.com/photo-1515542622106-78bda8ba0e5b?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80',
      'rome_2_3':
          'https://images.unsplash.com/photo-1552832230-c0197dd311b5?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80',
      'rome_3_1':
          'https://images.unsplash.com/photo-1525874684015-58379d421a52?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80',
      'rome_3_2':
          'https://images.unsplash.com/photo-1531572753322-ad063cecc140?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80',
      'rome_3_3':
          'https://images.unsplash.com/photo-1539593395743-7da5ee10ff07?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80',

      // IDs de Milán
      'milan_1_1':
          'https://images.unsplash.com/photo-1513581166391-887a96ddeafd?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80',
      'milan_1_2':
          'https://images.unsplash.com/photo-1549569794-8c7af3e5c945?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80',
      'milan_1_3':
          'https://images.unsplash.com/photo-1597149456632-62d37c92ce81?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80',
      'milan_2_1':
          'https://images.unsplash.com/photo-1529260830199-42c24126f198?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80',
      'milan_2_2':
          'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80',
      'milan_2_3':
          'https://images.unsplash.com/photo-1441986300917-64674bd600d8?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80',
      'milan_3_1':
          'https://images.unsplash.com/photo-1441986300917-64674bd600d8?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80',
      'milan_3_2':
          'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80',
    };

    return activityImages[activityId] ?? getCityImage('unknown');
  }

  /// Obtiene todas las URLs únicas de las guías populares
  static List<String> get allPopularGuidesUrls {
    final allUrls = <String>{};
    allUrls.addAll(popularGuidesImages.values);
    allUrls.addAll(citySpecificImages.values);
    return allUrls.toList();
  }

  /// Método de utilidad para obtener una imagen aleatoria de alta calidad
  static String getRandomHighQualityImage() {
    final urls = allPopularGuidesUrls;
    final randomIndex = (DateTime.now().millisecondsSinceEpoch % urls.length);
    return urls[randomIndex];
  }

  /// Valida si una URL de imagen está en nuestro catálogo de imágenes verificadas
  static bool isVerifiedImageUrl(String url) {
    return allPopularGuidesUrls.contains(url);
  }

  /// Método para buscar imagen por palabras clave
  static String? findImageByKeywords(List<String> keywords,
      {String? fallbackCity}) {
    for (final keyword in keywords) {
      // Buscar en el mapeo principal
      for (final entry in popularGuidesImages.entries) {
        if (entry.key.toLowerCase().contains(keyword.toLowerCase())) {
          return entry.value;
        }
      }
    }

    // Si no se encuentra, usar imagen de ciudad como fallback
    if (fallbackCity != null) {
      return getCityImage(fallbackCity);
    }

    return null;
  }

  /// Método de prueba para verificar URLs de imágenes
  static Map<String, String> getTestImages() {
    return {
      'picsum_test': 'https://picsum.photos/800/600?random=1',
      'pexels_berlin': _pexelsImages['berlin']!,
      'pexels_budapest': _pexelsImages['budapest']!,
      'pexels_roma': _pexelsImages['roma']!,
      'unsplash_simple':
          'https://images.unsplash.com/photo-1566911753692-9cef1de4d5b4?w=400&h=300',
      'fallback_berlin': _fallbackImages['berlin']!,
    };
  }

  /// Método alternativo simplificado que SIEMPRE funciona
  static String getWorkingImage([String? city]) {
    // Usa Picsum que siempre funciona
    if (city != null) {
      final cityKey =
          city.toLowerCase().replaceAll('á', 'a').replaceAll('í', 'i');
      return _fallbackImages[cityKey] ?? _fallbackImages['default']!;
    }
    return 'https://picsum.photos/800/600?random=${DateTime.now().millisecondsSinceEpoch % 100}';
  }
}
