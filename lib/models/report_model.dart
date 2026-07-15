class FinancialReport {
  final String id;
  final String chamaId;
  final String organizationId;
  final String generatedBy;
  final String reportType;
  final String title;
  final String description;
  final DateTime periodStart;
  final DateTime periodEnd;
  final Map<String, dynamic> data;
  final DateTime generatedAt;
  final String? fileUrl;

  FinancialReport({
    required this.id,
    required this.chamaId,
    required this.organizationId,
    required this.generatedBy,
    required this.reportType,
    required this.title,
    required this.description,
    required this.periodStart,
    required this.periodEnd,
    required this.data,
    required this.generatedAt,
    this.fileUrl,
  });

  factory FinancialReport.fromMap(Map<String, dynamic> map, String id) {
    return FinancialReport(
      id: id,
      chamaId: map['chamaId'] ?? '',
      organizationId: map['organizationId'] ?? '',
      generatedBy: map['generatedBy'] ?? '',
      reportType: map['reportType'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      periodStart: map['periodStart'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['periodStart'])
          : DateTime.now(),
      periodEnd: map['periodEnd'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['periodEnd'])
          : DateTime.now(),
      data: Map<String, dynamic>.from(map['data'] ?? {}),
      generatedAt: map['generatedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['generatedAt'])
          : DateTime.now(),
      fileUrl: map['fileUrl'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'chamaId': chamaId,
      'organizationId': organizationId,
      'generatedBy': generatedBy,
      'reportType': reportType,
      'title': title,
      'description': description,
      'periodStart': periodStart.millisecondsSinceEpoch,
      'periodEnd': periodEnd.millisecondsSinceEpoch,
      'data': data,
      'generatedAt': generatedAt.millisecondsSinceEpoch,
      if (fileUrl != null) 'fileUrl': fileUrl,
    };
  }
}

class ReportTemplate {
  final String id;
  final String name;
  final String reportType;
  final String description;
  final bool isDefault;
  final List<String> sections;

  ReportTemplate({
    required this.id,
    required this.name,
    required this.reportType,
    required this.description,
    required this.isDefault,
    required this.sections,
  });

  factory ReportTemplate.fromMap(Map<String, dynamic> map) {
    return ReportTemplate(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      reportType: map['reportType'] ?? '',
      description: map['description'] ?? '',
      isDefault: map['isDefault'] ?? false,
      sections: List<String>.from(map['sections'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'reportType': reportType,
      'description': description,
      'isDefault': isDefault,
      'sections': sections,
    };
  }
}
