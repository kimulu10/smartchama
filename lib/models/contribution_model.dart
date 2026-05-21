class Contribution {
  final String id;
  final String chamaId;
  final String? organizationId;
  final String memberId;
  final String? memberName;
  final double amount;
  final String? description;
  final String? mpesaCode;
  final String status;
  final DateTime createdAt;

  Contribution({
    required this.id,
    required this.chamaId,
    this.organizationId,
    required this.memberId,
    this.memberName,
    required this.amount,
    this.description,
    this.mpesaCode,
    this.status = 'completed',
    required this.createdAt,
  });

  factory Contribution.fromMap(Map<String, dynamic> map, String id) {
    return Contribution(
      id: id,
      chamaId: map['chamaId'] ?? '',
      organizationId: map['organizationId'] as String?,
      memberId: map['memberId'] ?? map['userId'] ?? '',
      memberName: map['memberName'] as String?,
      amount: (map['amount'] ?? 0).toDouble(),
      description: map['description'] as String?,
      mpesaCode: map['mpesaCode'] as String?,
      status: map['status'] ?? 'completed',
      createdAt: map['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              map['createdAt'] is int
                  ? map['createdAt']
                  : (map['createdAt'] as dynamic).millisecondsSinceEpoch,
            )
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'chamaId': chamaId,
      if (organizationId != null) 'organizationId': organizationId,
      'memberId': memberId,
      if (memberName != null) 'memberName': memberName,
      'amount': amount,
      if (description != null) 'description': description,
      if (mpesaCode != null) 'mpesaCode': mpesaCode,
      'status': status,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }
}
