import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/collaborators_service.dart';

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

class _CollaboratorsModalState extends State<CollaboratorsModal> {
  final CollaboratorsService _collaboratorsService = CollaboratorsService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _emailController = TextEditingController();

  List<Map<String, dynamic>> _collaborators = [];
  String? _userRole;
  bool _isLoading = true;
  bool _isAddingCollaborator = false;
  String? _error;
  String _selectedRole = 'viewer';

  @override
  void initState() {
    super.initState();
    _loadCollaborators();
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadCollaborators() async {
    print('DEBUG: Cargando colaboradores...');
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final collaboratorsResponse =
          await _collaboratorsService.getCollaborators(widget.guideId);
      print('DEBUG: Respuesta de colaboradores: $collaboratorsResponse');

      // Obtener rol del usuario actual
      final user = _auth.currentUser;
      if (user != null) {
        final userRoleResponse =
            await _collaboratorsService.getUserRole(widget.guideId);
        print('DEBUG: Respuesta de rol de usuario: $userRoleResponse');
        setState(() {
          _userRole = userRoleResponse['role'] as String?;
        });
      }

      setState(() {
        _collaborators =
            (collaboratorsResponse['collaborators'] as List<dynamic>?)
                    ?.cast<Map<String, dynamic>>() ??
                [];
        _isLoading = false;
      });
      print('DEBUG: Colaboradores cargados: ${_collaborators.length}');
    } catch (e) {
      print('DEBUG: Error al cargar colaboradores: $e');
      setState(() {
        _error = 'Error al cargar colaboradores: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _addCollaborator() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showMessage('Por favor, introduce un email', isError: true);
      return;
    }

    setState(() {
      _isAddingCollaborator = true;
      _error = null;
    });

    try {
      final result = await _collaboratorsService.addCollaborator(
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
        return 'Editor';
      case 'viewer':
        return 'Visualizador';
      default:
        return 'Rol desconocido';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.85,
        margin: EdgeInsets.only(top: MediaQuery.of(context).size.height * 0.15),
        decoration: const BoxDecoration(
          color: CupertinoColors.systemBackground,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          children: [
            // Header fijo
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
              child: SafeArea(
                bottom: false,
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
                    Expanded(
                      child: Text(
                        'Colaboradores',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: CupertinoColors.label.resolveFrom(context),
                        ),
                      ),
                    ),
                    if (_canManageCollaborators())
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: _showAddCollaboratorSheet,
                        child: const Icon(
                          CupertinoIcons.add,
                          color: CupertinoColors.systemBlue,
                          size: 22,
                        ),
                      )
                    else
                      const SizedBox(width: 60), // Para mantener el centro
                  ],
                ),
              ),
            ),
            // Contenido scrollable
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CupertinoActivityIndicator(radius: 16),
                    )
                  : _buildContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              CupertinoIcons.exclamationmark_triangle,
              size: 48,
              color: CupertinoColors.systemRed,
            ),
            const SizedBox(height: 16),
            Text(
              'Error al cargar',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: CupertinoColors.label.resolveFrom(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
            ),
            const SizedBox(height: 20),
            CupertinoButton.filled(
              onPressed: _loadCollaborators,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    if (_collaborators.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              CupertinoIcons.person_2,
              size: 64,
              color: CupertinoColors.systemGrey,
            ),
            const SizedBox(height: 20),
            Text(
              'Sin colaboradores',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: CupertinoColors.label.resolveFrom(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Invita a otros usuarios para que colaboren en esta guía',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
            ),
            if (_canManageCollaborators()) ...[
              const SizedBox(height: 24),
              CupertinoButton.filled(
                onPressed: _showAddCollaboratorSheet,
                child: const Text('Invitar colaborador'),
              ),
            ],
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _collaborators.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final collaborator = _collaborators[index];
        return _buildCollaboratorTile(collaborator);
      },
    );
  }

  Widget _buildCollaboratorTile(Map<String, dynamic> collaborator) {
    final email = collaborator['email'] as String;
    final role = collaborator['role'] as String;
    final isCurrentUser = _auth.currentUser?.email == email;

    return Container(
      decoration: BoxDecoration(
        color: CupertinoColors.secondarySystemBackground.resolveFrom(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _getRoleColor(role).withOpacity(0.15),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Icon(
                _getRoleIcon(role),
                color: _getRoleColor(role),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            // Info del colaborador
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          email,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: CupertinoColors.label.resolveFrom(context),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isCurrentUser) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: CupertinoColors.systemBlue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Tú',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: CupertinoColors.systemBlue,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _getRoleDisplayName(role),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: _getRoleColor(role),
                    ),
                  ),
                ],
              ),
            ),
            // Botón eliminar
            if (_canManageCollaborators() && !isCurrentUser)
              CupertinoButton(
                padding: EdgeInsets.zero,
                minSize: 0,
                onPressed: () => _showRemoveCollaboratorDialog(email),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemRed.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    CupertinoIcons.trash,
                    color: CupertinoColors.systemRed,
                    size: 16,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showAddCollaboratorSheet() {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext context) {
        return _AddCollaboratorSheet(
          onAdd: () {
            _addCollaborator();
            Navigator.of(context).pop();
          },
          emailController: _emailController,
          selectedRole: _selectedRole,
          onRoleChanged: (String newRole) {
            setState(() {
              _selectedRole = newRole;
            });
          },
          isLoading: _isAddingCollaborator,
        );
      },
    );
  }

  void _showRemoveCollaboratorDialog(String email) {
    showCupertinoDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return CupertinoAlertDialog(
          title: const Text('Eliminar colaborador'),
          content: Text('¿Seguro que quieres eliminar a $email?'),
          actions: <CupertinoDialogAction>[
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
        );
      },
    );
  }
}

// Widget para agregar colaborador
class _AddCollaboratorSheet extends StatefulWidget {
  final VoidCallback onAdd;
  final TextEditingController emailController;
  final String selectedRole;
  final ValueChanged<String> onRoleChanged;
  final bool isLoading;

  const _AddCollaboratorSheet({
    required this.onAdd,
    required this.emailController,
    required this.selectedRole,
    required this.onRoleChanged,
    required this.isLoading,
  });

  @override
  State<_AddCollaboratorSheet> createState() => _AddCollaboratorSheetState();
}

class _AddCollaboratorSheetState extends State<_AddCollaboratorSheet> {
  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.6,
        margin: EdgeInsets.only(top: MediaQuery.of(context).size.height * 0.4),
        decoration: const BoxDecoration(
          color: CupertinoColors.systemBackground,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
              child: SafeArea(
                bottom: false,
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
                      onPressed: widget.isLoading ? null : widget.onAdd,
                      child: widget.isLoading
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
            ),
            // Contenido
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
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
                      controller: widget.emailController,
                      placeholder: 'ejemplo@email.com',
                      keyboardType: TextInputType.emailAddress,
                      enabled: !widget.isLoading,
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
                      'Visualizador',
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
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleOption(String value, String title, String description,
      IconData icon, Color color) {
    final isSelected = widget.selectedRole == value;

    return GestureDetector(
      onTap: widget.isLoading ? null : () => widget.onRoleChanged(value),
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
}

// Función helper para mostrar el modal
void showCollaboratorsModal(
    BuildContext context, String guideId, String guideTitle) {
  showCupertinoModalPopup<void>(
    context: context,
    builder: (context) => CollaboratorsModal(
      guideId: guideId,
      guideTitle: guideTitle,
    ),
  );
}
