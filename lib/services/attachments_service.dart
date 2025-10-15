import 'dart:typed_data';
import 'dart:io';
import 'package:mime/mime.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:tourify_flutter/config/debug_config.dart';

class Attachment {
  final String id;
  final String guideId;
  final String title;
  final String category; // activity | lodging | transport
  final String type; // ticket | reservation | invoice
  final int? dayNumber;
  final String? relatedActivityId;
  final String fileUrl;
  final String mimeType;
  final int sizeBytes;
  final String? thumbnailUrl;
  final String createdBy;
  final String assignedTo;
  final String? provider;
  final String? code;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  Attachment({
    required this.id,
    required this.guideId,
    required this.title,
    required this.category,
    required this.type,
    required this.fileUrl,
    required this.mimeType,
    required this.sizeBytes,
    required this.createdBy,
    required this.assignedTo,
    required this.createdAt,
    required this.updatedAt,
    this.dayNumber,
    this.relatedActivityId,
    this.thumbnailUrl,
    this.provider,
    this.code,
    this.dateFrom,
    this.dateTo,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'guideId': guideId,
      'title': title,
      'category': category,
      'type': type,
      'dayNumber': dayNumber,
      'relatedActivityId': relatedActivityId,
      'fileUrl': fileUrl,
      'mimeType': mimeType,
      'sizeBytes': sizeBytes,
      'thumbnailUrl': thumbnailUrl,
      'createdBy': createdBy,
      'assignedTo': assignedTo,
      'provider': provider,
      'code': code,
      'dateFrom': dateFrom?.toIso8601String(),
      'dateTo': dateTo?.toIso8601String(),
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  static Attachment fromMap(Map<String, dynamic> map) {
    return Attachment(
      id: map['id'] as String,
      guideId: map['guideId'] as String,
      title: map['title'] as String,
      category: map['category'] as String,
      type: map['type'] as String,
      dayNumber: (map['dayNumber'] as num?)?.toInt(),
      relatedActivityId: map['relatedActivityId'] as String?,
      fileUrl: map['fileUrl'] as String,
      mimeType: map['mimeType'] as String,
      sizeBytes: (map['sizeBytes'] as num?)?.toInt() ?? 0,
      thumbnailUrl: map['thumbnailUrl'] as String?,
      createdBy: map['createdBy'] as String,
      assignedTo: map['assignedTo'] as String,
      provider: map['provider'] as String?,
      code: map['code'] as String?,
      dateFrom:
          map['dateFrom'] != null ? DateTime.tryParse(map['dateFrom']) : null,
      dateTo: map['dateTo'] != null ? DateTime.tryParse(map['dateTo']) : null,
      notes: map['notes'] as String?,
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(map['updatedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

class AttachmentsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  CollectionReference<Map<String, dynamic>> _attachmentsCol(String guideId) =>
      _firestore.collection('guides').doc(guideId).collection('attachments');

  Future<Attachment> uploadAttachment({
    required String guideId,
    required Uint8List bytes,
    required String originalName,
    required String mimeType,
    required String title,
    required String category,
    required String type,
    required String assignedToUserId,
    int? dayNumber,
    String? relatedActivityId,
    String? provider,
    String? code,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? notes,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Usuario no autenticado');
    }

    final now = DateTime.now();
    final docRef = _attachmentsCol(guideId).doc();
    final attachmentId = docRef.id;

    // Subir a Storage
    final storagePath = 'guides/$guideId/attachments/$attachmentId/original';
    final storageRef = _storage.ref().child(storagePath);
    final resolvedMime = mimeType.isNotEmpty
        ? mimeType
        : (lookupMimeType(originalName,
                headerBytes:
                    bytes.length > 64 ? bytes.sublist(0, 64) : bytes) ??
            'application/octet-stream');
    final metadata = SettableMetadata(
      contentType: resolvedMime,
      customMetadata: {
        'guideId': guideId,
        'attachmentId': attachmentId,
        'assignedTo': assignedToUserId,
        'createdBy': user.uid,
        'mimeType': resolvedMime,
        'originalName': originalName,
      },
      cacheControl: 'public,max-age=31536000',
    );
    // Logs de depuración
    print('[ATTACHMENTS] putData');
    print(' - storagePath: ' + storagePath);
    print(' - guideId: ' + guideId);
    print(' - attachmentId: ' + attachmentId);
    print(' - originalName: ' + originalName);
    print(' - resolvedMime: ' + resolvedMime);
    print(' - sizeBytes: ' + bytes.lengthInBytes.toString());
    print(' - assignedTo: ' + assignedToUserId);
    print(' - createdBy: ' + user.uid);

    try {
      // pequeño delay para asegurar que no hay animaciones/sheets cerrándose
      await Future.delayed(const Duration(milliseconds: 150));
      final snapshot = await storageRef.putData(bytes, metadata);
      print(' - upload state: ' + snapshot.state.toString());
      final fileUrl = await snapshot.ref.getDownloadURL();
      print(' - downloadURL: ' + fileUrl);

      final attachment = Attachment(
        id: attachmentId,
        guideId: guideId,
        title: title,
        category: category,
        type: type,
        dayNumber: dayNumber,
        relatedActivityId: relatedActivityId,
        fileUrl: fileUrl,
        mimeType: resolvedMime,
        sizeBytes: bytes.lengthInBytes,
        thumbnailUrl: null,
        createdBy: user.uid,
        assignedTo: assignedToUserId,
        provider: provider,
        code: code,
        dateFrom: dateFrom,
        dateTo: dateTo,
        notes: notes,
        createdAt: now,
        updatedAt: now,
      );

      await docRef.set(attachment.toMap());
      return attachment;
    } catch (e) {
      print(' - EXCEPCION putData: ' + e.toString());
      rethrow;
    }
  }

  Future<Attachment> uploadAttachmentFromFile({
    required String guideId,
    required File file,
    required String originalName,
    required String mimeType,
    required String title,
    required String category,
    required String type,
    required String assignedToUserId,
    int? dayNumber,
    String? relatedActivityId,
    String? provider,
    String? code,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? notes,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Usuario no autenticado');
    }

    final now = DateTime.now();
    final docRef = _attachmentsCol(guideId).doc();
    final attachmentId = docRef.id;

    // Subir a Storage con putFile
    final storagePath = 'guides/$guideId/attachments/$attachmentId/original';
    print('[ATTACHMENTS] putFile');
    print(' - storagePath: ' + storagePath);
    final storageRef = _storage.ref().child(storagePath);
    List<int> headerBytes = const [];
    try {
      headerBytes = await file.openRead(0, 64).first;
    } catch (_) {}
    final resolvedMimeFile = mimeType.isNotEmpty
        ? mimeType
        : (lookupMimeType(originalName,
                headerBytes: headerBytes.isNotEmpty ? headerBytes : null) ??
            'application/octet-stream');
    final metadata = SettableMetadata(
      contentType: resolvedMimeFile,
      customMetadata: {
        'guideId': guideId,
        'attachmentId': attachmentId,
        'assignedTo': assignedToUserId,
        'createdBy': user.uid,
        'mimeType': resolvedMimeFile,
        'originalName': originalName,
      },
      cacheControl: 'public,max-age=31536000',
    );
    try {
      final snapshot = await storageRef.putFile(file, metadata);
      print(' - upload state: ' + snapshot.state.toString());
      if (snapshot.state != TaskState.success) {
        throw Exception(
            'Fallo subiendo archivo (' + snapshot.state.toString() + ')');
      }
      final fileUrl = await snapshot.ref.getDownloadURL();
      print(' - downloadURL: ' + fileUrl);

      final fileLength = await file.length();

      final attachment = Attachment(
        id: attachmentId,
        guideId: guideId,
        title: title,
        category: category,
        type: type,
        dayNumber: dayNumber,
        relatedActivityId: relatedActivityId,
        fileUrl: fileUrl,
        mimeType: resolvedMimeFile,
        sizeBytes: fileLength,
        thumbnailUrl: null,
        createdBy: user.uid,
        assignedTo: assignedToUserId,
        provider: provider,
        code: code,
        dateFrom: dateFrom,
        dateTo: dateTo,
        notes: notes,
        createdAt: now,
        updatedAt: now,
      );

      await docRef.set(attachment.toMap());
      return attachment;
    } catch (e) {
      print(' - EXCEPCION putFile: ' + e.toString());
      rethrow;
    }
  }

  Future<Attachment> createLinkAttachment({
    required String guideId,
    required String url,
    required String title,
    required String category,
    required String type,
    required String assignedToUserId,
    int? dayNumber,
    String? relatedActivityId,
    String? provider,
    String? code,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? notes,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Usuario no autenticado');
    }

    final now = DateTime.now();
    final docRef = _attachmentsCol(guideId).doc();
    final attachmentId = docRef.id;

    // Deducir proveedor desde el host si no se pasa explícito
    String? inferredProvider;
    try {
      final uri = Uri.parse(url);
      inferredProvider = uri.host.isNotEmpty ? uri.host : null;
    } catch (_) {}

    final attachment = Attachment(
      id: attachmentId,
      guideId: guideId,
      title: title.isNotEmpty ? title : url,
      category: category,
      type: type,
      dayNumber: dayNumber,
      relatedActivityId: relatedActivityId,
      fileUrl: url,
      mimeType: 'text/uri-list',
      sizeBytes: 0,
      thumbnailUrl: null,
      createdBy: user.uid,
      assignedTo: assignedToUserId,
      provider: provider ?? inferredProvider,
      code: code,
      dateFrom: dateFrom,
      dateTo: dateTo,
      notes: notes,
      createdAt: now,
      updatedAt: now,
    );

    await docRef.set(attachment.toMap());
    return attachment;
  }

  Stream<List<Attachment>> streamByGuide({
    required String guideId,
    String? relatedActivityId,
    int? dayNumber,
    String? assignedTo,
    bool onlyMineIfViewer = true,
    bool? useServerFiltering,
  }) {
    final user = _auth.currentUser;
    if (user == null) {
      // Usuario no autenticado: retorna stream vacío
      return const Stream<List<Attachment>>.empty();
    }

    final serverFiltering =
        useServerFiltering ?? DebugConfig.enableServerSideAttachmentFilters;

    if (serverFiltering) {
      // Filtrado en servidor (requiere índices compuestos). En modo viewer
      // evitamos filtrar por assignedTo en servidor para preservar los
      // adjuntos creados por el usuario (OR no soportado en Firestore).
      Query<Map<String, dynamic>> q = _attachmentsCol(guideId);

      if (relatedActivityId != null) {
        q = q.where('relatedActivityId', isEqualTo: relatedActivityId);
      }
      if (dayNumber != null) {
        q = q.where('dayNumber', isEqualTo: dayNumber);
      }
      if (assignedTo != null && !onlyMineIfViewer) {
        q = q.where('assignedTo', isEqualTo: assignedTo);
      }

      q = q.orderBy('createdAt', descending: true);

      return q.snapshots().map((snap) {
        var list = snap.docs.map((d) => Attachment.fromMap(d.data())).toList();
        if (onlyMineIfViewer) {
          list = list
              .where(
                  (a) => a.assignedTo == user.uid || a.createdBy == user.uid)
              .toList();
        }
        return list;
      });
    }

    // Filtrado en cliente (no requiere índices compuestos)
    final q = _attachmentsCol(guideId).orderBy('createdAt', descending: true);

    return q.snapshots().map((snap) {
      var list = snap.docs.map((d) => Attachment.fromMap(d.data())).toList();

      if (relatedActivityId != null) {
        list = list
            .where((a) => a.relatedActivityId == relatedActivityId)
            .toList();
      }
      if (dayNumber != null) {
        list = list.where((a) => a.dayNumber == dayNumber).toList();
      }
      if (assignedTo != null) {
        list = list.where((a) => a.assignedTo == assignedTo).toList();
      }

      if (onlyMineIfViewer) {
        list = list
            .where((a) => a.assignedTo == user.uid || a.createdBy == user.uid)
            .toList();
      }
      return list;
    });
  }

  Future<void> deleteAttachment({
    required String guideId,
    required String attachmentId,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Usuario no autenticado');

    // Borrar Firestore
    await _attachmentsCol(guideId).doc(attachmentId).delete();

    // Borrar Storage (best-effort)
    try {
      final storageRef =
          _storage.ref().child('guides/$guideId/attachments/$attachmentId');
      final list = await storageRef.listAll();
      for (final item in list.items) {
        await item.delete();
      }
    } catch (_) {}
  }

  Future<void> updateAttachmentMetadata({
    required String guideId,
    required String attachmentId,
    String? title,
    String? notes,
    String? category,
    int? dayNumber,
    String? relatedActivityId,
    String? assignedTo,
  }) async {
    final updates = <String, dynamic>{};
    if (title != null) updates['title'] = title;
    if (notes != null) updates['notes'] = notes;
    if (category != null) updates['category'] = category;
    if (dayNumber != null) updates['dayNumber'] = dayNumber;
    if (relatedActivityId != null)
      updates['relatedActivityId'] = relatedActivityId;
    if (assignedTo != null) updates['assignedTo'] = assignedTo;
    updates['updatedAt'] = DateTime.now().toIso8601String();

    await _attachmentsCol(guideId).doc(attachmentId).update(updates);
  }
}
