import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../chama/members_screen.dart';
import '../loans/loan_management_screen.dart';
import '../contributions/contribution_screen.dart';
import '../transactions/transaction_history_screen.dart';
import '../analytics/analytics_screen.dart';
import '../posts/admin_posts_screen.dart';
import '../posts/voting_screen.dart';
import '../meetings/meeting_scheduler.dart';
import '../communication/leader_private_chat_screen.dart';
import '../subscription/organization_offers_screen.dart';
import '../dashboard/unified_dashboard.dart';

class LeaderDashboard extends StatefulWidget {
  final String chamaId;
  final String organizationId;
  final String userId;
  final String role;

  const LeaderDashboard({
    super.key,
    required this.chamaId,
    required this.organizationId,
    required this.userId,
    required this.role,
  });

  @override
  State<LeaderDashboard> createState() => _LeaderDashboardState();
}

class _LeaderDashboardState extends State<LeaderDashboard> {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final FirebaseAuth auth = FirebaseAuth.instance;

  bool isLoading = true;
  String chamaName = "";
  String userName = "";
  Map<String, dynamic> stats = {};

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    final chamaDoc = await firestore
        .collection("organizations")
        .doc(widget.organizationId)
        .collection("chamas")
        .doc(widget.chamaId)
        .get();

    if (chamaDoc.exists && mounted) {
      setState(() => chamaName = chamaDoc.data()?["name"] ?? "Chama");
    }

    final userDoc = await firestore.collection("users").doc(widget.userId).get();
    if (userDoc.exists) {
      userName = userDoc.data()?["name"] ?? userDoc.data()?["email"] ?? "Leader";
    }

    final members = await firestore
        .collection("organizations")
        .doc(widget.organizationId)
        .collection("chamas")
        .doc(widget.chamaId)
        .collection("members")
        .get();

    final loans = await firestore
        .collection("organizations")
        .doc(widget.organizationId)
        .collection("chamas")
        .doc(widget.chamaId)
        .collection("loans")
        .get();

    int pendingLoans = 0;
    double totalLoans = 0;
    double totalRepaid = 0;

    for (var loan in loans.docs) {
      final amount = (loan["amount"] ?? 0).toDouble();
      final repaid = (loan["repaidAmount"] ?? 0).toDouble();
      final status = loan["status"] ?? "pending";

      totalLoans += amount;
      totalRepaid += repaid;
      if (status == "pending") pendingLoans++;
    }

    final contributions = await firestore
        .collection("organizations")
        .doc(widget.organizationId)
        .collection("chamas")
        .doc(widget.chamaId)
        .collection("contributions")
        .get();

    double totalContributions = 0;
    for (var c in contributions.docs) {
      totalContributions += (c["amount"] ?? 0).toDouble();
    }

    setState(() {
      isLoading = false;
      stats = {
        "members": members.docs.length,
        "totalContributions": totalContributions,
        "totalLoans": totalLoans,
        "totalRepaid": totalRepaid,
        "pendingLoans": pendingLoans,
        "activeLoans": loans.docs.where((l) => l["status"] == "approved").length,
      };
    });
  }

  Color _getRoleColor() {
    switch (widget.role) {
      case 'chairman': return Colors.purple;
      case 'secretary': return Colors.blue;
      case 'treasurer': return Colors.orange;
      case 'admin': return Colors.red;
      default: return Colors.green;
    }
  }

  IconData _getRoleIcon() {
    switch (widget.role) {
      case 'chairman': return Icons.emoji_events;
      case 'secretary': return Icons.edit_document;
      case 'treasurer': return Icons.account_balance;
      case 'admin': return Icons.admin_panel_settings;
      default: return Icons.person;
    }
  }

  String _getRoleTitle() {
    switch (widget.role) {
      case 'chairman': return "Chairman Dashboard";
      case 'secretary': return "Secretary Dashboard";
      case 'treasurer': return "Treasurer Dashboard";
      case 'admin': return "Admin Dashboard";
      default: return "Leader Dashboard";
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(_getRoleTitle())),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text("$chamaName - ${_getRoleTitle()}"),
        backgroundColor: _getRoleColor(),
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: loadData,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildRoleCard(),
              const SizedBox(height: 20),
              _buildStatsGrid(),
              const SizedBox(height: 20),
              _buildQuickActions(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleCard() {
    final responsibilities = _getResponsibilities();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_getRoleColor(), _getRoleColor().withOpacity(0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: Colors.white.withOpacity(0.2),
                child: Icon(_getRoleIcon(), color: Colors.white, size: 30),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Welcome, $userName",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Your responsibilities:",
                      style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: responsibilities.map((resp) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                resp,
                style: const TextStyle(color: Colors.white, fontSize: 11),
              ),
            )).toList(),
          ),
        ],
      ),
    );
  }

  List<String> _getResponsibilities() {
    switch (widget.role) {
      case 'chairman':
        return ['Manage chama', 'Approve loans', 'View analytics', 'Manage members', 'Oversee finances'];
      case 'secretary':
        return ['Create posts', 'Manage votes', 'Schedule meetings', 'Communicate with members'];
      case 'treasurer':
        return ['Manage contributions', 'Track loans', 'View analytics', 'Financial reports'];
      case 'admin':
        return ['Manage chama', 'Manage members', 'Approve loans', 'View analytics', 'Manage finances', 'Create posts', 'Schedule meetings'];
      default:
        return ['View dashboard', 'Make contributions', 'Request loans'];
    }
  }

  Widget _buildStatsGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Overview", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildStatCard("Members", stats["members"]?.toString() ?? "0", Icons.people, Colors.blue)),
            const SizedBox(width: 10),
            Expanded(child: _buildStatCard("Contributions", "KES ${((stats["totalContributions"] ?? 0) as double).toInt()}", Icons.savings, Colors.green)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _buildStatCard("Total Loans", "KES ${((stats["totalLoans"] ?? 0) as double).toInt()}", Icons.money, Colors.orange)),
            const SizedBox(width: 10),
            Expanded(child: _buildStatCard("Pending", stats["pendingLoans"]?.toString() ?? "0", Icons.pending, Colors.red)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _buildStatCard("Active Loans", stats["activeLoans"]?.toString() ?? "0", Icons.check_circle, Colors.purple)),
            const SizedBox(width: 10),
            Expanded(child: _buildStatCard("Repaid", "KES ${((stats["totalRepaid"] ?? 0) as double).toInt()}", Icons.done_all, Colors.teal)),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
          const SizedBox(height: 4),
          Text(title, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    List<Map<String, dynamic>> actions = [];

    actions.addAll([
      {"title": "View Members", "icon": Icons.people, "color": Colors.blue},
      {"title": "Loans", "icon": Icons.money, "color": Colors.orange},
      {"title": "Contributions", "icon": Icons.savings, "color": Colors.green},
      {"title": "Transactions", "icon": Icons.receipt, "color": Colors.purple},
    ]);

    if (widget.role == "treasurer" || widget.role == "admin") {
      actions.addAll([
        {"title": "Analytics", "icon": Icons.analytics, "color": Colors.teal},
      ]);
    }

    if (widget.role == "secretary" || widget.role == "admin") {
      actions.addAll([
        {"title": "Posts", "icon": Icons.article, "color": Colors.indigo},
        {"title": "Votes", "icon": Icons.how_to_vote, "color": Colors.pink},
        {"title": "Meetings", "icon": Icons.event, "color": Colors.cyan},
      ]);
    }

    if (widget.role == "chairman" || widget.role == "admin" || widget.role == "secretary" || widget.role == "treasurer") {
      actions.addAll([
        {"title": "Leader Chat", "icon": Icons.lock, "color": Colors.brown},
      ]);
    }

    if (widget.role == "admin") {
      actions.addAll([
        {"title": "Org Offers", "icon": Icons.local_offer, "color": Colors.deepOrange},
      ]);
    }

    actions.addAll([
      {"title": "Settings", "icon": Icons.settings, "color": Colors.grey},
    ]);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Quick Actions", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: actions.map((action) {
            return ElevatedButton(
              onPressed: () => _handleAction(action["title"]),
              style: ElevatedButton.styleFrom(
                backgroundColor: action["color"],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(action["icon"], size: 18),
                  const SizedBox(width: 8),
                  Text(action["title"]),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  void _handleAction(String title) {
    switch (title) {
      case "View Members":
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MembersScreen(
              organizationId: widget.organizationId,
              chamaId: widget.chamaId,
            ),
          ),
        );
        break;
      case "Loans":
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => LoanManagementScreen(
              chamaId: widget.chamaId,
              organizationId: widget.organizationId,
            ),
          ),
        );
        break;
      case "Contributions":
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ContributionScreen(
              chamaId: widget.chamaId,
              organizationId: widget.organizationId,
            ),
          ),
        );
        break;
      case "Transactions":
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TransactionHistoryScreen(
              chamaId: widget.chamaId,
              organizationId: widget.organizationId,
            ),
          ),
        );
        break;
      case "Analytics":
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AnalyticsScreen(
              chamaId: widget.chamaId,
              organizationId: widget.organizationId,
            ),
          ),
        );
        break;
      case "Posts":
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AdminPostsScreen(
              chamaId: widget.chamaId,
              organizationId: widget.organizationId,
            ),
          ),
        );
        break;
      case "Votes":
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => VotingScreen(
              chamaId: widget.chamaId,
              organizationId: widget.organizationId,
              isLeader: true,
              userId: widget.userId,
            ),
          ),
        );
        break;
      case "Meetings":
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MeetingScheduler(
              chamaId: widget.chamaId,
              organizationId: widget.organizationId,
              isLeader: true,
            ),
          ),
        );
        break;
      case "Leader Chat":
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => LeaderPrivateChatScreen(
              chamaId: widget.chamaId,
              organizationId: widget.organizationId,
              userId: widget.userId,
              userName: userName,
              role: widget.role,
            ),
          ),
        );
        break;
      case "Org Offers":
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OrganizationOffersScreen(
              organizationId: widget.organizationId,
              chamaId: widget.chamaId,
            ),
          ),
        );
        break;
      case "Settings":
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => UnifiedDashboard(
              userId: widget.userId,
              organizationId: widget.organizationId,
              chamaId: widget.chamaId,
            ),
          ),
        );
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Opening $title...")),
        );
    }
  }
}