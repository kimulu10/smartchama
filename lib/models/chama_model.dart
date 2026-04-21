import 'package:cloud_firestore/cloud_firestore.dart';

class Chama {
  final String id;
  final String name;
  final String? description;
  final String? inviteCode;
  final String? createdBy;
  final DateTime? createdAt;
  final String? status;

  Chama({
    required this.id,
    required this.name,
    this.description,
    this.inviteCode,
    this.createdBy,
    this.createdAt,
    this.status,
  });

  factory Chama.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    return Chama(
      id: doc.id,
      name: data?['name'] ?? '',
      description: data?['description'],
      inviteCode: data?['inviteCode'],
      createdBy: data?['createdBy'],
      createdAt:
          data?['createdAt'] != null ? data!['createdAt'].toDate() : null,
      status: data?['status'],
    );
  }
}

class ChamaModel {
  final String id;
  final String name;
  final String organizationId;
  final String adminId;
  final double totalContributions;
  final double totalLoans;
  final DateTime createdAt;
  final String? description;
  final List<String> memberIds;
  final ChamaFeatures features;

  ChamaModel({
    required this.id,
    required this.name,
    required this.organizationId,
    required this.adminId,
    this.totalContributions = 0,
    this.totalLoans = 0,
    required this.createdAt,
    this.description,
    this.memberIds = const [],
    ChamaFeatures? features,
  }) : features = features ?? ChamaFeatures();

  factory ChamaModel.fromMap(Map<String, dynamic> map, String id) {
    ChamaFeatures? features;
    if (map['features'] != null) {
      features =
          ChamaFeatures.fromMap(Map<String, dynamic>.from(map['features']));
    }
    return ChamaModel(
      id: id,
      name: map['name'] ?? '',
      organizationId: map['organizationId'] ?? '',
      adminId: map['adminId'] ?? '',
      totalContributions: (map['totalContributions'] ?? 0).toDouble(),
      totalLoans: (map['totalLoans'] ?? 0).toDouble(),
      createdAt: map['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'])
          : DateTime.now(),
      description: map['description'],
      memberIds: List<String>.from(map['memberIds'] ?? []),
      features: features,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'organizationId': organizationId,
      'adminId': adminId,
      'totalContributions': totalContributions,
      'totalLoans': totalLoans,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'description': description,
      'memberIds': memberIds,
      'features': features.toMap(),
    };
  }

  ChamaModel copyWith({
    String? id,
    String? name,
    String? organizationId,
    String? adminId,
    double? totalContributions,
    double? totalLoans,
    DateTime? createdAt,
    String? description,
    List<String>? memberIds,
    ChamaFeatures? features,
  }) {
    return ChamaModel(
      id: id ?? this.id,
      name: name ?? this.name,
      organizationId: organizationId ?? this.organizationId,
      adminId: adminId ?? this.adminId,
      totalContributions: totalContributions ?? this.totalContributions,
      totalLoans: totalLoans ?? this.totalLoans,
      createdAt: createdAt ?? this.createdAt,
      description: description ?? this.description,
      memberIds: memberIds ?? this.memberIds,
      features: features ?? this.features,
    );
  }

  int get memberCount => memberIds.length;

  double get balance => totalContributions - totalLoans;
}

class ChamaFeatures {
  final bool loansEnabled;
  final bool investmentsEnabled;
  final bool dividendsEnabled;
  final bool documentsEnabled;
  final bool meetingsEnabled;
  final bool votingEnabled;
  final bool analyticsEnabled;
  final bool attendanceEnabled;

  ChamaFeatures({
    this.loansEnabled = true,
    this.investmentsEnabled = true,
    this.dividendsEnabled = true,
    this.documentsEnabled = true,
    this.meetingsEnabled = true,
    this.votingEnabled = true,
    this.analyticsEnabled = true,
    this.attendanceEnabled = true,
  });

  factory ChamaFeatures.fromMap(Map<String, dynamic> map) {
    return ChamaFeatures(
      loansEnabled: map['loansEnabled'] ?? true,
      investmentsEnabled: map['investmentsEnabled'] ?? true,
      dividendsEnabled: map['dividendsEnabled'] ?? true,
      documentsEnabled: map['documentsEnabled'] ?? true,
      meetingsEnabled: map['meetingsEnabled'] ?? true,
      votingEnabled: map['votingEnabled'] ?? true,
      analyticsEnabled: map['analyticsEnabled'] ?? true,
      attendanceEnabled: map['attendanceEnabled'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'loansEnabled': loansEnabled,
      'investmentsEnabled': investmentsEnabled,
      'dividendsEnabled': dividendsEnabled,
      'documentsEnabled': documentsEnabled,
      'meetingsEnabled': meetingsEnabled,
      'votingEnabled': votingEnabled,
      'analyticsEnabled': analyticsEnabled,
      'attendanceEnabled': attendanceEnabled,
    };
  }

  ChamaFeatures copyWith({
    bool? loansEnabled,
    bool? investmentsEnabled,
    bool? dividendsEnabled,
    bool? documentsEnabled,
    bool? meetingsEnabled,
    bool? votingEnabled,
    bool? analyticsEnabled,
    bool? attendanceEnabled,
  }) {
    return ChamaFeatures(
      loansEnabled: loansEnabled ?? this.loansEnabled,
      investmentsEnabled: investmentsEnabled ?? this.investmentsEnabled,
      dividendsEnabled: dividendsEnabled ?? this.dividendsEnabled,
      documentsEnabled: documentsEnabled ?? this.documentsEnabled,
      meetingsEnabled: meetingsEnabled ?? this.meetingsEnabled,
      votingEnabled: votingEnabled ?? this.votingEnabled,
      analyticsEnabled: analyticsEnabled ?? this.analyticsEnabled,
      attendanceEnabled: attendanceEnabled ?? this.attendanceEnabled,
    );
  }
}
