import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/collaborators_service.dart';

class CollaboratorsScreen extends StatefulWidget {
  final String guideId;
  final String guideTitle;

  const CollaboratorsScreen({
    super.key,
    required this.guideId,
    required this.guideTitle,
  });

  @override
  State<CollaboratorsScreen> createState() => _CollaboratorsScreenState();
}

class _CollaboratorsScreenState extends State<CollaboratorsScreen>
    with SingleTickerProviderStateMixin {
  final CollaboratorsService _collaboratorsService = CollaboratorsService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _emailController = TextEditingController();

  List<Map<String, dynamic>> _collaborators = [];
  String? _userRole;
  bool _isLoading = true;
  bool _isAddingCollaborator = false;
  String? _error;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadCollaborators();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _tabController.dispose();
    super.dispose();
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

      setState(() {
        _userRole = userRoleResponse['role'] as String?;
        _collaborators =
            (collaboratorsResponse['collaborators'] as List<dynamic>?)
                    ?.cast<Map<String, dynamic>>() ??
                [];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error al cargar colaboradores: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _addCollaborator(String role) async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, introduce un email')),
      );
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
        role: role,
      );
      _emailController.clear();
      await _loadCollaborators(); // Recargar la lista

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Colaborador agregado como $role')),
        );
      }
    } catch (e) {
      setState(() {
        _error = 'Error al agregar colaborador: $e';
      });
    } finally {
      setState(() {
        _isAddingCollaborator = false;
      });
    }
  }

  Future<void> _removeCollaborator(String collaboratorId) async {
    // Mostrar diálogo de confirmación
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar eliminación'),
        content: const Text(
            '¿Estás seguro de que quieres eliminar este colaborador?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _collaboratorsService.removeCollaborator(
            widget.guideId, collaboratorId);
        await _loadCollaborators(); // Recargar la lista

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Colaborador eliminado')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al eliminar colaborador: $e')),
          );
        }
      }
    }
  }

  List<Map<String, dynamic>> _getCollaboratorsByRole(String role) {
    return _collaborators.where((c) => c['role'] == role).toList();
  }

  bool _canManageCollaborators() {
    return _userRole == 'owner' || _userRole == 'editor';
  }

  Widget _buildAddCollaboratorForm(String role) {
    if (!_canManageCollaborators()) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Text(
          'No tienes permisos para gestionar colaboradores',
          style: TextStyle(color: Colors.grey),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: 'Email del colaborador',
              hintText: 'ejemplo@email.com',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.email),
              enabled: !_isAddingCollaborator,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed:
                  _isAddingCollaborator ? null : () => _addCollaborator(role),
              style: ElevatedButton.styleFrom(
                backgroundColor: role == 'editor' ? Colors.blue : Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: _isAddingCollaborator
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      'Agregar como ${role == 'editor' ? 'Organizador' : 'Acoplado'}'),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: const TextStyle(color: Colors.red, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCollaboratorsList(String role) {
    final collaborators = _getCollaboratorsByRole(role);

    if (collaborators.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(
              role == 'editor' ? Icons.edit : Icons.visibility,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No hay ${role == 'editor' ? 'organizadores' : 'acoplados'} aún',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              role == 'editor'
                  ? 'Los organizadores pueden modificar la guía'
                  : 'Los acoplados solo pueden ver la guía',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: collaborators.length,
      itemBuilder: (context, index) {
        final collaborator = collaborators[index];
        return _buildCollaboratorTile(collaborator);
      },
    );
  }

  Widget _buildCollaboratorTile(Map<String, dynamic> collaborator) {
    final isOwner = collaborator['role'] == 'owner';
    final canRemove = _canManageCollaborators() && !isOwner;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getRoleColor(collaborator['role']),
          child: Icon(
            _getRoleIcon(collaborator['role']),
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Text(
          collaborator['email'] ?? 'Email no disponible',
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          _getRoleDisplayName(collaborator['role']),
          style: TextStyle(
            color: _getRoleColor(collaborator['role']),
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: canRemove
            ? IconButton(
                onPressed: () => _removeCollaborator(collaborator['id']),
                icon: const Icon(Icons.remove_circle_outline),
                color: Colors.red,
                tooltip: 'Eliminar colaborador',
              )
            : isOwner
                ? const Icon(Icons.star, color: Colors.amber)
                : null,
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'owner':
        return Colors.amber;
      case 'editor':
        return Colors.blue;
      case 'viewer':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData _getRoleIcon(String role) {
    switch (role) {
      case 'owner':
        return Icons.star;
      case 'editor':
        return Icons.edit;
      case 'viewer':
        return Icons.visibility;
      default:
        return Icons.person;
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
    return Scaffold(
      appBar: AppBar(
        title: Text('Colaboradores - ${widget.guideTitle}'),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black87,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(
              icon: const Icon(Icons.edit),
              text:
                  'Organizadores (${_getCollaboratorsByRole('editor').length})',
            ),
            Tab(
              icon: const Icon(Icons.visibility),
              text: 'Acoplados (${_getCollaboratorsByRole('viewer').length})',
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                // Tab de Editores
                SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildAddCollaboratorForm('editor'),
                      const Divider(),
                      _buildCollaboratorsList('editor'),
                    ],
                  ),
                ),
                // Tab de Acoplados
                SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildAddCollaboratorForm('viewer'),
                      const Divider(),
                      _buildCollaboratorsList('viewer'),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
