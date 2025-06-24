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
      print('Error al cargar links de acceso: $e');
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
    print('DEBUG: Cargando colaboradores...');
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final collaboratorsResponse =
          await _collaboratorsService.getCollaborators(widget.guideId);
      print('DEBUG: Respuesta de colaboradores: $collaboratorsResponse');

      final userRole = (collaboratorsResponse is Map &&
              collaboratorsResponse['userRole'] is String)
          ? collaboratorsResponse['userRole'] as String?
          : null;
      final collaboratorsList = (collaboratorsResponse is Map &&
              collaboratorsResponse['collaborators'] is List)
          ? (collaboratorsResponse['collaborators'] as List)
              .whereType<Map<String, dynamic>>()
              .toList()
          : <Map<String, dynamic>>[];

      setState(() {
        _userRole = userRole;
        _collaborators = collaboratorsList;
        _isLoading = false;
      });
      print('DEBUG: Colaboradores cargados: \\${_collaborators.length}');
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
        return 'Editor';
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
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          SizedBox(
                            height: 48,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 22, vertical: 0),
                                textStyle: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w600),
                                minimumSize: const Size(0, 48),
                              ),
                              onPressed: _isGeneratingLink
                                  ? null
                                  : _generateAccessLink,
                              child: _isGeneratingLink
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Text('Generar link'),
                            ),
                          ),
                          const SizedBox(width: 20),
                          Container(
                            height: 48,
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedRole,
                                isDense: true,
                                style: const TextStyle(
                                    fontSize: 16, color: Colors.black),
                                alignment: Alignment.center,
                                items: const [
                                  DropdownMenuItem(
                                    value: 'viewer',
                                    child: Text('Acoplado'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'editor',
                                    child: Text('Organizador'),
                                  ),
                                ],
                                onChanged: _isGeneratingLink
                                    ? null
                                    : (value) {
                                        if (value != null) {
                                          setState(() => _selectedRole = value);
                                        }
                                      },
                              ),
                            ),
                          ),
                        ],
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
