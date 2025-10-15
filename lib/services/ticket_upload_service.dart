import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:tourify_flutter/services/attachments_service.dart';

/// Servicio especializado para manejar la lógica de subida de tickets
/// Separando la lógica de negocio de la UI
class TicketUploadService {
  final AttachmentsService _attachmentsService = AttachmentsService();

  /// Detecta el tipo MIME de un archivo basado en su extensión
  String detectMimeType(PlatformFile file) {
    final extension = file.extension?.toLowerCase();
    switch (extension) {
      case 'pdf':
        return 'application/pdf';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'txt':
        return 'text/plain';
      default:
        return 'application/octet-stream';
    }
  }

  /// Sube un archivo como ticket
  Future<void> uploadFileTicket({
    required String guideId,
    required PlatformFile file,
    required String assignedUserId,
    int? dayNumber,
    String? relatedActivityId,
  }) async {
    final mimeType = detectMimeType(file);

    if (file.bytes != null) {
      await _attachmentsService.uploadAttachment(
        guideId: guideId,
        bytes: file.bytes!,
        originalName: file.name,
        mimeType: mimeType,
        title: file.name,
        category: 'activity',
        type: 'ticket',
        assignedToUserId: assignedUserId,
        dayNumber: dayNumber,
        relatedActivityId: relatedActivityId,
      );
    } else if (file.path != null && file.path!.isNotEmpty) {
      await _attachmentsService.uploadAttachmentFromFile(
        guideId: guideId,
        file: File(file.path!),
        originalName: file.name,
        mimeType: mimeType,
        title: file.name,
        category: 'activity',
        type: 'ticket',
        assignedToUserId: assignedUserId,
        dayNumber: dayNumber,
        relatedActivityId: relatedActivityId,
      );
    } else {
      throw Exception('No se pudo obtener los datos del archivo');
    }
  }

  /// Crea un ticket de tipo enlace
  Future<void> createLinkTicket({
    required String guideId,
    required String url,
    String? title,
    required String assignedUserId,
    int? dayNumber,
    String? relatedActivityId,
  }) async {
    await _attachmentsService.createLinkAttachment(
      guideId: guideId,
      url: url.trim(),
      title: (title ?? '').trim(),
      category: 'activity',
      type: 'ticket',
      assignedToUserId: assignedUserId,
      dayNumber: dayNumber,
      relatedActivityId: relatedActivityId,
    );
  }

  /// Valida que un archivo sea válido para subir como ticket
  bool isValidTicketFile(PlatformFile file) {
    // Verificar tamaño máximo (10MB)
    const maxSize = 10 * 1024 * 1024;
    if (file.size > maxSize) {
      return false;
    }

    // Verificar extensiones permitidas
    final allowedExtensions = {
      'pdf',
      'jpg',
      'jpeg',
      'png',
      'gif',
      'doc',
      'docx',
      'txt',
      'zip',
      'rar'
    };

    final extension = file.extension?.toLowerCase();
    return extension != null && allowedExtensions.contains(extension);
  }

  /// Valida que una URL sea válida para crear un ticket de enlace
  bool isValidTicketUrl(String url) {
    try {
      final uri = Uri.parse(url.trim());
      return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (e) {
      return false;
    }
  }
}
