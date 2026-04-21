import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MembersScreen extends StatefulWidget {
  final String organizationId;
  final String chamaId;
  final String? inviteCode;

  const MembersScreen({
    super.key,
    required this.organizationId,
    required this.chamaId,
    this.inviteCode,
  });

  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<MembersScreen> {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final FirebaseAuth auth = FirebaseAuth.instance;

  String? currentUserId;
  String? currentUserRole;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    final user = auth.currentUser;
    if (user != null) {
      final userDoc = await firestore
          .collection("organizations")
          .doc(widget.organizationId)
          .collection("chamas")
          .doc(widget.chamaId)
          .collection("members")
          .doc(user.uid)
          .get();

      setState(() {
        currentUserId = user.uid;
        currentUserRole = userDoc.data()?['role'];
      });
    }
  }

  Future<void> updateMemberRole(String memberId, String newRole) async {
    await firestore
        .collection("organizations")
        .doc(widget.organizationId)
        .collection("chamas")
        .doc(widget.chamaId)
        .collection("members")
        .doc(memberId)
        .update({"role": newRole});

    await firestore.collection("users").doc(memberId).update({
      "role": newRole,
      "position": newRole != "member" ? newRole : null,
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Member role updated to $newRole")),
    );
  }

  Future<void> removeMember(String memberId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Remove Member"),
        content: const Text("Are you sure you want to remove this member?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Remove"),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await firestore
          .collection("organizations")
          .doc(widget.organizationId)
          .collection("chamas")
          .doc(widget.chamaId)
          .collection("members")
          .doc(memberId)
          .delete();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Member removed")),
      );
    }
  }

  bool get isAdmin => currentUserRole == 'admin' || currentUserRole == 'treasurer';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chama Members'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        actions: [
          if (widget.inviteCode != null && widget.inviteCode!.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: () => _showInviteCode(widget.inviteCode!),
              tooltip: "Share Invite Code",
            ),
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.person_add),
              onPressed: () => _showAddMemberDialog(),
            ),
        ],
      ),
      body: _buildMembersList(),
    );
  }

  void _showInviteCode(String code) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Invite Code"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Share this code with new members:"),
            const SizedBox(height: 16),
            SelectableText(
              code,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 4,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Code copied!")),
              );
            },
            icon: const Icon(Icons.copy),
            label: const Text("Copy"),
          ),
        ],
      ),
    );
  }

  Widget _buildMembersList() {
    return StreamBuilder<QuerySnapshot>(
      stream: firestore
          .collection("organizations")
          .doc(widget.organizationId)
          .collection("chamas")
          .doc(widget.chamaId)
          .collection("members")
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState();
        }

        final members = snapshot.data!.docs;

        int adminCount = 0;
        int chairmanCount = 0;
        int secretaryCount = 0;
        int treasurerCount = 0;
        int memberCount = 0;

        for (var member in members) {
          final role = member['role'] ?? 'member';
          if (role == 'admin') adminCount++;
          if (role == 'chairman') chairmanCount++;
          if (role == 'secretary') secretaryCount++;
          if (role == 'treasurer') treasurerCount++;
          if (role == 'member') memberCount++;
        }

        return Column(
          children: [
            _buildMemberStats(chairmanCount, secretaryCount, treasurerCount, adminCount, memberCount),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: members.length,
                itemBuilder: (context, index) {
                  return _buildMemberCard(members[index]);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMemberStats(int chairmen, int secretaries, int treasurers, int admins, int members) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('Chairmen', chairmen, Icons.emoji_events),
          _buildStatItem('Secs', secretaries, Icons.edit_document),
          _buildStatItem('Treasurers', treasurers, Icons.account_balance),
          _buildStatItem('Admins', admins, Icons.admin_panel_settings),
          _buildStatItem('Members', members, Icons.people),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, int count, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 24),
        const SizedBox(height: 4),
        Text(
          count.toString(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildMemberCard(QueryDocumentSnapshot member) {
    final data = member.data() as Map<String, dynamic>;
    final memberId = member.id;
    final name = data['name'] ?? data['email'] ?? 'Unknown';
    final email = data['email'] ?? '';
    final role = data['role'] ?? 'member';
    final joinedAt = data['joinedAt'] as Timestamp?;
    final isCurrentUser = memberId == currentUserId;

    Color roleColor;
    IconData roleIcon;

    switch (role) {
      case 'chairman':
        roleColor = Colors.purple;
        roleIcon = Icons.emoji_events;
        break;
      case 'secretary':
        roleColor = Colors.blue;
        roleIcon = Icons.edit_document;
        break;
      case 'treasurer':
        roleColor = Colors.orange;
        roleIcon = Icons.account_balance;
        break;
      case 'admin':
        roleColor = Colors.red;
        roleIcon = Icons.admin_panel_settings;
        break;
      default:
        roleColor = Colors.green;
        roleIcon = Icons.person;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: isAdmin ? () => _showMemberOptions(memberId, name, role) : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFF2E7D32),
                radius: 24,
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : 'M',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        if (isCurrentUser) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'You',
                              style: TextStyle(
                                color: Colors.blue,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (email.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        email,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 13,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      joinedAt != null
                          ? 'Joined: ${_formatDate(joinedAt.toDate())}'
                          : 'Joined: Unknown',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: roleColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(roleIcon, size: 14, color: roleColor),
                    const SizedBox(width: 4),
                    Text(
                      role.toUpperCase(),
                      style: TextStyle(
                        color: roleColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMemberOptions(String memberId, String name, String currentRole) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Change Role',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                _buildRoleChip('chairman', 'Chairman', Icons.emoji_events, memberId),
                _buildRoleChip('secretary', 'Secretary', Icons.edit_document, memberId),
                _buildRoleChip('treasurer', 'Treasurer', Icons.account_balance, memberId),
                _buildRoleChip('admin', 'Admin', Icons.admin_panel_settings, memberId),
                _buildRoleChip('member', 'Member', Icons.person, memberId),
              ],
            ),
            const SizedBox(height: 20),
            if (currentRole != 'admin' || (currentUserRole == 'admin' || currentUserRole == 'chairman'))
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.delete, color: Colors.white),
                  label: const Text('Remove Member'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    removeMember(memberId);
                  },
                ),
              ),
            if (currentRole == 'admin' && currentUserRole == 'admin')
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.swap_horiz, color: Colors.white),
                  label: const Text('Transfer Ownership'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    _showTransferOwnership(memberId, name);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleChip(String role, String label, IconData icon, String memberId) {
    Color chipColor;
    switch (role) {
      case 'chairman':
        chipColor = Colors.purple;
        break;
      case 'secretary':
        chipColor = Colors.blue;
        break;
      case 'treasurer':
        chipColor = Colors.orange;
        break;
      case 'admin':
        chipColor = Colors.red;
        break;
      default:
        chipColor = Colors.green;
    }
    
    return ActionChip(
      avatar: Icon(icon, size: 18, color: chipColor),
      label: Text(label),
      backgroundColor: chipColor.withOpacity(0.1),
      onPressed: () {
        Navigator.pop(context);
        updateMemberRole(memberId, role);
      },
    );
  }

  Future<void> _showTransferOwnership(String memberId, String memberName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Transfer Ownership"),
        content: Text("Are you sure you want to transfer admin ownership to $memberName?\n\nYou will become a regular member after this transfer."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Transfer"),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final currentUser = auth.currentUser;
      if (currentUser == null) return;

      await firestore
          .collection("organizations")
          .doc(widget.organizationId)
          .collection("chamas")
          .doc(widget.chamaId)
          .collection("members")
          .doc(memberId)
          .update({"role": "admin"});

      await firestore
          .collection("organizations")
          .doc(widget.organizationId)
          .collection("chamas")
          .doc(widget.chamaId)
          .collection("members")
          .doc(currentUser.uid)
          .update({"role": "member"});

      await firestore.collection("users").doc(currentUser.uid).update({"role": "member"});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Ownership transferred to $memberName")),
      );
    }
  }

  void _showAddMemberDialog() {
    final emailController = TextEditingController();
    final nameController = TextEditingController();
    String selectedRole = 'member';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add Member'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: selectedRole,
                decoration: const InputDecoration(
                  labelText: 'Role',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'member', child: Text('Member')),
                  DropdownMenuItem(value: 'chairman', child: Text('Chairman')),
                  DropdownMenuItem(value: 'secretary', child: Text('Secretary')),
                  DropdownMenuItem(value: 'treasurer', child: Text('Treasurer')),
                  DropdownMenuItem(value: 'admin', child: Text('Admin')),
                ],
                onChanged: (value) {
                  setState(() => selectedRole = value!);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (emailController.text.isEmpty || nameController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please fill all fields')),
                  );
                  return;
                }

                await firestore
                    .collection("organizations")
                    .doc(widget.organizationId)
                    .collection("chamas")
                    .doc(widget.chamaId)
                    .collection("members")
                    .add({
                  'name': nameController.text.trim(),
                  'email': emailController.text.trim(),
                  'role': selectedRole,
                  'joinedAt': Timestamp.now(),
                  'status': 'active',
                });

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${nameController.text.trim()} added! They will receive a welcome notification.'),
                    backgroundColor: const Color(0xFF2E7D32),
                  ),
                );

                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Member added successfully')),
                );
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            'No members yet',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add members to get started',
            style: TextStyle(
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 24),
          if (isAdmin)
            ElevatedButton.icon(
              icon: const Icon(Icons.person_add),
              label: const Text('Add Member'),
              onPressed: _showAddMemberDialog,
            ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}