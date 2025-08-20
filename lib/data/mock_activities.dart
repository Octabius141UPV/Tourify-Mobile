class Activity {
  final String id;
  final String name;
  final String description;
  final String imageUrl;
  final double rating;
  final int reviews;
  final String category;
  final double price;
  final int duration; // en minutos
  final List<String> tags;
  final int? order; // orden sugerido dentro del día (opcional)
  final String? timeSlot; // morning | afternoon | evening | night (opcional)

  Activity({
    required this.id,
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.rating,
    required this.reviews,
    required this.category,
    required this.price,
    required this.duration,
    required this.tags,
    this.order,
    this.timeSlot,
  });
}

final List<Activity> mockActivities = [
  Activity(
    id: '1',
    name: 'Tour por el Museo del Louvre',
    description:
        'Descubre las obras maestras del arte mundial en el museo más famoso de París.',
    imageUrl: 'https://images.unsplash.com/photo-1542051841857-5f90071e7989',
    rating: 4.8,
    reviews: 1245,
    category: 'Cultura',
    price: 25.0,
    duration: 180,
    tags: ['Museo', 'Arte', 'Historia'],
  ),
  Activity(
    id: '2',
    name: 'Paseo en barco por el Sena',
    description:
        'Disfruta de las vistas más impresionantes de París desde el río Sena.',
    imageUrl: 'https://images.unsplash.com/photo-1502602898657-3e91760cbb34',
    rating: 4.6,
    reviews: 892,
    category: 'Naturaleza',
    price: 15.0,
    duration: 60,
    tags: ['Barco', 'Río', 'Vistas'],
  ),
  Activity(
    id: '3',
    name: 'Clase de cocina francesa',
    description:
        'Aprende a preparar los platos más emblemáticos de la gastronomía francesa.',
    imageUrl: 'https://images.unsplash.com/photo-1556910103-1c02745aae4d',
    rating: 4.9,
    reviews: 567,
    category: 'Gastronomía',
    price: 75.0,
    duration: 240,
    tags: ['Cocina', 'Gastronomía', 'Taller'],
  ),
  Activity(
    id: '4',
    name: 'Tour por Montmartre',
    description:
        'Explora el barrio bohemio de París y sus lugares más emblemáticos.',
    imageUrl: 'https://images.unsplash.com/photo-1502602898657-3e91760cbb34',
    rating: 4.7,
    reviews: 1034,
    category: 'Cultura',
    price: 20.0,
    duration: 120,
    tags: ['Barrio', 'Historia', 'Arte'],
  ),
  Activity(
    id: '5',
    name: 'Visita a la Torre Eiffel',
    description:
        'Sube a la cima del símbolo más famoso de París y disfruta de las vistas panorámicas.',
    imageUrl: 'https://images.unsplash.com/photo-1542051841857-5f90071e7989',
    rating: 4.9,
    reviews: 2345,
    category: 'Monumentos',
    price: 30.0,
    duration: 90,
    tags: ['Monumento', 'Vistas', 'Fotografía'],
  ),
];
