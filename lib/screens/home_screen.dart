import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:tourify_flutter/widgets/home/create_guide_button.dart';
import 'package:tourify_flutter/widgets/home/popular_guides_section.dart';
import 'package:tourify_flutter/widgets/home/search_section.dart';
import 'package:tourify_flutter/services/public_guides_service.dart';
import 'package:tourify_flutter/services/navigation_service.dart';
import '../widgets/home/create_guide_modal.dart';
import '../widgets/common/custom_bottom_navigation_bar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, dynamic>> _popularGuides = [];
  List<Map<String, dynamic>> _searchResults = [];
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  bool _isLoadingPopularGuides = true;

  @override
  void initState() {
    super.initState();
    _searchResults = [];
    _loadPopularGuides();
  }

  Future<void> _loadPopularGuides() async {
    setState(() {
      _isLoadingPopularGuides = true;
    });

    try {
      final guides =
          await PublicGuidesService.getTopRatedPublicGuides(limit: 4);
      setState(() {
        _popularGuides = guides;
        _isLoadingPopularGuides = false;
      });
    } catch (e) {
      print('Error loading popular guides: $e');
      setState(() {
        _isLoadingPopularGuides = false;
      });
    }
  }

  void _filterGuides(String query) async {
    if (query.isEmpty) {
      setState(() {
        _isSearching = false;
        _searchResults = [];
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      final results = await PublicGuidesService.searchPublicGuides(query);
      setState(() {
        _searchResults = results;
      });
    } catch (e) {
      print('Error al buscar guías: $e');
      setState(() {
        _searchResults = [];
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Stack(
        children: [
          // Fondo degradado azul hasta arriba
          Container(
            width: double.infinity,
            height: 160, // más margen visual arriba y abajo
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF60A5FA), Color(0xFF2563EB)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(32),
                bottomRight: Radius.circular(32),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cabecera con mensaje de bienvenida (sin fondo)
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        '👋 ¡Bienvenido a Tourify!',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Crea y comparte guías de viaje únicas',
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
                // Separador decorativo tipo wave
                Container(
                  width: double.infinity,
                  height: 28,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(32),
                      topRight: Radius.circular(32),
                    ),
                  ),
                  child: CustomPaint(
                    painter: _WavePainter(),
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SearchSection(
                    searchController: _searchController,
                    onSearch: _filterGuides,
                    searchResults: _searchResults,
                    isSearching: _isSearching,
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: PopularGuidesSection(
                      guides: _popularGuides,
                      isLoading: _isLoadingPopularGuides,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: CreateGuideButton(
                    onTap: _showCreateGuideModal,
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: CustomBottomNavigationBar(
        currentIndex: 0,
        onTap: (index) {
          switch (index) {
            case 0:
              // Already on home, do nothing
              break;
            case 1:
              NavigationService.navigateToMainScreen('/my-guides');
              break;
            case 2:
              NavigationService.navigateToMainScreen('/profile');
              break;
          }
        },
      ),
    );
  }
}

// Separador decorativo tipo wave
class _WavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFF5F5F5)
      ..style = PaintingStyle.fill;
    final path = Path();
    path.moveTo(0, 0);
    path.quadraticBezierTo(size.width * 0.25, 18, size.width * 0.5, 12);
    path.quadraticBezierTo(size.width * 0.75, 6, size.width, 18);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
