import 'package:flutter/material.dart';

import '../../config/app_colors.dart';

class GuideCard extends StatelessWidget {
  final String title;
  final String author;
  final String duration;
  final int activities;
  final int views;
  final VoidCallback? onTap;

  const GuideCard({
    super.key,
    required this.title,
    required this.author,
    required this.duration,
    required this.activities,
    required this.views,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.35,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: 60,
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  gradient: AppColors.primaryGradient,
                ),
                child: Center(
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.location_city,
                      size: 28,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title.isNotEmpty ? title : 'Sin título',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1F2937),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.calendar_today,
                              size: 15, color: Colors.blue[400]),
                          const SizedBox(width: 4),
                          Text(
                            duration.isNotEmpty
                                ? duration
                                : 'Duración no especificada',
                            style: const TextStyle(
                                fontSize: 13, color: Color(0xFF2563EB)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.attractions,
                              size: 15, color: Colors.green[400]),
                          const SizedBox(width: 4),
                          Text(
                            '$activities actividades',
                            style: const TextStyle(
                                fontSize: 13, color: Color(0xFF059669)),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 11,
                            backgroundColor: Colors.blue[100],
                            child: Text(
                              (author.isNotEmpty
                                  ? author[0].toUpperCase()
                                  : 'A'),
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF2563EB),
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              author.isNotEmpty
                                  ? 'Por $author'
                                  : 'Autor desconocido',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[700],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            Icons.visibility,
                            size: 13,
                            color: Colors.grey[500],
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '$views',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
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
