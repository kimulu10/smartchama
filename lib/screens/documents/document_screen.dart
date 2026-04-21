import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smartchama/models/document_model.dart';
import 'package:smartchama/services/document_service.dart';
import 'package:intl/intl.dart';

class DocumentScreen extends StatefulWidget {
  final String chamaId;
  final String organizationId;

  const DocumentScreen({
    super.key,
    required this.chamaId,
    required this.organizationId,
  });

  @override
  State<DocumentScreen> createState() => _DocumentScreenState();
}

class _DocumentScreenState extends State<DocumentScreen> {
  final _documentService = DocumentService();
  DocumentType? _filterType;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Documents'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton<DocumentType?>(
            icon: const Icon(Icons.filter_list),
            onSelected: (type) => setState(() => _filterType = type),
            itemBuilder: (context) => [
              const PopupMenuItem(value: null, child: Text('All')),
              ...DocumentType.values.map((t) => PopupMenuItem(
                    value: t,
                    child: Text(t.displayName),
                  )),
            ],
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('documents')
            .where('chamaId', isEqualTo: widget.chamaId)
            .orderBy('uploadedAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          var documents = snapshot.data!.docs
              .map((doc) => ChamaDocument.fromMap(doc.data() as Map<String, dynamic>, doc.id))
              .toList();

          if (_filterType != null) {
            documents = documents.where((d) => d.type == _filterType).toList();
          }

          if (documents.isEmpty) {
            return _buildEmptyState();
          }

          return RefreshIndicator(
            onRefresh: () async => setState(() {}),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: documents.length,
              itemBuilder: (context, index) =>
                  _buildDocumentCard(documents[index]),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showUploadDialog,
        backgroundColor: const Color(0xFF2E7D32),
        child: const Icon(Icons.upload_file),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_open, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No documents yet',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap upload to add first document',
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentCard(ChamaDocument document) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF2E7D32).withOpacity(0.1),
          child: Icon(_getDocumentIcon(document.type), color: const Color(0xFF2E7D32)),
        ),
        title: Text(document.name,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(document.type.displayName),
            Text(
              'Uploaded ${DateFormat.yMMMd().format(document.uploadedAt)}',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(document.formattedSize),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () => _confirmDelete(document),
            ),
          ],
        ),
        onTap: () => _openDocument(document),
      ),
    );
  }

  IconData _getDocumentIcon(DocumentType type) {
    switch (type) {
      case DocumentType.constitution:
        return Icons.gavel;
      case DocumentType.minutes:
        return Icons.notes;
      case DocumentType.financialStatement:
        return Icons.account_balance;
      case DocumentType.auditReport:
        return Icons.fact_check;
      case DocumentType.meetingNotice:
        return Icons.event;
      case DocumentType.memberList:
        return Icons.people;
      case DocumentType.loanAgreement:
        return Icons.description;
      case DocumentType.other:
        return Icons.folder;
    }
  }

  void _showUploadDialog() {
    final nameController = TextEditingController();
    DocumentType selectedType = DocumentType.other;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Upload Document'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Document Name'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<DocumentType>(
              value: selectedType,
              decoration: const InputDecoration(labelText: 'Type'),
              items: DocumentType.values
                  .map((t) => DropdownMenuItem(
                        value: t,
                        child: Text(t.displayName),
                      ))
                  .toList(),
              onChanged: (v) => selectedType = v!,
            ),
            const SizedBox(height: 12),
            const Text('Use file_picker package to select files'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // Would integrate with file_picker here
              Navigator.pop(context);
            },
            child: const Text('Select File'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(ChamaDocument document) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Document?'),
        content: Text('Are you sure you want to delete ${document.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await _documentService.deleteDocument(document.id);
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _openDocument(ChamaDocument document) async {
    final url = await _documentService.getDownloadUrl(document.id);
    if (url.isNotEmpty) {
      // Use url_launcher to open URL
    }
  }
}