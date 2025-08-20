import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:tourify_flutter/services/collaborators_service.dart';
import 'package:flutter/services.dart';
import 'package:tourify_flutter/utils/email_validator.dart';
import 'package:tourify_flutter/utils/dialog_utils.dart';

class CollaboratorsModal extends StatefulWidget {
  final String guideId;
  final String guideTitle;

  const CollaboratorsModal({
    super.key,
    required this.guideId,
    required this.guideTitle,
  });

  @override
  State<CollaboratorsModal> createState() => _CollaboratorsModalState();
}

class _CollaboratorsModalState extends State<CollaboratorsModal>
    with SingleTickerProviderStateMixin {
  final CollaboratorsService _collaboratorsService = CollaboratorsService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _emailController = TextEditingController();

  List<Map<String, dynamic>> _collaborators = [];
  List<Map<String, dynamic>> _accessLinks = [];
  String? _userRole;
  bool _isLoading = true;
  bool _isAddingCollaborator = false;
  bool _isGeneratingLink = false;
  String? _error;
  String _selectedRole = 'viewer';
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadCollaborators();
    _loadAccessLinks();

    // Forzar actualización del rol cada vez que se abre el modal
    _refreshUserRole();
  }

  Future<void> _refreshUserRole() async {
    try {
      final userRoleResponse =
          await _collaboratorsService.getUserRole(widget.guideId);
      setState(() {
        _userRole = userRoleResponse['role'] as String?;
      });
      print('Rol del usuario actualizado: $_userRole');
    } catch (e) {
      print('Error al actualizar rol del usuario: $e');
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAccessLinks() async {
    try {
      final links =
          await _collaboratorsService.getActiveAccessLinks(widget.guideId);
      setState(() {
        _accessLinks = links;
      });
    } catch (e) {
      // Error silencioso
    }
  }

  Future<void> _generateAccessLink() async {
    // Verificar permisos antes de generar
    if (!_canManageLinks()) {
      _showMessage(
          'No tienes permisos para generar links de acceso.\n\nSolo propietarios y organizadores pueden crear links.',
          isError: true);
      return;
    }

    setState(() {
      _isGeneratingLink = true;
      _error = null;
    });

    final result = await _handleFirestoreOperation<Map<String, dynamic>>(
      () async {
        print('=== GENERANDO LINK ===');
        print('Rol del usuario: $_userRole');
        print('Rol del link: $_selectedRole');
        print('¿Puede gestionar links? ${_canManageLinks()}');

        final result = await _collaboratorsService.generateAccessLink(
            widget.guideId, _selectedRole);
        await _loadAccessLinks();
        return result;
      },
      operationName: 'generar link de acceso',
    );

    if (result != null && mounted) {
      // Copiar el link al portapapeles
      final String? link = result['link'] as String?;
      if (link != null) {
        await Clipboard.setData(ClipboardData(text: link));
        _showMessage('¡Enlace copiado al portapapeles!');
      } else {
        _showMessage('Link de acceso generado correctamente');
      }
    }

    setState(() {
      _isGeneratingLink = false;
    });
  }

  Future<void> _removeAccessLink(String token) async {
    try {
      await _collaboratorsService.revokeAccessLink(widget.guideId, token);
      await _loadAccessLinks();
      if (mounted) {
        _showMessage('Link de acceso eliminado correctamente');
      }
    } catch (e) {
      if (mounted) {
        _showMessage('Error al eliminar link de acceso', isError: true);
      }
    }
  }

  Future<void> _loadCollaborators() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final collaboratorsResponse =
          await _collaboratorsService.getCollaborators(widget.guideId);

      final userRoleResponse =
          await _collaboratorsService.getUserRole(widget.guideId);

      final collaboratorsList = (collaboratorsResponse is Map &&
              collaboratorsResponse['collaborators'] is List)
          ? (collaboratorsResponse['collaborators'] as List)
              .whereType<Map<String, dynamic>>()
              .toList()
          : <Map<String, dynamic>>[];

      setState(() {
        _userRole = userRoleResponse['role'] as String?;
        _collaborators = collaboratorsList;
        _isLoading = false;
      });

      // Logging para depuración
      print('=== COLABORADORES MODAL DEBUG ===');
      print('Rol del usuario actual: $_userRole');
      print('¿Puede gestionar links? ${_canManageLinks()}');
      print('Número de colaboradores: ${_collaborators.length}');
      if (_userRole == 'editor') {
        print('✅ Usuario es ORGANIZADOR - debe poder gestionar links');
      } else if (_userRole == 'owner') {
        print('✅ Usuario es PROPIETARIO - debe poder gestionar links');
      } else {
        print('❌ Usuario es $_userRole - NO puede gestionar links');
      }
      print('=================================');
    } catch (e) {
      setState(() {
        _error = 'Error al cargar colaboradores: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _addCollaborator() async {
    final email = _emailController.text.trim();

    // Validar email usando el nuevo validador
    final validation = EmailValidator.validateEmail(email);
    if (!validation.isValid) {
      _showMessage(validation.error!, isError: true);
      return;
    }

    setState(() {
      _isAddingCollaborator = true;
      _error = null;
    });

    try {
      await _collaboratorsService.addCollaborator(
        guideId: widget.guideId,
        email: email,
        role: _selectedRole,
      );
      _emailController.clear();
      await _loadCollaborators();

      if (mounted) {
        _showMessage('Colaborador agregado exitosamente');
      }
    } catch (e) {
      if (mounted) {
        _showMessage('Error al agregar colaborador', isError: true);
      }
    } finally {
      setState(() {
        _isAddingCollaborator = false;
      });
    }
  }

  Future<void> _removeCollaborator(String email) async {
    try {
      await _collaboratorsService.removeCollaborator(widget.guideId, email);
      await _loadCollaborators();

      if (mounted) {
        _showMessage('Colaborador eliminado');
      }
    } catch (e) {
      if (mounted) {
        _showMessage('Error al eliminar colaborador', isError: true);
      }
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: isError ? Colors.red : Colors.green,
        content: Text(
          message,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          textAlign: TextAlign.center,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding:
            const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      ),
    );
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    });
  }

  bool _canManageCollaborators() {
    return _userRole == 'owner' || _userRole == 'editor';
  }

  bool _canManageLinks() {
    return _userRole == 'owner' || _userRole == 'editor';
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'owner':
        return CupertinoColors.systemOrange;
      case 'editor':
        return CupertinoColors.systemBlue;
      case 'viewer':
        return CupertinoColors.systemGreen;
      default:
        return CupertinoColors.systemGrey;
    }
  }

  IconData _getRoleIcon(String role) {
    switch (role) {
      case 'owner':
        return CupertinoIcons.star_fill;
      case 'editor':
        return CupertinoIcons.pencil;
      case 'viewer':
        return CupertinoIcons.eye;
      default:
        return CupertinoIcons.person;
    }
  }

  String _getRoleDisplayName(String role) {
    switch (role) {
      case 'owner':
        return 'Propietario';
      case 'editor':
        return 'Organizador';
      case 'viewer':
        return 'Acoplado';
      default:
        return 'Rol desconocido';
    }
  }

  // Helper para parsear Timestamps serializados desde backend
  Timestamp? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value;
    if (value is Map && value.containsKey('_seconds')) {
      return Timestamp(value['_seconds'], value['_nanoseconds'] ?? 0);
    }
    if (value is Map && value.containsKey('seconds')) {
      return Timestamp(value['seconds'], value['nanoseconds'] ?? 0);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final screenHeight = MediaQuery.of(context).size.height;
    final maxHeight = screenHeight * 0.9 - keyboardHeight;
    final minHeight = screenHeight * 0.3;

    return Material(
      color: Colors.transparent,
      child: SafeArea(
        child: Container(
          constraints: BoxConstraints(
            maxHeight: maxHeight,
            minHeight: minHeight,
          ),
          margin: EdgeInsets.zero,
          decoration: const BoxDecoration(
            color: CupertinoColors.systemBackground,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: CupertinoColors.systemBackground.resolveFrom(context),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                  border: Border(
                    bottom: BorderSide(
                      color: CupertinoColors.separator.resolveFrom(context),
                      width: 0.5,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text(
                        'Cancelar',
                        style: TextStyle(
                          color: CupertinoColors.systemBlue,
                          fontSize: 17,
                        ),
                      ),
                    ),
                    const Expanded(
                      child: Text(
                        'Colaboradores',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    SizedBox(width: 60), // Espacio para alinear el título
                  ],
                ),
              ),
              // Contenido
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Selección de rol
                      Text(
                        'Tipo de acceso',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: CupertinoColors.label.resolveFrom(context),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildRoleOption(
                        'viewer',
                        'Acoplado',
                        'Solo puede ver la guía',
                        CupertinoIcons.eye,
                        CupertinoColors.systemGreen,
                      ),
                      const SizedBox(height: 8),
                      _buildRoleOption(
                        'editor',
                        'Organizador',
                        'Puede editar la guía',
                        CupertinoIcons.pencil,
                        CupertinoColors.systemBlue,
                      ),
                      const SizedBox(height: 24),
                      // Sección de generar link (solo si puede gestionar links)
                      if (_canManageLinks()) _buildGenerateLinkSection(),
                      const SizedBox(height: 24),
                      // Sección de links activos eliminada
                      // _buildActiveLinks(),
                      // const SizedBox(height: 24),
                      // Sección de colaboradores actuales
                      _buildCurrentCollaborators(),
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

  Widget _buildRoleOption(String value, String title, String description,
      IconData icon, Color color) {
    final isSelected = _selectedRole == value;

    return GestureDetector(
      onTap: _isAddingCollaborator
          ? null
          : () => setState(() => _selectedRole = value),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withOpacity(0.1)
              : CupertinoColors.tertiarySystemBackground.resolveFrom(context),
          borderRadius: BorderRadius.circular(8),
          border: isSelected ? Border.all(color: color, width: 1.5) : null,
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(
                icon,
                color: color,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: isSelected
                          ? color
                          : CupertinoColors.label.resolveFrom(context),
                    ),
                  ),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 13,
                      color:
                          CupertinoColors.secondaryLabel.resolveFrom(context),
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                CupertinoIcons.checkmark_circle_fill,
                color: color,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenerateLinkSection() {
    return SizedBox(
      width: double.infinity,
      child: CupertinoButton(
        color: CupertinoColors.systemBlue,
        borderRadius: BorderRadius.circular(12),
        padding: const EdgeInsets.symmetric(vertical: 16),
        onPressed: _isGeneratingLink ? null : _generateAccessLink,
        child: _isGeneratingLink
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CupertinoActivityIndicator(color: Colors.white),
                  const SizedBox(width: 12),
                  const Text(
                    'Generando link...',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    CupertinoIcons.share,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Generar link de ${_getRoleDisplayName(_selectedRole).toLowerCase()}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildCurrentCollaborators() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              CupertinoIcons.person_2_fill,
              color: CupertinoColors.systemBlue.resolveFrom(context),
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'Colaboradores actuales',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: CupertinoColors.label.resolveFrom(context),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: CupertinoColors.systemBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_collaborators.length}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: CupertinoColors.systemBlue,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_isLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CupertinoActivityIndicator(),
            ),
          )
        else if (_collaborators.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: CupertinoColors.systemGrey6.resolveFrom(context),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Icon(
                  CupertinoIcons.person_add,
                  size: 40,
                  color: CupertinoColors.systemGrey.resolveFrom(context),
                ),
                const SizedBox(height: 8),
                Text(
                  'Aún no hay colaboradores',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: CupertinoColors.systemGrey.resolveFrom(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Invita a otros para colaborar en esta guía',
                  style: TextStyle(
                    fontSize: 14,
                    color: CupertinoColors.systemGrey2.resolveFrom(context),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: CupertinoColors.systemBackground.resolveFrom(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: CupertinoColors.separator.resolveFrom(context),
                width: 0.5,
              ),
            ),
            child: Column(
              children: _collaborators.asMap().entries.map((entry) {
                final index = entry.key;
                final collaborator = entry.value;
                final isLast = index == _collaborators.length - 1;

                return _buildCollaboratorItem(collaborator, isLast);
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildCollaboratorItem(
      Map<String, dynamic> collaborator, bool isLast) {
    final email = collaborator['email'] as String? ?? 'Email desconocido';
    final role = collaborator['role'] as String? ?? 'viewer';
    final displayName = collaborator['displayName'] as String?;
    final joinedAt = _parseTimestamp(collaborator['joinedAt']);

    final roleColor = _getRoleColor(role);
    final roleIcon = _getRoleIcon(role);
    final roleDisplayName = _getRoleDisplayName(role);
    final canRemove = _canManageCollaborators() && role != 'owner';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(
                bottom: BorderSide(
                  color: CupertinoColors.separator.resolveFrom(context),
                  width: 0.5,
                ),
              ),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: roleColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Icon(
              CupertinoIcons.person_fill,
              color: roleColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),

          // Información del colaborador
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (displayName != null && displayName.isNotEmpty) ...[
                  Text(
                    displayName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                ],
                Text(
                  email,
                  style: TextStyle(
                    fontSize: displayName != null ? 14 : 16,
                    color: displayName != null
                        ? CupertinoColors.secondaryLabel.resolveFrom(context)
                        : CupertinoColors.label.resolveFrom(context),
                    fontWeight: displayName != null
                        ? FontWeight.normal
                        : FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: roleColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            roleIcon,
                            size: 12,
                            color: roleColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            roleDisplayName,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: roleColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (joinedAt != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        'Desde ${_formatDate(joinedAt.toDate())}',
                        style: TextStyle(
                          fontSize: 12,
                          color: CupertinoColors.secondaryLabel
                              .resolveFrom(context),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Botón eliminar (solo para owners y editors, y no para el owner)
          if (canRemove)
            CupertinoButton(
              padding: EdgeInsets.zero,
              minSize: 32,
              onPressed: () => DialogUtils.showCupertinoConfirmation(
                context: context,
                title: 'Eliminar colaborador',
                content:
                    '¿Estás seguro de que quieres eliminar a $email de esta guía?',
                confirmLabel: 'Eliminar',
                confirmColor: Colors.red,
              ).then((confirmed) {
                if (confirmed == true) {
                  _removeCollaborator(email);
                }
              }),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: CupertinoColors.systemRed.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  CupertinoIcons.minus_circle_fill,
                  color: CupertinoColors.systemRed,
                  size: 18,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'hoy';
    } else if (difference.isNegative) {
      // Fecha futura
      final days = difference.inDays.abs();
      if (days == 1) {
        return 'en 1 día';
      } else if (days < 7) {
        return 'en $days días';
      } else if (days < 30) {
        final weeks = (days / 7).floor();
        return 'en $weeks semana${weeks > 1 ? 's' : ''}';
      } else {
        final months = (days / 30).floor();
        return 'en $months mes${months > 1 ? 'es' : ''}';
      }
    } else if (difference.inDays == 1) {
      return 'ayer';
    } else if (difference.inDays < 7) {
      return 'hace ${difference.inDays} días';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return 'hace $weeks semana${weeks > 1 ? 's' : ''}';
    } else {
      final months = (difference.inDays / 30).floor();
      return 'hace $months mes${months > 1 ? 'es' : ''}';
    }
  }

  void _showRemoveCollaboratorDialog(String email) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Eliminar colaborador'),
        content: Text(
            '¿Estás seguro de que quieres eliminar a $email de esta guía?'),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancelar'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.of(context).pop();
              _removeCollaborator(email);
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  // Wrapper para manejar errores de Firestore
  Future<T?> _handleFirestoreOperation<T>(
    Future<T> Function() operation, {
    String? loadingMessage,
    String? successMessage,
    String? operationName,
  }) async {
    try {
      if (loadingMessage != null && mounted) {
        setState(() {
          _error = null;
        });
        // Mostrar loading solo si es una operación larga
        if (loadingMessage.isNotEmpty) {
          _showMessage(loadingMessage);
        }
      }

      final result = await operation();

      if (successMessage != null && mounted) {
        _showMessage(successMessage);
      }

      return result;
    } catch (e) {
      String userMessage;

      if (e.toString().contains('temporalmente no disponible') ||
          e.toString().contains('unavailable') ||
          e.toString().contains('service is currently unavailable')) {
        userMessage = '🔄 Servicio temporalmente no disponible\n\n'
            'Firebase está experimentando dificultades técnicas. '
            'Por favor, inténtalo de nuevo en unos momentos.\n\n'
            'Puedes tocar "Reintentar" para volver a intentarlo.';
      } else if (e.toString().contains('permission-denied')) {
        userMessage = '🚫 Sin permisos\n\n'
            'No tienes los permisos necesarios para realizar esta acción.';
      } else if (e.toString().contains('network')) {
        userMessage = '📡 Problema de conexión\n\n'
            'Verifica tu conexión a internet e inténtalo de nuevo.';
      } else {
        userMessage = 'Error en ${operationName ?? "la operación"}\n\n'
            '${e.toString()}';
      }

      if (mounted) {
        _showMessage(userMessage, isError: true);
      }

      return null;
    }
  }
}

// Función helper para mostrar el modal
void showCollaboratorsModal(
    BuildContext context, String guideId, String guideTitle) {
  showCupertinoModalPopup<void>(
    context: context,
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: CollaboratorsModal(
        guideId: guideId,
        guideTitle: guideTitle,
      ),
    ),
  );
}
