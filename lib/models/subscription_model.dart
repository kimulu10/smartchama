class SubscriptionPlan {
  final String id;
  final String name;
  final String description;
  final double priceMonthly;
  final double priceAnnual;
  final int maxMembers;
  final int maxChamas;
  final int storageMb;
  final List<String> features;
  final bool whiteLabelIncluded;
  final bool apiAccessIncluded;
  final bool prioritySupport;

  const SubscriptionPlan({
    required this.id,
    required this.name,
    required this.description,
    required this.priceMonthly,
    required this.priceAnnual,
    required this.maxMembers,
    required this.maxChamas,
    required this.storageMb,
    required this.features,
    this.whiteLabelIncluded = false,
    this.apiAccessIncluded = false,
    this.prioritySupport = false,
  });

  double priceForCycle(BillingCycle cycle) =>
      cycle == BillingCycle.monthly ? priceMonthly : priceAnnual;

  double get annualSavings => (priceMonthly * 12) - priceAnnual;

  static const List<SubscriptionPlan> defaults = [
    SubscriptionPlan(
      id: 'free',
      name: 'Free',
      description: 'Get started with the essentials for a small group.',
      priceMonthly: 0,
      priceAnnual: 0,
      maxMembers: 25,
      maxChamas: 1,
      storageMb: 100,
      features: [
        'Core contributions & loans',
        'Basic reporting',
        'M-Pesa integration',
        'Up to 25 members',
      ],
    ),
    SubscriptionPlan(
      id: 'starter',
      name: 'Starter',
      description: 'For growing groups that need more room and insights.',
      priceMonthly: 499,
      priceAnnual: 4990,
      maxMembers: 100,
      maxChamas: 5,
      storageMb: 1000,
      features: [
        'Everything in Free',
        'AI Financial Advisor',
        'Advanced analytics',
        'Investment tracking',
        'Up to 100 members',
      ],
    ),
    SubscriptionPlan(
      id: 'professional',
      name: 'Professional',
      description: 'Full automation, fraud detection and white-labeling.',
      priceMonthly: 1499,
      priceAnnual: 14990,
      maxMembers: 500,
      maxChamas: 25,
      storageMb: 5000,
      features: [
        'Everything in Starter',
        'AI Fraud Detection',
        'Predictive analytics',
        'White-label branding',
        'Communication center',
        'Up to 500 members',
      ],
      whiteLabelIncluded: true,
    ),
    SubscriptionPlan(
      id: 'enterprise',
      name: 'Enterprise',
      description: 'Unlimited scale with API access and priority support.',
      priceMonthly: 4999,
      priceAnnual: 49990,
      maxMembers: 100000,
      maxChamas: 1000,
      storageMb: 50000,
      features: [
        'Everything in Professional',
        'API & third-party integrations',
        'Multi-region & multi-currency',
        'Dedicated success manager',
        'Custom compliance rules',
      ],
      whiteLabelIncluded: true,
      apiAccessIncluded: true,
      prioritySupport: true,
    ),
  ];

  static SubscriptionPlan getById(String id) =>
      defaults.firstWhere((p) => p.id == id, orElse: () => defaults.first);
}

enum BillingCycle { monthly, annual }

extension BillingCycleExtension on BillingCycle {
  String get displayName => this == BillingCycle.monthly ? 'Monthly' : 'Annual';
}

enum SubscriptionStatus { active, trialing, pastDue, cancelled, expired }

extension SubscriptionStatusExtension on SubscriptionStatus {
  String get displayName {
    switch (this) {
      case SubscriptionStatus.active:
        return 'Active';
      case SubscriptionStatus.trialing:
        return 'Trialing';
      case SubscriptionStatus.pastDue:
        return 'Past Due';
      case SubscriptionStatus.cancelled:
        return 'Cancelled';
      case SubscriptionStatus.expired:
        return 'Expired';
    }
  }
}

class Subscription {
  final String id;
  final String organizationId;
  final String planId;
  final BillingCycle billingCycle;
  final SubscriptionStatus status;
  final DateTime startDate;
  final DateTime endDate;
  final bool autoRenew;
  final String? paymentMethodId;
  final DateTime createdAt;
  final DateTime? cancelledAt;

  Subscription({
    required this.id,
    required this.organizationId,
    required this.planId,
    this.billingCycle = BillingCycle.monthly,
    this.status = SubscriptionStatus.active,
    required this.startDate,
    required this.endDate,
    this.autoRenew = true,
    this.paymentMethodId,
    required this.createdAt,
    this.cancelledAt,
  });

  factory Subscription.fromMap(Map<String, dynamic> map, String id) {
    return Subscription(
      id: id,
      organizationId: map['organizationId'] ?? '',
      planId: map['planId'] ?? 'free',
      billingCycle: BillingCycle.values[map['billingCycle'] ?? 0],
      status: SubscriptionStatus.values[map['status'] ?? 0],
      startDate: map['startDate'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['startDate'])
          : DateTime.now(),
      endDate: map['endDate'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['endDate'])
          : DateTime.now().add(const Duration(days: 30)),
      autoRenew: map['autoRenew'] ?? true,
      paymentMethodId: map['paymentMethodId'],
      createdAt: map['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'])
          : DateTime.now(),
      cancelledAt: map['cancelledAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['cancelledAt'])
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'organizationId': organizationId,
      'planId': planId,
      'billingCycle': billingCycle.index,
      'status': status.index,
      'startDate': startDate.millisecondsSinceEpoch,
      'endDate': endDate.millisecondsSinceEpoch,
      'autoRenew': autoRenew,
      'paymentMethodId': paymentMethodId,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'cancelledAt': cancelledAt?.millisecondsSinceEpoch,
    };
  }

  bool get isActive => status == SubscriptionStatus.active || status == SubscriptionStatus.trialing;
  bool get willRenew => isActive && autoRenew;
  int get daysRemaining => endDate.difference(DateTime.now()).inDays;
}

enum InvoiceStatus { paid, pending, failed, refunded }

extension InvoiceStatusExtension on InvoiceStatus {
  String get displayName {
    switch (this) {
      case InvoiceStatus.paid:
        return 'Paid';
      case InvoiceStatus.pending:
        return 'Pending';
      case InvoiceStatus.failed:
        return 'Failed';
      case InvoiceStatus.refunded:
        return 'Refunded';
    }
  }
}

class Invoice {
  final String id;
  final String organizationId;
  final String subscriptionId;
  final double amount;
  final String currency;
  final InvoiceStatus status;
  final DateTime issuedAt;
  final DateTime dueAt;
  final DateTime? paidAt;
  final String? paymentMethod;

  Invoice({
    required this.id,
    required this.organizationId,
    required this.subscriptionId,
    required this.amount,
    this.currency = 'KES',
    this.status = InvoiceStatus.pending,
    required this.issuedAt,
    required this.dueAt,
    this.paidAt,
    this.paymentMethod,
  });

  factory Invoice.fromMap(Map<String, dynamic> map, String id) {
    return Invoice(
      id: id,
      organizationId: map['organizationId'] ?? '',
      subscriptionId: map['subscriptionId'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      currency: map['currency'] ?? 'KES',
      status: InvoiceStatus.values[map['status'] ?? 1],
      issuedAt: map['issuedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['issuedAt'])
          : DateTime.now(),
      dueAt: map['dueAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['dueAt'])
          : DateTime.now(),
      paidAt: map['paidAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['paidAt'])
          : null,
      paymentMethod: map['paymentMethod'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'organizationId': organizationId,
      'subscriptionId': subscriptionId,
      'amount': amount,
      'currency': currency,
      'status': status.index,
      'issuedAt': issuedAt.millisecondsSinceEpoch,
      'dueAt': dueAt.millisecondsSinceEpoch,
      'paidAt': paidAt?.millisecondsSinceEpoch,
      'paymentMethod': paymentMethod,
    };
  }
}
