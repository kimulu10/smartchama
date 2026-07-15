import 'package:flutter/material.dart';

enum AdvisorCategory {
  insight,
  loanRecommendation,
  savingsAdvice,
  investmentSuggestion,
  cashFlowForecast,
  riskAlert,
}

extension AdvisorCategoryExtension on AdvisorCategory {
  String get displayName {
    switch (this) {
      case AdvisorCategory.insight:
        return 'Insight';
      case AdvisorCategory.loanRecommendation:
        return 'Loan Recommendation';
      case AdvisorCategory.savingsAdvice:
        return 'Savings Advice';
      case AdvisorCategory.investmentSuggestion:
        return 'Investment Suggestion';
      case AdvisorCategory.cashFlowForecast:
        return 'Cash Flow Forecast';
      case AdvisorCategory.riskAlert:
        return 'Risk Alert';
    }
  }

  IconData get icon {
    switch (this) {
      case AdvisorCategory.insight:
        return Icons.lightbulb;
      case AdvisorCategory.loanRecommendation:
        return Icons.handshake;
      case AdvisorCategory.savingsAdvice:
        return Icons.savings;
      case AdvisorCategory.investmentSuggestion:
        return Icons.trending_up;
      case AdvisorCategory.cashFlowForecast:
        return Icons.show_chart;
      case AdvisorCategory.riskAlert:
        return Icons.warning_amber;
    }
  }
}

enum AdvisorSeverity { info, positive, warning, critical }

extension AdvisorSeverityExtension on AdvisorSeverity {
  String get displayName {
    switch (this) {
      case AdvisorSeverity.info:
        return 'Info';
      case AdvisorSeverity.positive:
        return 'Positive';
      case AdvisorSeverity.warning:
        return 'Warning';
      case AdvisorSeverity.critical:
        return 'Critical';
    }
  }
}

class AdvisorInsight {
  final String id;
  final String organizationId;
  final String? chamaId;
  final AdvisorCategory category;
  final AdvisorSeverity severity;
  final String title;
  final String detail;
  final double? score;
  final DateTime createdAt;

  AdvisorInsight({
    required this.id,
    required this.organizationId,
    this.chamaId,
    required this.category,
    required this.severity,
    required this.title,
    required this.detail,
    this.score,
    required this.createdAt,
  });

  factory AdvisorInsight.fromMap(Map<String, dynamic> map, String id) {
    return AdvisorInsight(
      id: id,
      organizationId: map['organizationId'] ?? '',
      chamaId: map['chamaId'],
      category: AdvisorCategory.values[map['category'] ?? 0],
      severity: AdvisorSeverity.values[map['severity'] ?? 0],
      title: map['title'] ?? '',
      detail: map['detail'] ?? '',
      score: map['score'] != null ? (map['score'] as num).toDouble() : null,
      createdAt: map['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'organizationId': organizationId,
      'chamaId': chamaId,
      'category': category.index,
      'severity': severity.index,
      'title': title,
      'detail': detail,
      'score': score,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }
}
