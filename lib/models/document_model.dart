class ChamaDocument {
  final String id;
  final String chamaId;
  final String name;
  final String description;
  final String storagePath;
  final String url;
  final DocumentType type;
  final String uploadedBy;
  final DateTime uploadedAt;
  final int sizeBytes;

  ChamaDocument({
    required this.id,
    required this.chamaId,
    required this.name,
    this.description = '',
    required this.storagePath,
    this.url = '',
    required this.type,
    required this.uploadedBy,
    required this.uploadedAt,
    this.sizeBytes = 0,
  });

  factory ChamaDocument.fromMap(Map<String, dynamic> map, String id) {
    return ChamaDocument(
      id: id,
      chamaId: map['chamaId'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      storagePath: map['storagePath'] ?? '',
      url: map['url'] ?? '',
      type: DocumentType.values[map['type'] ?? 0],
      uploadedBy: map['uploadedBy'] ?? '',
      uploadedAt: map['uploadedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['uploadedAt'])
          : DateTime.now(),
      sizeBytes: map['sizeBytes'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'chamaId': chamaId,
      'name': name,
      'description': description,
      'storagePath': storagePath,
      'url': url,
      'type': type.index,
      'uploadedBy': uploadedBy,
      'uploadedAt': uploadedAt.millisecondsSinceEpoch,
      'sizeBytes': sizeBytes,
    };
  }

  String get formattedSize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

enum DocumentType {
  constitution,
  minutes,
  financialStatement,
  auditReport,
  meetingNotice,
  memberList,
  loanAgreement,
  other,
}

extension DocumentTypeExtension on DocumentType {
  String get displayName {
    switch (this) {
      case DocumentType.constitution:
        return 'Constitution';
      case DocumentType.minutes:
        return 'Meeting Minutes';
      case DocumentType.financialStatement:
        return 'Financial Statement';
      case DocumentType.auditReport:
        return 'Audit Report';
      case DocumentType.meetingNotice:
        return 'Meeting Notice';
      case DocumentType.memberList:
        return 'Member List';
      case DocumentType.loanAgreement:
        return 'Loan Agreement';
      case DocumentType.other:
        return 'Other';
    }
  }

  String get icon {
    switch (this) {
      case DocumentType.constitution:
        return 'gavel';
      case DocumentType.minutes:
        return 'notes';
      case DocumentType.financialStatement:
        return 'account_balance';
      case DocumentType.auditReport:
        return 'fact_check';
      case DocumentType.meetingNotice:
        return 'event';
      case DocumentType.memberList:
        return 'people';
      case DocumentType.loanAgreement:
        return 'description';
      case DocumentType.other:
        return 'folder';
    }
  }
}