import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smartchama/models/document_model.dart';

class DocumentService {
  static final DocumentService _instance = DocumentService._internal();
  factory DocumentService() => _instance;
  DocumentService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  CollectionReference get _documents => _firestore.collection('documents');

  Future<String> uploadDocument({
    required String chamaId,
    required String name,
    String description = '',
    required String filePath,
    required DocumentType type,
    required String uploadedBy,
  }) async {
    final ref =
        _storage.ref().child('chama_documents').child(chamaId).child(name);
    await ref.putFile(File(filePath));
    final url = await ref.getDownloadURL();

    final doc = _documents.doc();
    await doc.set(ChamaDocument(
      id: doc.id,
      chamaId: chamaId,
      name: name,
      description: description,
      storagePath: ref.fullPath,
      url: url,
      type: type,
      uploadedBy: uploadedBy,
      uploadedAt: DateTime.now(),
    ).toMap());

    return doc.id;
  }

  Future<List<ChamaDocument>> getDocuments(String chamaId) async {
    final snapshot = await _documents
        .where('chamaId', isEqualTo: chamaId)
        .orderBy('uploadedAt', descending: true)
        .get();

    return snapshot.docs
        .map((doc) =>
            ChamaDocument.fromMap(doc.data() as Map<String, dynamic>, doc.id))
        .toList();
  }

  Future<List<ChamaDocument>> getDocumentsByType({
    required String chamaId,
    required DocumentType type,
  }) async {
    final snapshot = await _documents
        .where('chamaId', isEqualTo: chamaId)
        .where('type', isEqualTo: type.index)
        .orderBy('uploadedAt', descending: true)
        .get();

    return snapshot.docs
        .map((doc) =>
            ChamaDocument.fromMap(doc.data() as Map<String, dynamic>, doc.id))
        .toList();
  }

  Future<void> deleteDocument(String documentId) async {
    final doc = await _documents.doc(documentId).get();
    if (doc.exists) {
      final data = doc.data() as Map<String, dynamic>;
      if (data['storagePath'] != null) {
        await _storage.ref().child(data['storagePath']).delete();
      }
      await _documents.doc(documentId).delete();
    }
  }

  Future<String> getDownloadUrl(String documentId) async {
    final doc = await _documents.doc(documentId).get();
    if (doc.exists) {
      final data = doc.data() as Map<String, dynamic>;
      return data['url'] ?? '';
    }
    return '';
  }
}
