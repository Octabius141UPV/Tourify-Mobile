import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:tourify_flutter/services/attachments_service.dart';
import 'package:tourify_flutter/services/ticket_upload_service.dart';
import 'package:tourify_flutter/models/ticket_ui_state.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

class TicketsSection extends StatefulWidget {
  final String guideId;
  final bool canEdit; // editor/owner
  final List<int> days;
  final String? relatedActivityIdFilter;
  final VoidCallback? onReopenModal;

  const TicketsSection({
    super.key,
    required this.guideId,
    required this.canEdit,
    required this.days,
    this.relatedActivityIdFilter,
    this.onReopenModal,
  });

  @override
  State<TicketsSection> createState() => _TicketsSectionState();
}

class _TicketsSectionState extends State<TicketsSection> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AttachmentsService _attachmentsService = AttachmentsService();
  final TicketUploadService _ticketUploadService = TicketUploadService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const bool _ticketsAddVisible = true;

  TicketUIState _uiState = const TicketUIState();

  @override
  void initState() {
    super.initState();
    if (widget.canEdit) {
      _loadCollaborators();
    }
  }

  Future<void> _loadCollaborators() async {
    _updateUIState(_uiState.copyWith(isLoadingCollaborators: true));

    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final snapshot = await _firestore
          .collection('guides')
          .doc(widget.guideId)
          .collection('collaborators')
          .get();

      final collaborators = <Collaborator>[];
      // Incluir siempre al owner actual por si no está en la subcolección
      collaborators.add(Collaborator(uid: user.uid, label: 'Yo'));

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final String? uid =
            (data['uid'] as String?) ?? (data['userId'] as String?);
        if (uid == null || uid.isEmpty) continue;

        final label = (data['email'] as String?) ?? uid;
        collaborators.add(Collaborator(uid: uid, label: label));
      }

      _updateUIState(_uiState.copyWith(collaborators: collaborators));
    } catch (_) {
      // Error silencioso - podríamos agregar logging aquí
    } finally {
      if (mounted) {
        _updateUIState(_uiState.copyWith(isLoadingCollaborators: false));
      }
    }
  }

  /// Método helper para actualizar el estado de la UI de forma consistente
  void _updateUIState(TicketUIState newState) {
    if (mounted) {
      setState(() {
        _uiState = newState;
      });
    }
  }

  /// Muestra un mensaje de error de forma consistente
  void _showErrorMessage(BuildContext context, String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Muestra un mensaje de éxito de forma consistente
  void _showSuccessMessage(BuildContext context, String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    if (user == null) {
      return _buildAuthRequired(context);
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground.resolveFrom(context),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(CupertinoIcons.ticket,
                  color: CupertinoColors.activeBlue, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Tickets y reservas',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              if (widget.canEdit && _ticketsAddVisible)
                CupertinoButton.filled(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minSize: 30,
                  onPressed: _uiState.isUploading ? null : _showAddOptions,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_uiState.isUploading)
                        const Padding(
                          padding: EdgeInsets.only(right: 8.0),
                          child: CupertinoActivityIndicator(
                              color: Colors.white, radius: 8),
                        )
                      else
                        const Icon(CupertinoIcons.add,
                            size: 18, color: CupertinoColors.white),
                      const SizedBox(width: 6),
                      const Text(
                        'Añadir',
                        style: TextStyle(
                            fontSize: 14, color: CupertinoColors.white),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (_uiState.isLoadingCollaborators && widget.canEdit)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: LinearProgressIndicator(minHeight: 2),
            ),
          _buildFilters(user.uid),
          const SizedBox(height: 8),
          StreamBuilder<List<Attachment>>(
            stream: _attachmentsService.streamByGuide(
              guideId: widget.guideId,
              relatedActivityId: widget.relatedActivityIdFilter,
              dayNumber: _uiState.selectedDay,
              assignedTo: widget.canEdit ? _uiState.assignedToFilter : user.uid,
              onlyMineIfViewer: !widget.canEdit,
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final items = snapshot.data ?? [];
              if (items.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(12.0),
                  child: Text(
                    'No hay tickets aún',
                    style: TextStyle(color: Colors.grey),
                  ),
                );
              }
              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final a = items[index];
                  return _cupertinoCell(a);
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAuthRequired(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: [
          Icon(Icons.lock, color: Colors.orange),
          SizedBox(width: 8),
          Expanded(
            child: Text('Inicia sesión para ver y añadir tickets'),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters(String currentUid) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _pill(
          icon: CupertinoIcons.calendar,
          label: _uiState.selectedDay == null
              ? 'Todos los días'
              : 'Día ${_uiState.selectedDay}',
          onTap: _pickDayCupertino,
        ),
        if (widget.canEdit)
          _pill(
            icon: CupertinoIcons.person_crop_circle,
            label: _uiState.assignedToFilter == null
                ? 'Todas las personas'
                : (_uiState.collaborators
                    .firstWhere((c) => c.uid == _uiState.assignedToFilter,
                        orElse: () => Collaborator(uid: '', label: 'Persona'))
                    .label),
            onTap: _pickAssigneeCupertino,
          ),
      ],
    );
  }

  Widget _pill(
      {required IconData icon,
      required String label,
      required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: CupertinoColors.systemGrey6,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: CupertinoColors.activeBlue),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 13)),
            const SizedBox(width: 4),
            const Icon(CupertinoIcons.chevron_down,
                size: 12, color: CupertinoColors.inactiveGray),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDayCupertino() async {
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Filtrar por día'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              _updateUIState(_uiState.copyWith(selectedDay: null));
              Navigator.pop(context);
            },
            child: const Text('Todos los días'),
          ),
          ...widget.days.map((d) => CupertinoActionSheetAction(
                onPressed: () {
                  _updateUIState(_uiState.copyWith(selectedDay: d));
                  Navigator.pop(context);
                },
                child: Text('Día $d'),
              )),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          isDefaultAction: true,
          child: const Text('Cancelar'),
        ),
      ),
    );
  }

  Future<void> _pickAssigneeCupertino() async {
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Filtrar por persona'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              _updateUIState(_uiState.copyWith(assignedToFilter: null));
              Navigator.pop(context);
            },
            child: const Text('Todas las personas'),
          ),
          ..._uiState.collaborators.map((c) => CupertinoActionSheetAction(
                onPressed: () {
                  _updateUIState(_uiState.copyWith(assignedToFilter: c.uid));
                  Navigator.pop(context);
                },
                child: Text(c.label),
              )),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          isDefaultAction: true,
          child: const Text('Cancelar'),
        ),
      ),
    );
  }

  Future<void> _onAddTicketPressed() async {
    if (_uiState.isUploading) return;

    // Capturar referencias ANTES de cerrar el modal, para no usar un context desmontado
    final NavigatorState rootNav = Navigator.of(context, rootNavigator: true);
    final BuildContext rootContext = rootNav.context;
    final VoidCallback? reopen = widget.onReopenModal;

    // Cerrar el modal actual
    rootNav.pop();

    try {
      // Esperar a que se desmonte el modal completamente
      await WidgetsBinding.instance.endOfFrame;
      await Future.delayed(const Duration(milliseconds: 200));

      // Seleccionar archivo desde el contexto limpio (evitar cargar bytes grandes en memoria)
      final result = await FilePicker.platform.pickFiles(withData: false);
      if (result == null || result.files.isEmpty) {
        await Future.delayed(const Duration(milliseconds: 200));
        reopen?.call();
        return;
      }

      final file = result.files.first;
      final path = file.path;
      if (path == null || path.isEmpty) {
        await Future.delayed(const Duration(milliseconds: 200));
        reopen?.call();
        return;
      }

      // Validación previa
      if (!_ticketUploadService.isValidTicketFile(file)) {
        ScaffoldMessenger.of(rootContext).showSnackBar(
          const SnackBar(
              content: Text('Archivo no permitido o excede 10MB')),
        );
        await Future.delayed(const Duration(milliseconds: 200));
        reopen?.call();
        return;
      }

      final user = _auth.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(rootContext).showSnackBar(
          const SnackBar(content: Text('Debes iniciar sesión')),
        );
        await Future.delayed(const Duration(milliseconds: 200));
        reopen?.call();
        return;
      }

      String assignedUid = user.uid;
      if (widget.canEdit && _uiState.collaborators.isNotEmpty) {
        // Mostrar diálogo de asignación desde el root context (sin modal abierto)
        final selected = await _askAssigneeFromRoot(rootContext, assignedUid);
        assignedUid = selected ?? user.uid;
      }

      // Subir archivo (ya sin modal interferiendo) usando el servicio dedicado
      _updateUIState(_uiState.copyWith(isUploading: true));
      await _ticketUploadService.uploadFileTicket(
        guideId: widget.guideId,
        file: file,
        assignedUserId: assignedUid,
        dayNumber: _uiState.selectedDay,
        relatedActivityId: widget.relatedActivityIdFilter,
      );

      // Mostrar éxito y reabrir modal
      ScaffoldMessenger.of(rootContext).showSnackBar(
        const SnackBar(content: Text('Ticket subido correctamente')),
      );

      await Future.delayed(const Duration(milliseconds: 300));
      reopen?.call();
    } catch (e) {
      // Notificar error y reabrir modal
      ScaffoldMessenger.of(rootContext).showSnackBar(
        SnackBar(
          content: Text('Error subiendo ticket: $e'),
          backgroundColor: Colors.red,
        ),
      );
      await Future.delayed(const Duration(milliseconds: 300));
      reopen?.call();
    } finally {
      if (mounted) {
        _updateUIState(_uiState.copyWith(isUploading: false));
      }
    }
  }

  Future<void> _onAddLinkPressed() async {
    final NavigatorState rootNav = Navigator.of(context, rootNavigator: true);
    final BuildContext rootContext = rootNav.context;
    final VoidCallback? reopen = widget.onReopenModal;

    // Cerrar modal para evitar overlays
    rootNav.pop();

    try {
      await WidgetsBinding.instance.endOfFrame;
      await Future.delayed(const Duration(milliseconds: 150));

      // Dialogo simple para pedir URL y título opcional
      final url = await _promptForText(rootContext,
          title: 'Pegar enlace del ticket', placeholder: 'https://...');
      if (url == null || url.trim().isEmpty) {
        await Future.delayed(const Duration(milliseconds: 150));
        reopen?.call();
        return;
      }

      final title = await _promptForText(rootContext,
          title: 'Título (opcional)', placeholder: 'Ej. Billete AVE');

      final user = _auth.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(rootContext).showSnackBar(
          const SnackBar(content: Text('Debes iniciar sesión')),
        );
        await Future.delayed(const Duration(milliseconds: 150));
        reopen?.call();
        return;
      }

      String assignedUid = user.uid;
      if (widget.canEdit && _uiState.collaborators.isNotEmpty) {
        final selected = await _askAssigneeFromRoot(rootContext, assignedUid);
        assignedUid = selected ?? user.uid;
      }

      // Validar URL
      if (!_ticketUploadService.isValidTicketUrl(url)) {
        ScaffoldMessenger.of(rootContext).showSnackBar(
          const SnackBar(content: Text('URL no válida')),
        );
        await Future.delayed(const Duration(milliseconds: 150));
        reopen?.call();
        return;
      }

      _updateUIState(_uiState.copyWith(isUploading: true));
      await _ticketUploadService.createLinkTicket(
        guideId: widget.guideId,
        url: url,
        title: title,
        assignedUserId: assignedUid,
        dayNumber: _uiState.selectedDay,
        relatedActivityId: widget.relatedActivityIdFilter,
      );

      ScaffoldMessenger.of(rootContext).showSnackBar(
        const SnackBar(content: Text('Enlace guardado correctamente')),
      );
      await Future.delayed(const Duration(milliseconds: 250));
      reopen?.call();
    } catch (e) {
      ScaffoldMessenger.of(rootContext).showSnackBar(
        SnackBar(content: Text('Error guardando enlace: $e')),
      );
      await Future.delayed(const Duration(milliseconds: 250));
      reopen?.call();
    } finally {
      if (mounted) {
        _updateUIState(_uiState.copyWith(isUploading: false));
      }
    }
  }

  Future<void> _showAddOptions() async {
    final NavigatorState rootNav = Navigator.of(context, rootNavigator: true);
    final BuildContext rootContext = rootNav.context;

    // Cupertino action sheet con dos opciones: Archivo o Enlace
    final choice = await showCupertinoModalPopup<String>(
      context: rootContext,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('Añadir ticket'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(ctx, 'file'),
            child: const Text('Desde archivo'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(ctx, 'link'),
            child: const Text('Desde enlace'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancelar'),
        ),
      ),
    );

    if (choice == 'file') {
      await _onAddTicketPressed();
    } else if (choice == 'link') {
      await _onAddLinkPressed();
    }
  }

  Future<String?> _promptForText(BuildContext rootContext,
      {required String title, String? placeholder}) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: rootContext,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: placeholder),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Future<String?> _askAssigneeFromRoot(
      BuildContext rootContext, String initial) async {
    return showCupertinoModalPopup<String>(
      context: rootContext,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Asignar ticket a'),
        actions: _uiState.collaborators
            .map((c) => CupertinoActionSheetAction(
                  onPressed: () => Navigator.pop(context, c.uid),
                  child: Text(c.label),
                ))
            .toList(),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context, initial),
          isDefaultAction: true,
          child: const Text('Cancelar'),
        ),
      ),
    );
  }

  String _subtitleOf(Attachment a) {
    final parts = <String>[];
    if (a.dayNumber != null) parts.add('Día ${a.dayNumber}');
    parts.add(a.category);
    parts.add(a.type);
    return parts.join(' • ');
  }

  IconData _iconForMime(String mime) {
    if (mime.contains('pdf')) return CupertinoIcons.doc_fill;
    if (mime.contains('image'))
      return CupertinoIcons.photo_fill_on_rectangle_fill;
    return CupertinoIcons.doc_text_fill;
  }

  Future<void> _openAttachment(Attachment a) async {
    final uri = Uri.tryParse(a.fileUrl);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _deleteAttachment(Attachment a) async {
    await _attachmentsService.deleteAttachment(
      guideId: a.guideId,
      attachmentId: a.id,
    );
  }

  Widget _cupertinoCell(Attachment a) {
    return InkWell(
      onTap: () => _openAttachment(a),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(
                color: Color(0x1F8E8E93), width: 0.5), // iOS separator
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: CupertinoColors.systemGrey5,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(_iconForMime(a.mimeType),
                  color: CupertinoColors.activeBlue, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    a.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _subtitleOf(a),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12, color: CupertinoColors.inactiveGray),
                  ),
                ],
              ),
            ),
            if (widget.canEdit)
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                minSize: 28,
                onPressed: () => _deleteAttachment(a),
                child: const Icon(CupertinoIcons.delete_solid,
                    size: 18, color: CupertinoColors.systemRed),
              )
            else
              const Icon(CupertinoIcons.chevron_forward,
                  size: 16, color: CupertinoColors.inactiveGray),
          ],
        ),
      ),
    );
  }
}

// Nota: detección de MIME centralizada en TicketUploadService
