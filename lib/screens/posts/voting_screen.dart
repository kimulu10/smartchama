import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class VotingScreen extends StatefulWidget {
  final String chamaId;
  final String organizationId;
  final bool isLeader;
  final String userId;

  const VotingScreen({
    super.key,
    required this.chamaId,
    required this.organizationId,
    required this.isLeader,
    required this.userId,
  });

  @override
  State<VotingScreen> createState() => _VotingScreenState();
}

class _VotingScreenState extends State<VotingScreen> with SingleTickerProviderStateMixin {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final FirebaseAuth auth = FirebaseAuth.instance;
  
  String? currentUserId;
  String chamaName = "Voting";
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    final user = auth.currentUser;
    currentUserId = user?.uid;
    _loadChamaName();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadChamaName() async {
    final chamaDoc = await firestore
        .collection("organizations")
        .doc(widget.organizationId)
        .collection("chamas")
        .doc(widget.chamaId)
        .get();
    if (chamaDoc.exists && mounted) {
      setState(() => chamaName = chamaDoc.data()?["name"] ?? "Voting");
    }
  }

  Future<void> createRoleVote() async {
    final titleController = TextEditingController();
    String selectedRole = "chairman";
    List<Map<String, String>> candidates = [];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text("Create Role Election"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Select Role:", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: selectedRole,
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: "chairman", child: Text("Chairman")),
                    DropdownMenuItem(value: "secretary", child: Text("Secretary")),
                    DropdownMenuItem(value: "treasurer", child: Text("Treasurer")),
                  ],
                  onChanged: (value) => setStateDialog(() => selectedRole = value!),
                ),
                const SizedBox(height: 16),
                const Text("Description:", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextField(
                  controller: titleController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    hintText: "e.g., Election for new Chairman",
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.trim().isEmpty) return;
                
                await firestore
                    .collection("organizations")
                    .doc(widget.organizationId)
                    .collection("chamas")
                    .doc(widget.chamaId)
                    .collection("votes")
                    .add({
                  "title": titleController.text.trim(),
                  "role": selectedRole,
                  "type": "role_election",
                  "createdBy": currentUserId,
                  "createdAt": Timestamp.now(),
                  "yesVotes": 0,
                  "noVotes": 0,
                  "voters": [],
                  "status": "active",
                  "candidates": [],
                });
                
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Role election created!")),
                );
              },
              child: const Text("Create"),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> createPoll() async {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Create Poll"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: "Poll Title",
                  hintText: "e.g., Monthly Contribution Amount",
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: "Description",
                  hintText: "Describe what members are voting for",
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              if (titleController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Please enter a title")),
                );
                return;
              }

              await firestore
                  .collection("organizations")
                  .doc(widget.organizationId)
                  .collection("chamas")
                  .doc(widget.chamaId)
                  .collection("votes")
                  .add({
                "title": titleController.text.trim(),
                "description": descriptionController.text.trim(),
                "type": "poll",
                "createdBy": currentUserId,
                "createdAt": Timestamp.now(),
                "yesVotes": 0,
                "noVotes": 0,
                "voters": [],
                "status": "active",
              });

              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Poll created successfully")),
              );
            },
            child: const Text("Create"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("$chamaName - Votes"),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: "Role Elections"),
            Tab(text: "Polls"),
          ],
        ),
        actions: [
          if (widget.isLeader)
            PopupMenuButton<String>(
              icon: const Icon(Icons.add),
              onSelected: (value) {
                if (value == "role") {
                  createRoleVote();
                } else if (value == "poll") createPoll();
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: "role",
                  child: Row(
                    children: [
                      Icon(Icons.how_to_vote, color: Color(0xFF2E7D32)),
                      SizedBox(width: 8),
                      Text("Role Election"),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: "poll",
                  child: Row(
                    children: [
                      Icon(Icons.poll, color: Color(0xFF2E7D32)),
                      SizedBox(width: 8),
                      Text("Create Poll"),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildVotesList("role_election"),
          _buildVotesList("poll"),
        ],
      ),
    );
  }

  Widget _buildVotesList(String type) {
    return StreamBuilder<QuerySnapshot>(
      stream: firestore
          .collection("organizations")
          .doc(widget.organizationId)
          .collection("chamas")
          .doc(widget.chamaId)
          .collection("votes")
          .where("type", isEqualTo: type)
          .orderBy("createdAt", descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState(type);
        }

        final votes = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: votes.length,
          itemBuilder: (context, index) => _buildVoteCard(votes[index]),
        );
      },
    );
  }

  Widget _buildEmptyState(String type) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            type == "role_election" ? Icons.how_to_vote : Icons.poll,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            type == "role_election" ? "No role elections" : "No polls yet",
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            widget.isLeader
                ? type == "role_election" 
                    ? "Create a role election for members to vote"
                    : "Create a poll to get members' input"
                : "Check back later for elections",
            style: TextStyle(color: Colors.grey[500]),
          ),
          if (widget.isLeader) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: Text(type == "role_election" ? "Create Election" : "Create Poll"),
              onPressed: type == "role_election" ? createRoleVote : createPoll,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVoteCard(QueryDocumentSnapshot voteDoc) {
    final data = voteDoc.data() as Map<String, dynamic>;
    final title = data["title"] ?? "";
    final description = data["description"] ?? "";
    final role = data["role"] ?? "";
    final yesVotes = data["yesVotes"] ?? 0;
    final noVotes = data["noVotes"] ?? 0;
    final voters = List<String>.from(data["voters"] ?? []);
    final status = data["status"] ?? "active";

    final hasVoted = currentUserId != null && voters.contains(currentUserId);
    final totalVotes = (yesVotes as int) + (noVotes as int);
    final double yesPercent = totalVotes > 0 ? ((yesVotes) / totalVotes * 100) : 0.0;

    Color cardColor;
    IconData cardIcon;
    
    if (data["type"] == "role_election") {
      switch (role) {
        case "chairman":
          cardColor = Colors.purple;
          cardIcon = Icons.emoji_events;
          break;
        case "secretary":
          cardColor = Colors.blue;
          cardIcon = Icons.edit_document;
          break;
        case "treasurer":
          cardColor = Colors.orange;
          cardIcon = Icons.account_balance;
          break;
        default:
          cardColor = Colors.green;
          cardIcon = Icons.how_to_vote;
      }
    } else {
      cardColor = const Color(0xFF2E7D32);
      cardIcon = Icons.poll;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cardColor.withOpacity(0.3), width: 2),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: cardColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(cardIcon, color: cardColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        if (data["type"] == "role_election")
                          Text(
                            "Role: ${role.substring(0, 1).toUpperCase()}${role.substring(1)}",
                            style: TextStyle(color: cardColor, fontWeight: FontWeight.w500),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: status == "active" ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: TextStyle(
                        color: status == "active" ? Colors.green : Colors.grey,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              if (description.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(description, style: TextStyle(color: Colors.grey[700])),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  _buildVoteResult("Yes", yesVotes, yesPercent, Colors.green),
                  const SizedBox(width: 20),
                  _buildVoteResult("No", noVotes, (100.0 - yesPercent).toDouble(), Colors.red),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                "Total votes: $totalVotes",
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
              if (status == "active" && !hasVoted) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => castVote(voteDoc.id, true),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                        child: const Text("Vote Yes"),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => castVote(voteDoc.id, false),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                        child: const Text("Vote No"),
                      ),
                    ),
                  ],
                ),
              ] else if (hasVoted) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E7D32).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle, color: Color(0xFF2E7D32), size: 20),
                      SizedBox(width: 8),
                      Text("You have voted", style: TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
              if (widget.isLeader && status == "active") ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: () => closeVote(voteDoc.id),
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text("Close Vote"),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: () => deleteVote(voteDoc.id),
                      icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                      label: const Text("Delete", style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVoteResult(String label, int count, double percent, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: color)),
              Text("$count (${percent.toStringAsFixed(1)}%)", style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percent / 100,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> castVote(String voteId, bool yes) async {
    final voteDoc = await firestore
        .collection("organizations")
        .doc(widget.organizationId)
        .collection("chamas")
        .doc(widget.chamaId)
        .collection("votes")
        .doc(voteId)
        .get();
    
    final data = voteDoc.data() ?? {};
    final voters = List<String>.from(data["voters"] ?? []);

    if (voters.contains(currentUserId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You have already voted")),
      );
      return;
    }

    voters.add(currentUserId!);

    await firestore
        .collection("organizations")
        .doc(widget.organizationId)
        .collection("chamas")
        .doc(widget.chamaId)
        .collection("votes")
        .doc(voteId)
        .update({
      "voters": voters,
      "yesVotes": yes ? (data["yesVotes"] ?? 0) + 1 : data["yesVotes"],
      "noVotes": !yes ? (data["noVotes"] ?? 0) + 1 : data["noVotes"],
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(yes ? "Voted Yes!" : "Voted No!")),
    );
  }

  Future<void> closeVote(String voteId) async {
    await firestore
        .collection("organizations")
        .doc(widget.organizationId)
        .collection("chamas")
        .doc(widget.chamaId)
        .collection("votes")
        .doc(voteId)
        .update({"status": "closed"});
    
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Vote closed")));
  }

  Future<void> deleteVote(String voteId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Vote"),
        content: const Text("Are you sure you want to delete this vote?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await firestore
          .collection("organizations")
          .doc(widget.organizationId)
          .collection("chamas")
          .doc(widget.chamaId)
          .collection("votes")
          .doc(voteId)
          .delete();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Vote deleted")));
    }
  }
}