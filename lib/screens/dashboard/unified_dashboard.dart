import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:smartchama/models/chama_model.dart';

// SCREENS
import '../loans/loan_request_screen.dart';
import '../loans/loan_management_screen.dart';
import '../loans/member_loan_screen.dart';
import '../analytics/analytics_screen.dart';
import '../chama/members_screen.dart';
import '../transactions/transaction_history_screen.dart';
import '../contributions/add_contribution_screen.dart';
import '../contributions/contribution_history_screen.dart';
import '../contributions/monthly_tracker_screen.dart';
import '../meetings/meeting_scheduler.dart';
import '../posts/posts_screen.dart';
import '../posts/voting_screen.dart';
import '../admin/admin_dashboard_screen.dart';
import '../profile/profile_screen.dart';
import '../leaders/leader_dashboard.dart';
import 'package:smartchama/services/security_service.dart';

class UnifiedDashboard extends StatefulWidget {
  final String userId;

  const UnifiedDashboard({super.key, required this.userId});

  @override
  State<UnifiedDashboard> createState() => _UnifiedDashboardState();
}

class _UnifiedDashboardState extends State<UnifiedDashboard> {
  final FirebaseAuth auth = FirebaseAuth.instance;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  bool isLoading = true;
  bool hasChama = true;
  bool isApproved = true;

  String chamaId = "";
  String organizationId = "";
  String chamaName = "";
  String chamaDescription = "";
  String chamaLogoUrl = "";
  String welcomeMessage = "";
  String inviteCode = "";
  String userRole = "member";
  String userName = "";

  List<Map<String, dynamic>> members = [];

  ChamaFeatures features = ChamaFeatures();

  int membersCount = 0;
  double totalContributions = 0;
  double userBalance = 0;
  int totalLoans = 0;
  int activeLoans = 0;
  int repaidLoans = 0;
  int pendingTransactions = 0;
  int failedTransactions = 0;

  bool get isAdmin => userRole == "admin" || userRole == "chairman";
  bool get isTreasurer => userRole == "treasurer";
  bool get isSecretary => userRole == "secretary";
  bool get isLeader => isAdmin || isTreasurer || isSecretary;
  bool get isMember => userRole == "member";

  @override
  void initState() {
    super.initState();
    loadDashboard();
  }

  Future<void> loadDashboard() async {
    try {
      final userDoc = await firestore.collection("users").doc(widget.userId).get();

      if (!userDoc.exists || userDoc.data()?["chamaId"] == null) {
        setState(() {
          hasChama = false;
          isLoading = false;
        });
        return;
      }

      chamaId = userDoc["chamaId"];
      organizationId = userDoc["organizationId"] ?? "";
      
      // If no organizationId, user can't access dashboard
      if (organizationId.isEmpty) {
        setState(() {
          hasChama = false;
          isLoading = false;
        });
        return;
      }
      
      userRole = userDoc.data()?["role"] ?? "member";
      userName = userDoc.data()?["name"] ?? userDoc.data()?["email"] ?? "Member";
      isApproved = userDoc.data()?["status"] != "pending";

      final chamaDoc = await firestore
          .collection("organizations")
          .doc(organizationId)
          .collection("chamas")
          .doc(chamaId)
          .get();

      chamaName = chamaDoc.data()?["name"] ?? "SmartChama";
      chamaDescription = chamaDoc.data()?["description"] ?? "";
      chamaLogoUrl = chamaDoc.data()?["logoUrl"] ?? "";
      welcomeMessage = chamaDoc.data()?["welcomeMessage"] ?? "Welcome to $chamaName!";
      inviteCode = chamaDoc.data()?["inviteCode"] ?? "";
      
      final chamaData = chamaDoc.data();
      if (chamaData != null && chamaData["features"] != null) {
        features = ChamaFeatures.fromMap(Map<String, dynamic>.from(chamaData["features"]));
      }

      final memberDocs = await firestore
          .collection("organizations")
          .doc(organizationId)
          .collection("chamas")
          .doc(chamaId)
          .collection("members")
          .get();

      members = memberDocs.docs
          .map((d) => {
                "id": d.id,
                "email": d["email"] ?? "",
                "name": d["name"] ?? "",
                "role": d["role"] ?? "member",
              })
          .toList();

      membersCount = members.length;

      final transactions = await firestore
          .collection("transactions")
          .where("chamaId", isEqualTo: chamaId)
          .get();

      totalContributions = 0;
      userBalance = 0;
      totalLoans = 0;
      activeLoans = 0;
      repaidLoans = 0;
      pendingTransactions = 0;
      failedTransactions = 0;

      for (var doc in transactions.docs) {
        final type = (doc["type"] ?? "").toString();
        final status = (doc["status"] ?? "").toString();
        double amount = (doc["amount"] ?? 0).toDouble();

        if (status == "pending") pendingTransactions++;
        if (status == "failed") failedTransactions++;

        if (type == "contribution" && status == "success") {
          totalContributions += amount;
          if (doc["userId"] == widget.userId) {
            userBalance += amount;
          }
        }

        if (type == "loan_request") {
          totalLoans++;
          if (status == "approved") activeLoans++;
        }

        if (type == "loan_repayment" && status == "success") {
          repaidLoans++;
        }
      }

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      print("ERROR: $e");
      setState(() => isLoading = false);
    }
  }

  Future<void> logout() async {
    await SecureStorageService.clearAll();
    await auth.signOut();
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/auth', (_) => false);
    }
  }

  Future<void> shareInvite() async {
    final message = "Join our Chama '$chamaName' using code: $inviteCode";
    final url = Uri.parse("https://wa.me/?text=${Uri.encodeComponent(message)}");
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  void goToContribution() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddContributionScreen(
          organizationId: organizationId,
          chamaId: chamaId,
        ),
      ),
    );
  }

  void goToContributionHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ContributionHistoryScreen(
          organizationId: organizationId,
          chamaId: chamaId,
        ),
      ),
    );
  }

  void goToMonthlyTracker() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MonthlyTrackerScreen(
          organizationId: organizationId,
          chamaId: chamaId,
        ),
      ),
    );
  }

  void goToLoans() {
    if (isMember) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MemberLoanScreen(
            organizationId: organizationId,
            chamaId: chamaId,
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LoanManagementScreen(
            chamaId: chamaId,
            organizationId: organizationId,
          ),
        ),
      );
    }
  }

  void goToRequestLoan() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LoanRequestScreen(
          chamaId: chamaId,
          organizationId: organizationId,
        ),
      ),
    );
  }

  void goToAnalytics() {
    if (isLeader) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AnalyticsScreen(
            chamaId: chamaId,
            organizationId: organizationId,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Analytics only available for leaders")),
      );
    }
  }

  void goToMembers() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MembersScreen(
          organizationId: organizationId,
          chamaId: chamaId,
          inviteCode: inviteCode,
        ),
      ),
    );
  }

  void goToTransactions() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TransactionHistoryScreen(
          chamaId: chamaId,
          organizationId: organizationId,
          memberId: isMember ? widget.userId : null,
        ),
      ),
    );
  }

  void goToMeetings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MeetingScheduler(
          chamaId: chamaId,
          organizationId: organizationId,
        ),
      ),
    );
  }

  void goToAdminPosts() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PostsScreen(
          chamaId: chamaId,
          organizationId: organizationId,
          isLeader: isLeader,
          userId: widget.userId,
        ),
      ),
    );
  }

  void goToVoting() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VotingScreen(
          chamaId: chamaId,
          organizationId: organizationId,
          isLeader: isLeader,
          userId: widget.userId,
        ),
      ),
    );
  }

  void goToAdminDashboard() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminDashboardScreen(
          chamaId: chamaId,
          organizationId: organizationId,
        ),
      ),
    );
  }

  void goToProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProfileScreen(
          userId: widget.userId,
          organizationId: organizationId,
          chamaId: chamaId,
        ),
      ),
    );
  }

  void goToLeaderDashboard() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LeaderDashboard(
          chamaId: chamaId,
          organizationId: organizationId,
          userId: widget.userId,
          role: userRole,
        ),
      ),
    );
  }

  Color getRoleColor() {
    switch (userRole) {
      case 'chairman':
        return Colors.purple;
      case 'secretary':
        return Colors.blue;
      case 'treasurer':
        return Colors.orange;
      case 'admin':
        return Colors.red;
      default:
        return Colors.green;
    }
  }

  IconData getRoleIcon() {
    switch (userRole) {
      case 'chairman':
        return Icons.emoji_events;
      case 'secretary':
        return Icons.edit_document;
      case 'treasurer':
        return Icons.account_balance;
      case 'admin':
        return Icons.admin_panel_settings;
      default:
        return Icons.person;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!hasChama) {
      return Scaffold(
        appBar: AppBar(title: const Text("SmartChama Dashboard")),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("You are not part of any Chama yet!"),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/createChama');
                },
                child: const Text("Create Chama"),
              ),
              const SizedBox(height: 5),
              ElevatedButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/joinChama');
                },
                child: const Text("Join Chama"),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(chamaName),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: goToProfile,
            tooltip: "My Profile",
          ),
          if (isLeader)
            IconButton(
              icon: const Icon(Icons.admin_panel_settings),
              onPressed: goToAdminDashboard,
              tooltip: "Admin Panel",
            ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: logout,
            tooltip: "Logout",
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: loadDashboard,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildWelcomeCard(),
              const SizedBox(height: 20),
              _buildQuickActions(),
              const SizedBox(height: 20),
              _buildSummaryCards(),
              if (isLeader) ...[
                const SizedBox(height: 20),
                _buildLeaderSection(),
              ],
              if (isMember) ...[
                const SizedBox(height: 20),
                _buildMemberSection(),
              ],
              const SizedBox(height: 20),
              _buildInviteSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              getRoleColor(),
              getRoleColor().withOpacity(0.7),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.white.withOpacity(0.3),
              radius: 30,
              backgroundImage: chamaLogoUrl.isNotEmpty ? NetworkImage(chamaLogoUrl) : null,
              child: chamaLogoUrl.isEmpty 
                  ? Icon(getRoleIcon(), color: Colors.white, size: 30)
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    chamaName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (chamaDescription.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      chamaDescription,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 12,
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        userName,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          userRole.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Quick Actions",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _actionBtn("Add Money", Icons.add, goToContribution),
            _actionBtn("Contributions", Icons.history, goToContributionHistory),
            if (features.loansEnabled && isLeader) _actionBtn("Loans", Icons.money, goToLoans),
            if (features.loansEnabled && isMember) _actionBtn("My Loans", Icons.money, goToLoans),
            if (features.analyticsEnabled && isLeader) _actionBtn("Analytics", Icons.bar_chart, goToAnalytics),
            _actionBtn("Transactions", Icons.receipt_long, goToTransactions),
            _actionBtn("Members", Icons.people, goToMembers),
            if (features.votingEnabled) _actionBtn("Votes", Icons.how_to_vote, goToVoting),
            if (features.meetingsEnabled && isLeader) _actionBtn("Meetings", Icons.event, goToMeetings),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryCards() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _card(
                "Total Chama",
                "KES ${totalContributions.toInt()}",
                Icons.account_balance_wallet,
                const Color(0xFF2E7D32),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _card(
                "My Contributions",
                "KES ${userBalance.toInt()}",
                Icons.savings,
                Colors.blue,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _card("Members", membersCount.toString(), Icons.people, Colors.purple),
            ),
            if (features.loansEnabled) ...[
              const SizedBox(width: 10),
              Expanded(
                child: _card("Loans", totalLoans.toString(), Icons.money, Colors.orange),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildLeaderSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Leadership Tools",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        
        // Role-specific dashboard button
        Card(
          color: getRoleColor().withOpacity(0.1),
          child: ListTile(
            leading: Icon(getRoleIcon(), color: getRoleColor()),
            title: Text("${userRole.substring(0,1).toUpperCase()}${userRole.substring(1)} Dashboard"),
            subtitle: const Text("View your role-specific dashboard"),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: goToLeaderDashboard,
          ),
        ),
        if (features.loansEnabled) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _miniCard("Active Loans", activeLoans.toString())),
              Expanded(child: _miniCard("Repaid Loans", repaidLoans.toString())),
            ],
          ),
        ],
        Row(
          children: [
            Expanded(child: _miniCard("Pending", pendingTransactions.toString())),
            Expanded(child: _miniCard("Failed", failedTransactions.toString())),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.group_add, color: Color(0xFF2E7D32)),
            title: const Text("Invite Members"),
            subtitle: Text("Code: $inviteCode"),
            trailing: IconButton(
              icon: const Icon(Icons.copy),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: inviteCode));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Code copied!")),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMemberSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.info_outline, color: Color(0xFF2E7D32)),
                SizedBox(width: 8),
                Text(
                  "Member Access",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              "• You can view your own transactions and loans",
              style: TextStyle(color: Colors.grey[600]),
            ),
            Text(
              "• You can contribute and request loans",
              style: TextStyle(color: Colors.grey[600]),
            ),
            Text(
              "• You can participate in votes and reply to posts",
              style: TextStyle(color: Colors.grey[600]),
            ),
            Text(
              "• Contact your leader for full access",
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInviteSection() {
    if (!isLeader) return const SizedBox.shrink();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Row(
              children: [
                Icon(Icons.share, color: Color(0xFF2E7D32)),
                SizedBox(width: 8),
                Text(
                  "Invite New Members",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF2E7D32).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Invitation Code",
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(height: 4),
                        SelectableText(
                          inviteCode,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, color: Color(0xFF2E7D32)),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: inviteCode));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Code copied!")),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.share, color: Color(0xFF2E7D32)),
                    onPressed: shareInvite,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 8),
          Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color),
          ),
        ],
      ),
    );
  }

  Widget _miniCard(String title, String value) {
    return Container(
      margin: const EdgeInsets.all(5),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF2E7D32).withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 11)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _actionBtn(String title, IconData icon, VoidCallback onTap) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(title, style: const TextStyle(fontSize: 12)),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }
}