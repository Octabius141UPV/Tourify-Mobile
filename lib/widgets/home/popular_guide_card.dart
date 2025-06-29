import 'package:flutter/material.dart';

class PopularGuideCard extends StatelessWidget {
  final String title;
  final String duration;
  final int activities;
  final String? imageUrl;
  final String? city;
  final VoidCallback? onTap;
  final VoidCallback? onCopyTap;
  final bool isPredefined;

  const PopularGuideCard({
    super.key,
    required this.title,
    required this.duration,
    required this.activities,
    this.imageUrl,
    this.city,
    this.onTap,
    this.onCopyTap,
    this.isPredefined = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header con imagen
          InkWell(
            onTap: onTap,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Container(
              height: 70,
              decoration: BoxDecoration(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
                color: Colors.grey[200],
              ),
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
                child: _buildHeaderContent(),
              ),
            ),
          ),

          // Contenido del card
          Expanded(
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title.isNotEmpty ? title : 'Sin título',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F2937),
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.calendar_today,
                                size: 12, color: Colors.blue[400]),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                duration.isNotEmpty
                                    ? duration
                                    : 'Duración no especificada',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF2563EB),
                                  height: 1.1,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(Icons.attractions,
                                size: 12, color: Colors.green[400]),
                            const SizedBox(width: 4),
                            Text(
                              '$activities actividades',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF059669),
                                height: 1.1,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Botón "Usar esta guía" si es una guía predefinida
          if (isPredefined) ...[
            const Divider(height: 1, color: Color(0xFFE5E7EB)),
            InkWell(
              onTap: onCopyTap,
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(16)),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.copy,
                      size: 16,
                      color: Colors.blue[600],
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Usar esta guía',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeaderContent() {
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            imageUrl!,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return _buildFallbackHeader();
            },
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return _buildFallbackHeader();
            },
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black.withOpacity(0.3),
                  Colors.transparent,
                ],
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
              ),
            ),
          ),
        ],
      );
    }

    return _buildFallbackHeader();
  }

  Widget _buildFallbackHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF60A5FA), Color(0xFF2563EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 3,
              ),
            ],
          ),
          child: Icon(
            Icons.location_city,
            size: 12,
            color: Colors.blue[400],
          ),
        ),
      ),
    );
  }
}
