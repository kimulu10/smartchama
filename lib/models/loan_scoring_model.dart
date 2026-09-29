import 'package:flutter/material.dart';

class LoanScore {
  final String id;
  final String loanId;
  final String chamaId;
  final String userId;
  final int score;
  final String riskLevel;
  final String recommendation;
  final Map<String, dynamic> factors;
  final double memberContributionHistory;
  final double memberLoanHistory;
  final double repaymentRate;
  final int chamaMembershipDuration;
  final DateTime calculatedAt;
  final String? calculatedBy;

  LoanScore({
    required this.id,
    required this.loanId,
    required this.chamaId,
    required this.userId,
    required this.score,
    required this.riskLevel,
    required this.recommendation,
    required this.factors,
    required this.memberContributionHistory,
    required this.memberLoanHistory,
    required this.repaymentRate,
    required this.chamaMembershipDuration,
    required this.calculatedAt,
    this.calculatedBy,
  });

  factory LoanScore.fromMap(Map<String, dynamic> map, String id) {
    return LoanScore(
      id: id,
      loanId: map['loanId'] ?? '',
      chamaId: map['chamaId'] ?? '',
      userId: map['userId'] ?? '',
      score: map['score'] ?? 0,
      riskLevel: map['riskLevel'] ?? 'medium',
      recommendation: map['recommendation'] ?? 'review',
      factors: Map<String, dynamic>.from(map['factors'] ?? {}),
      memberContributionHistory: (map['memberContributionHistory'] ?? 0).toDouble(),
      memberLoanHistory: (map['memberLoanHistory'] ?? 0).toDouble(),
      repaymentRate: (map['repaymentRate'] ?? 0).toDouble(),
      chamaMembershipDuration: map['chamaMembershipDuration'] ?? 0,
      calculatedAt: map['calculatedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['calculatedAt'])
          : DateTime.now(),
      calculatedBy: map['calculatedBy'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'loanId': loanId,
      'chamaId': chamaId,
      'userId': userId,
      'score': score,
      'riskLevel': riskLevel,
      'recommendation': recommendation,
      'factors': factors,
      'memberContributionHistory': memberContributionHistory,
      'memberLoanHistory': memberLoanHistory,
      'repaymentRate': repaymentRate,
      'chamaMembershipDuration': chamaMembershipDuration,
      'calculatedAt': calculatedAt.millisecondsSinceEpoch,
      if (calculatedBy != null) 'calculatedBy': calculatedBy,
    };
  }

  LoanScore copyWith({
    String? id,
    String? loanId,
    String? chamaId,
    String? userId,
    int? score,
    String? riskLevel,
    String? recommendation,
    Map<String, dynamic>? factors,
    double? memberContributionHistory,
    double? memberLoanHistory,
    double? repaymentRate,
    int? chamaMembershipDuration,
    DateTime? calculatedAt,
    String? calculatedBy,
  }) {
    return LoanScore(
      id: id ?? this.id,
      loanId: loanId ?? this.loanId,
      chamaId: chamaId ?? this.chamaId,
      userId: userId ?? this.userId,
      score: score ?? this.score,
      riskLevel: riskLevel ?? this.riskLevel,
      recommendation: recommendation ?? this.recommendation,
      factors: factors ?? this.factors,
      memberContributionHistory: memberContributionHistory ?? this.memberContributionHistory,
      memberLoanHistory: memberLoanHistory ?? this.memberLoanHistory,
      repaymentRate: repaymentRate ?? this.repaymentRate,
      chamaMembershipDuration: chamaMembershipDuration ?? this.chamaMembershipDuration,
      calculatedAt: calculatedAt ?? this.calculatedAt,
      calculatedBy: calculatedBy ?? this.calculatedBy,
    );
  }
}

class ScoringFactor {
  final String name;
  final double weight;
  final int score;
  final String description;

  ScoringFactor({
    required this.name,
    required this.weight,
    required this.score,
    required this.description,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'weight': weight,
      'score': score,
      'description': description,
    };
  }

  factory ScoringFactor.fromMap(Map<String, dynamic> map) {
    return ScoringFactor(
      name: map['name'] ?? '',
      weight: (map['weight'] ?? 0).toDouble(),
      score: map['score'] ?? 0,
      description: map['description'] ?? '',
    );
  }
}

enum RiskLevel { low, medium, high }

extension RiskLevelExtension on RiskLevel {
  String get displayName {
    switch (this) {
      case RiskLevel.low:
        return 'Low';
      case RiskLevel.medium:
        return 'Medium';
      case RiskLevel.high:
        return 'High';
    }
  }

  Color get color {
    switch (this) {
      case RiskLevel.low:
        return Colors.green;
      case RiskLevel.medium:
        return Colors.orange;
      case RiskLevel.high:
        return Colors.red;
    }
  }
}
