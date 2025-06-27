import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/collaborators_service.dart';
import 'package:flutter/services.dart';

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
    setState(() {
      _isGeneratingLink = true;
      _error = null;
    });

    try {
      final result = await _collaboratorsService.generateAccessLink(
          widget.guideId, _selectedRole);
      await _loadAccessLinks();
      if (mounted) {
        // Copiar el link al portapapeles
        final String? link = result['link'] as String?;
        if (link != null) {
          await Clipboard.setData(ClipboardData(text: link));
          _showMessage(
              '✅ Link generado y copiado al portapapeles\n\nComparte este link para que otros se unan a tu guía:\n$link');
        } else {
          _showMessage('Link de acceso generado correctamente');
        }
      }
    } catch (e) {
      if (mounted) {
        _showMessage('Error al generar link de acceso', isError: true);
      }
    } finally {
      setState(() {
        _isGeneratingLink = false;
      });
    }
  }

  Future<void> _revokeAccessLink(String token) async {
    try {
      await _collaboratorsService.revokeAccessLink(widget.guideId, token);
      await _loadAccessLinks();
      if (mounted) {
        _showMessage('Link de acceso revocado correctamente');
      }
    } catch (e) {
      if (mounted) {
        _showMessage('Error al revocar link de acceso', isError: true);
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
    } catch (e) {
      setState(() {
        _error = 'Error al cargar colaboradores: $e';
        _isLoading = false;
      });
    }
  }

  /// Valida si un email tiene formato válido
  bool _isValidEmail(String email) {
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    return emailRegex.hasMatch(email);
  }

  Future<void> _addCollaborator() async {
    final email = _emailController.text.trim();

    // Validar que el email no esté vacío
    if (email.isEmpty) {
      _showMessage('Por favor, introduce un email', isError: true);
      return;
    }

    // Validar que el email tenga formato válido
    if (!_isValidEmail(email)) {
      _showMessage('Por favor, introduce un email válido', isError: true);
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
    if (mounted) {
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: Text(isError ? 'Error' : 'Éxito'),
          content: Text(message),
          actions: [
            CupertinoDialogAction(
              child: const Text('OK'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      );
    }
  }

  bool _canManageCollaborators() {
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
                        'Agregar colaborador',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed:
                          _isAddingCollaborator ? null : _addCollaborator,
                      child: _isAddingCollaborator
                          ? const CupertinoActivityIndicator()
                          : const Text(
                              'Agregar',
                              style: TextStyle(
                                color: CupertinoColors.systemBlue,
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
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
                      // Campo email
                      Text(
                        'Email del colaborador',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: CupertinoColors.label.resolveFrom(context),
                        ),
                      ),
                      const SizedBox(height: 8),
                      CupertinoTextField(
                        controller: _emailController,
                        placeholder: 'ejemplo@email.com',
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.done,
                        enabled: !_isAddingCollaborator,
                        autofocus: false,
                        onSubmitted: (_) => _addCollaborator(),
                        decoration: BoxDecoration(
                          color: CupertinoColors.tertiarySystemBackground
                              .resolveFrom(context),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.all(12),
                      ),
                      const SizedBox(height: 24),

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
                        'Editor',
                        'Puede editar la guía',
                        CupertinoIcons.pencil,
                        CupertinoColors.systemBlue,
                      ),

                      const SizedBox(height: 24),

                      // Sección de generar link
                      _buildGenerateLinkSection(),

                      const SizedBox(height: 32),

                      // Sección de links activos
                      _buildActiveLinks(),

                      const SizedBox(height: 24),

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

  Widget _buildActiveLinks() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              CupertinoIcons.link,
              color: CupertinoColors.systemPurple.resolveFrom(context),
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'Links de acceso activos',
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
                color: CupertinoColors.systemPurple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_accessLinks.length}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: CupertinoColors.systemPurple,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_accessLinks.isEmpty)
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
                  CupertinoIcons.link_circle,
                  size: 40,
                  color: CupertinoColors.systemGrey.resolveFrom(context),
                ),
                const SizedBox(height: 8),
                Text(
                  'No hay links activos',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: CupertinoColors.systemGrey.resolveFrom(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Genera un link para compartir acceso',
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
              children: _accessLinks.asMap().entries.map((entry) {
                final index = entry.key;
                final link = entry.value;
                final isLast = index == _accessLinks.length - 1;

                return _buildAccessLinkItem(link, isLast);
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildAccessLinkItem(Map<String, dynamic> link, bool isLast) {
    final token = link['token'] as String? ?? '';
    final role = link['role'] as String? ?? 'viewer';
    final createdAt = link['createdAt'] as Timestamp?;
    final expiresAt = link['expiresAt'] as Timestamp?;
    final linkUrl = link['link'] as String? ?? '';

    final roleColor = _getRoleColor(role);
    final roleIcon = _getRoleIcon(role);
    final roleDisplayName = _getRoleDisplayName(role);

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: roleColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  roleIcon,
                  color: roleColor,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Link de ${roleDisplayName.toLowerCase()}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
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
                        if (expiresAt != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            'Expira ${_formatDate(expiresAt.toDate())}',
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
              // Botones de acción
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Botón copiar
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    minSize: 32,
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: linkUrl));
                      _showMessage('Link copiado al portapapeles');
                    },
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemBlue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        CupertinoIcons.doc_on_clipboard,
                        color: CupertinoColors.systemBlue,
                        size: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Botón revocar
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    minSize: 32,
                    onPressed: () => _showRevokeAccessLinkDialog(token),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemRed.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        CupertinoIcons.xmark_circle_fill,
                        color: CupertinoColors.systemRed,
                        size: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showRevokeAccessLinkDialog(String token) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Revocar link de acceso'),
        content: const Text(
            '¿Estás seguro de que quieres revocar este link? Ya no funcionará para nuevos usuarios.'),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancelar'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.of(context).pop();
              _revokeAccessLink(token);
            },
            child: const Text('Revocar'),
          ),
        ],
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
    final joinedAt = collaborator['joinedAt'] as Timestamp?;

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
              onPressed: () => _showRemoveCollaboratorDialog(email),
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
    } else if (difference.inDays == 1) {
      return 'ayer';
    } else if (difference.inDays < 7) {
      return 'hace ${difference.inDays} días';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return 'hace ${weeks} semana${weeks > 1 ? 's' : ''}';
    } else {
      final months = (difference.inDays / 30).floor();
      return 'hace ${months} mes${months > 1 ? 'es' : ''}';
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
