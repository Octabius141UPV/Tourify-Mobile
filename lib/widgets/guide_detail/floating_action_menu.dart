import 'package:flutter/material.dart';

class FloatingActionMenu extends StatelessWidget {
  final bool isMenuExpanded;
  final VoidCallback onToggleMenu;
  final VoidCallback onAddActivity;
  final VoidCallback onOrganizeActivities;
  final VoidCallback onOpenAgent;
  final VoidCallback? onOpenTickets; // nuevo botón tickets

  const FloatingActionMenu({
    super.key,
    required this.isMenuExpanded,
    required this.onToggleMenu,
    required this.onAddActivity,
    required this.onOrganizeActivities,
    required this.onOpenAgent,
    this.onOpenTickets,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedOpacity(
          opacity: !isMenuExpanded ? 0.0 : 1.0,
          duration: const Duration(milliseconds: 300),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: !isMenuExpanded ? 0 : null,
            child: isMenuExpanded
                ? Column(
                    children: [
                      AnimatedSlide(
                        offset: isMenuExpanded ? Offset(0, 0) : Offset(0, 0.9),
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeOutBack,
                        child: AnimatedScale(
                          scale: isMenuExpanded ? 1.0 : 0.7,
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.easeOutBack,
                          child: AnimatedOpacity(
                            opacity: isMenuExpanded ? 1.0 : 0.0,
                            duration: const Duration(milliseconds: 600),
                            child: Tooltip(
                              message: 'Agente de viaje',
                              child: _buildCircularButton(
                                onTap: onOpenAgent,
                                size: 46,
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFF42A5F5),
                                    Color(0xFF1565C0),
                                  ],
                                ),
                                shadowColor: Colors.blue,
                                customChild: ClipOval(
                                  child: Image.asset(
                                    'assets/images/agent_avatar.png',
                                    width: 32,
                                    height: 32,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      AnimatedSlide(
                        offset: isMenuExpanded ? Offset(0, 0) : Offset(0, 0.6),
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeOutBack,
                        child: AnimatedScale(
                          scale: isMenuExpanded ? 1.0 : 0.7,
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.easeOutBack,
                          child: AnimatedOpacity(
                            opacity: isMenuExpanded ? 1.0 : 0.0,
                            duration: const Duration(milliseconds: 600),
                            child: Tooltip(
                              message: 'Organizar actividades',
                              child: _buildCircularButton(
                                onTap: onOrganizeActivities,
                                size: 46,
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFF42A5F5),
                                    Color(0xFF1565C0),
                                  ],
                                ),
                                shadowColor: Colors.blue,
                                icon: Icons.swap_vert_rounded,
                                iconSize: 24,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (onOpenTickets != null)
                        AnimatedSlide(
                          offset:
                              isMenuExpanded ? Offset(0, 0) : Offset(0, 0.45),
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.easeOutBack,
                          child: AnimatedScale(
                            scale: isMenuExpanded ? 1.0 : 0.7,
                            duration: const Duration(milliseconds: 600),
                            curve: Curves.easeOutBack,
                            child: AnimatedOpacity(
                              opacity: isMenuExpanded ? 1.0 : 0.0,
                              duration: const Duration(milliseconds: 600),
                              child: Tooltip(
                                message: 'Tickets y reservas',
                                child: _buildCircularButton(
                                  onTap: onOpenTickets!,
                                  size: 46,
                                  gradient: const LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Color(0xFF42A5F5),
                                      Color(0xFF1565C0),
                                    ],
                                  ),
                                  shadowColor: Colors.blue,
                                  icon: Icons.confirmation_num_outlined,
                                  iconSize: 22,
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (onOpenTickets != null) const SizedBox(height: 12),
                      AnimatedSlide(
                        offset: isMenuExpanded ? Offset(0, 0) : Offset(0, 0.3),
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeOutBack,
                        child: AnimatedScale(
                          scale: isMenuExpanded ? 1.0 : 0.7,
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.easeOutBack,
                          child: AnimatedOpacity(
                            opacity: isMenuExpanded ? 1.0 : 0.0,
                            duration: const Duration(milliseconds: 600),
                            child: Tooltip(
                              message: 'Añadir actividad',
                              child: _buildCircularButton(
                                onTap: onAddActivity,
                                size: 46,
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFF42A5F5),
                                    Color(0xFF1565C0),
                                  ],
                                ),
                                shadowColor: Colors.blue,
                                icon: Icons.add,
                                iconSize: 24,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ),
        Tooltip(
          message: isMenuExpanded ? 'Cerrar menú' : 'Abrir menú',
          child: _buildCircularButton(
            onTap: onToggleMenu,
            size: 54,
            gradient: isMenuExpanded
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFE53935),
                      Color(0xFFB71C1C),
                    ],
                  )
                : const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF2196F3),
                      Color(0xFF0D47A1),
                    ],
                  ),
            shadowColor: isMenuExpanded ? Colors.red : Colors.blue,
            icon: isMenuExpanded ? Icons.close : Icons.more_vert,
            iconSize: 28,
          ),
        ),
      ],
    );
  }

  Widget _buildCircularButton({
    required VoidCallback onTap,
    required double size,
    required LinearGradient gradient,
    required Color shadowColor,
    IconData? icon,
    double? iconSize,
    Widget? customChild,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: gradient,
        boxShadow: [
          BoxShadow(
            color: shadowColor.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: shadowColor.withOpacity(0.1),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(size / 2),
          onTap: onTap,
          splashColor: Colors.white.withOpacity(0.3),
          highlightColor: Colors.white.withOpacity(0.1),
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: customChild ??
                  (icon != null
                      ? Icon(
                          icon,
                          color: Colors.white,
                          size: iconSize,
                          key: ValueKey(icon),
                        )
                      : const SizedBox()),
            ),
          ),
        ),
      ),
    );
  }
}
