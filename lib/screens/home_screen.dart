import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tourify_flutter/widgets/home/create_guide_button.dart';
import 'package:tourify_flutter/widgets/home/popular_guides_section.dart';
import 'package:tourify_flutter/services/guide_service.dart';
import 'package:tourify_flutter/services/navigation_service.dart';
import 'package:tourify_flutter/screens/guide_detail_screen.dart';
import '../widgets/home/create_guide_modal.dart';
import '../widgets/common/custom_bottom_navigation_bar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  List<Map<String, dynamic>> _popularGuides = [];
  List<Map<String, dynamic>> _recentGuides = [];
  bool _isLoadingPopularGuides = true;
  bool _isLoadingRecentGuides = true;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadPopularGuides();
    _loadRecentGuides();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // Recargar guías cuando la app vuelve al primer plano
      _refreshData();
    }
  }

  Future<void> _loadPopularGuides() async {
    setState(() {
      _isLoadingPopularGuides = true;
    });

    try {
      final guides = await GuideService.getTopPublicGuides(limit: 4);
      setState(() {
        _popularGuides = guides;
        _isLoadingPopularGuides = false;
      });
    } catch (e) {
      print('Error loading curated guides: $e');
      setState(() {
        _popularGuides = [];
        _isLoadingPopularGuides = false;
      });
    }
  }

  Future<void> _loadRecentGuides() async {
    setState(() {
      _isLoadingRecentGuides = true;
    });

    try {
      final user = _auth.currentUser;
      if (user == null) {
        setState(() {
          _recentGuides = [];
          _isLoadingRecentGuides = false;
        });
        return;
      }

      final userRef = _firestore.collection('users').doc(user.uid);
      final guidesQuery = await _firestore
          .collection('guides')
          .where('userRef', isEqualTo: userRef)
          .orderBy('createdAt', descending: true)
          .limit(4)
          .get();

      final recentGuides = guidesQuery.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'title': data['title'] ?? data['name'] ?? 'Sin título',
          'city': data['city'] ?? data['name'] ?? 'Sin título',
          'location': data['formattedAddress'] ??
              data['destination'] ??
              'Sin ubicación',
          'createdAt': data['createdAt'] ?? DateTime.now(),
          'totalDays': data['totalDays'] ?? 0,
          'startDate': data['startDate'],
          'endDate': data['endDate'],
        };
      }).toList();

      setState(() {
        _recentGuides = recentGuides;
        _isLoadingRecentGuides = false;
      });
    } catch (e) {
      print('Error loading recent guides: $e');
      setState(() {
        _recentGuides = [];
        _isLoadingRecentGuides = false;
      });
    }
  }

  void _showCreateGuideModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const CreateGuideModal(),
    );
  }

  Future<void> _refreshData() async {
    await Future.wait([
      _loadPopularGuides(),
      _loadRecentGuides(),
    ]);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 32),
            // Botón "Me voy de viaje" al principio
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: CreateGuideButton(
                onTap: _showCreateGuideModal,
              ),
            ),
            const SizedBox(height: 16),
            // Divisor
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Divider(
                color: Colors.grey.withOpacity(0.3),
                thickness: 1,
                height: 32,
              ),
            ),
            // Contenido scrolleable
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refreshData,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Sección de mis últimas guías
                      if (_auth.currentUser != null) ...[
                        _buildRecentGuidesSection(),
                        const SizedBox(height: 32),
                      ],

                      // Sección de guías populares (predefinidas)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: PopularGuidesSection(
                          guides: _popularGuides,
                          isLoading: _isLoadingPopularGuides,
                        ),
                      ),
                      const SizedBox(height: 100), // Espacio para el navbar
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: CustomBottomNavigationBar(
        currentIndex: 0,
        onTap: (index) {
          final user = FirebaseAuth.instance.currentUser;
          switch (index) {
            case 0:
              // Ya estás en Home
              break;
            case 1:
              if (user == null) {
                _showLoginRequiredDialog();
              } else {
                NavigationService.navigateToMainScreen('/my-guides');
              }
              break;
            case 2:
              if (user == null) {
                _showLoginRequiredDialog();
              } else {
                NavigationService.navigateToMainScreen('/profile');
              }
              break;
          }
        },
      ),
    );
  }

  Widget _buildRecentGuidesSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Mis Últimas Guías',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              if (_recentGuides.isNotEmpty)
                TextButton(
                  onPressed: () {
                    NavigationService.navigateToMainScreen('/my-guides');
                  },
                  child: Text(
                    'Ver todas',
                    style: TextStyle(
                      color: const Color(0xFF2563EB),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (_isLoadingRecentGuides)
            Container(
              height: 120,
              child: Center(
                child: CircularProgressIndicator(
                  color: const Color(0xFF2563EB),
                ),
              ),
            )
          else if (_recentGuides.isEmpty)
            Container(
              height: 120,
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.explore_outlined,
                      size: 32,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Aún no tienes guías',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '¡Crea tu primera aventura!',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SizedBox(
              height: 140,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _recentGuides.length,
                itemBuilder: (context, index) {
                  final guide = _recentGuides[index];
                  return _buildRecentGuideCard(guide);
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRecentGuideCard(Map<String, dynamic> guide) {
    final String title = guide['title'] ?? 'Sin título';
    final String location = guide['location'] ?? 'Sin ubicación';
    final int totalDays = guide['totalDays'] ?? 0;

    return Container(
      width: 280,
      margin: const EdgeInsets.only(right: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => GuideDetailScreen(
                  guideId: guide['id'],
                  guideTitle: title,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF60A5FA).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.map_rounded,
                        color: const Color(0xFF2563EB),
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
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1F2937),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(
                                Icons.location_on_rounded,
                                size: 14,
                                color: Colors.grey[500],
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  location,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[600],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (totalDays > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.calendar_today_rounded,
                              size: 12,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$totalDays día${totalDays > 1 ? 's' : ''}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                      color: const Color(0xFF2563EB),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showLoginRequiredDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Inicia sesión o regístrate'),
        content: Text(
            'Debes iniciar sesión o registrarte para acceder a esta función.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              NavigationService.navigateToMainScreen(
                  '/login'); // Ajusta la ruta si es diferente
            },
            child: Text('Iniciar sesión'),
          ),
        ],
      ),
    );
  }
}
