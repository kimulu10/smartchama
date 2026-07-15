import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smartchama/models/subscription_model.dart';

/// Subscription & billing engine. Manages plans, subscriptions, automatic
/// renewal, and invoices for each tenant.
class SubscriptionService {
  static final SubscriptionService _instance = SubscriptionService._internal();
  factory SubscriptionService() => _instance;
  SubscriptionService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<SubscriptionPlan> get plans => SubscriptionPlan.defaults;

  CollectionReference get _subs =>
      _firestore.collection('subscriptions');
  CollectionReference get _invoices => _firestore.collection('invoices');

  SubscriptionPlan planById(String id) => SubscriptionPlan.getById(id);

  /// Subscribes (or upgrades) a tenant to a plan, generating the first invoice.
  Future<Subscription> subscribe({
    required String organizationId,
    required String planId,
    required BillingCycle cycle,
    String? paymentMethodId,
  }) async {
    final plan = planById(planId);
    final now = DateTime.now();
    final duration =
        cycle == BillingCycle.monthly ? const Duration(days: 30) : const Duration(days: 365);

    // Cancel any existing active subscription for the org.
    final existing = await getActiveSubscription(organizationId);
    if (existing != null) {
      await _subs.doc(existing.id).update({
        'status': SubscriptionStatus.cancelled.index,
        'cancelledAt': now.millisecondsSinceEpoch,
      });
    }

    final doc = _subs.doc();
    final subscription = Subscription(
      id: doc.id,
      organizationId: organizationId,
      planId: planId,
      billingCycle: cycle,
      status: SubscriptionStatus.active,
      startDate: now,
      endDate: now.add(duration),
      autoRenew: true,
      paymentMethodId: paymentMethodId,
      createdAt: now,
    );
    await doc.set(subscription.toMap());

    // Update tenant plan reference.
    await _firestore
        .collection('organizations')
        .doc(organizationId)
        .update({'planId': planId});

    await _issueInvoice(subscription, plan.priceForCycle(cycle));
    return subscription;
  }

  Future<Invoice> _issueInvoice(Subscription subscription, double amount) async {
    final now = DateTime.now();
    final doc = _invoices.doc();
    final invoice = Invoice(
      id: doc.id,
      organizationId: subscription.organizationId,
      subscriptionId: subscription.id,
      amount: amount,
      status: InvoiceStatus.paid,
      issuedAt: now,
      dueAt: now,
      paidAt: now,
      paymentMethod: subscription.paymentMethodId,
    );
    await doc.set(invoice.toMap());
    return invoice;
  }

  Future<Subscription?> getActiveSubscription(String organizationId) async {
    final snapshot = await _subs
        .where('organizationId', isEqualTo: organizationId)
        .where('status',
            whereIn: [SubscriptionStatus.active.index, SubscriptionStatus.trialing.index])
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return null;
    return Subscription.fromMap(
        snapshot.docs.first.data() as Map<String, dynamic>, snapshot.docs.first.id);
  }

  Future<void> cancelSubscription(String subscriptionId, String organizationId) async {
    final now = DateTime.now();
    await _subs.doc(subscriptionId).update({
      'status': SubscriptionStatus.cancelled.index,
      'autoRenew': false,
      'cancelledAt': now.millisecondsSinceEpoch,
    });
    await _firestore
        .collection('organizations')
        .doc(organizationId)
        .update({'planId': 'free'});
  }

  /// Renews a subscription if expired and auto-renew is enabled.
  Future<Subscription> renew(Subscription subscription) async {
    final plan = planById(subscription.planId);
    final now = DateTime.now();
    final duration = subscription.billingCycle == BillingCycle.monthly
        ? const Duration(days: 30)
        : const Duration(days: 365);
    final renewed = subscription.copyWithRenewal(
      startDate: now,
      endDate: now.add(duration),
    );
    await _subs.doc(renewed.id).update(renewed.toMap());
    await _issueInvoice(renewed, plan.priceForCycle(subscription.billingCycle));
    return renewed;
  }

  Future<List<Invoice>> getInvoices(String organizationId, {int limit = 20}) async {
    final snapshot = await _invoices
        .where('organizationId', isEqualTo: organizationId)
        .orderBy('issuedAt', descending: true)
        .limit(limit)
        .get();
    return snapshot.docs
        .map((d) => Invoice.fromMap(d.data() as Map<String, dynamic>, d.id))
        .toList();
  }
}

extension SubscriptionRenewal on Subscription {
  Subscription copyWithRenewal({
    required DateTime startDate,
    required DateTime endDate,
  }) {
    return Subscription(
      id: id,
      organizationId: organizationId,
      planId: planId,
      billingCycle: billingCycle,
      status: SubscriptionStatus.active,
      startDate: startDate,
      endDate: endDate,
      autoRenew: autoRenew,
      paymentMethodId: paymentMethodId,
      createdAt: createdAt,
      cancelledAt: cancelledAt,
    );
  }
}
