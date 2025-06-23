import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:tourify_flutter/widgets/home/create_guide_button.dart';
import 'package:tourify_flutter/widgets/home/popular_guides_section.dart';
import 'package:tourify_flutter/widgets/home/public_guides_section.dart';
import 'package:tourify_flutter/widgets/home/search_section.dart';
import 'package:tourify_flutter/services/guide_service.dart';
import 'package:tourify_flutter/services/navigation_service.dart';
import '../widgets/home/create_guide_modal.dart';
import '../widgets/common/custom_bottom_navigation_bar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  List<Map<String, dynamic>> _popularGuides = [];
  List<Map<String, dynamic>> _publicGuides = [];
  List<Map<String, dynamic>> _searchResults = [];
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  bool _isLoadingPopularGuides = true;
  bool _isLoadingPublicGuides = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _searchResults = [];
    _loadPopularGuides();
    _loadPublicGuides();
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
      print('Error loading popular guides: $e');
      setState(() {
        _isLoadingPopularGuides = false;
      });
    }
  }

  Future<void> _loadPublicGuides() async {
    setState(() {
      _isLoadingPublicGuides = true;
    });

    try {
      final guides = await GuideService.getCommunityPublicGuides(limit: 20);
      setState(() {
        _publicGuides = guides;
        _isLoadingPublicGuides = false;
      });
    } catch (e) {
      print('Error loading public guides: $e');
      setState(() {
        _isLoadingPublicGuides = false;
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
      final results = await GuideService.searchPublicGuides(query);
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

  Future<void> _refreshData() async {
    await Future.wait([
      _loadPopularGuides(),
      _loadPublicGuides(),
    ]);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
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
                      // Sección de guías populares (predefinidas)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: PopularGuidesSection(
                          guides: _popularGuides,
                          isLoading: _isLoadingPopularGuides,
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Sección de guías públicas (comunidad)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: PublicGuidesSection(
                          guides: _publicGuides,
                          isLoading: _isLoadingPublicGuides,
                        ),
                      ),
                      const SizedBox(height: 100), // Espacio para el navbar
                    ],
                  ),
                ),
              ),
            ),
            // Sección de búsqueda al final, por encima del navbar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SearchSection(
                searchController: _searchController,
                onSearch: _filterGuides,
                searchResults: _searchResults,
                isSearching: _isSearching,
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
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
