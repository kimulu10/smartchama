import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class MemberPostsScreen extends StatefulWidget {
  final String chamaId;
  final bool isAdmin;

  const MemberPostsScreen({
    super.key,
    required this.chamaId,
    this.isAdmin = false,
  });

  @override
  State<MemberPostsScreen> createState() => _MemberPostsScreenState();
}

class _MemberPostsScreenState extends State<MemberPostsScreen> {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final FirebaseAuth auth = FirebaseAuth.instance;
  final TextEditingController _postController = TextEditingController();

  String? currentUserId;
  String? currentUserRole;

  @override
  void initState() {
    super.initState();
    final user = auth.currentUser;
    currentUserId = user?.uid;
    _loadUserRole();
  }

  Future<void> _loadUserRole() async {
    if (currentUserId != null) {
      final userDoc = await firestore
          .collection("members")
          .doc(currentUserId)
          .get();
      setState(() {
        currentUserRole = userDoc.data()?["role"];
      });
    }
  }

  bool get isLeader => widget.isAdmin || 
      currentUserRole == "chairman" || 
      currentUserRole == "secretary" || 
      currentUserRole == "treasurer";

  Future<void> createPost() async {
    if (_postController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please write something")),
      );
      return;
    }

    await firestore.collection("posts").add({
      "chamaId": widget.chamaId,
      "authorId": currentUserId,
      "content": _postController.text.trim(),
      "createdAt": Timestamp.now(),
      "isAnnouncement": isLeader,
    });

    _postController.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Post shared successfully")),
    );
  }

  Future<void> _replyToPost(String postId, String authorId) async {
    final replyController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Reply to Post"),
        content: TextField(
          controller: replyController,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: "Write your reply...",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              if (replyController.text.trim().isEmpty) return;

              await firestore
                  .collection("postReplies")
                  .add({
                    "postId": postId,
                    "authorId": currentUserId,
                    "content": replyController.text.trim(),
                    "createdAt": Timestamp.now(),
                  });

              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Reply posted")),
              );
            },
            child: const Text("Reply"),
          ),
        ],
      ),
    );
  }

  Future<void> deletePost(String postId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Post"),
        content: const Text("Are you sure you want to delete this post?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await firestore.collection("posts").doc(postId).delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Post deleted")),
      );
    }
  }

  String _formatTime(Timestamp timestamp) {
    final date = timestamp.toDate();
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays > 7) {
      return DateFormat('MMM d, y').format(date);
    } else if (diff.inDays > 0) {
      return '${diff.inDays}d ago';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}h ago';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Chama Posts"),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          if (isLeader)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const CircleAvatar(
                        backgroundColor: Color(0xFF2E7D32),
                        radius: 16,
                        child: Icon(Icons.person, color: Colors.white, size: 18),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "Share an announcement or note",
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _postController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: "Write your message to members...",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: createPost,
                      icon: const Icon(Icons.send, size: 18),
                      label: const Text("Post"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E7D32),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: firestore
                  .collection("posts")
                  .where("chamaId", isEqualTo: widget.chamaId)
                  .orderBy("createdAt", descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildEmptyState();
                }

                final posts = snapshot.data!.docs;
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: posts.length,
                  itemBuilder: (context, index) {
                    return _buildPostCard(posts[index]);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.article_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            "No posts yet",
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            "Share updates with your chama members",
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildPostCard(QueryDocumentSnapshot postDoc) {
    final data = postDoc.data() as Map<String, dynamic>;
    final content = data["content"] ?? "";
    final authorId = data["authorId"];
    final isAnnouncement = data["isAnnouncement"] ?? false;
    final createdAt = data["createdAt"] as Timestamp?;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              isAnnouncement ? const Color(0xFF2E7D32).withOpacity(0.05) : Colors.grey.shade50,
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: isAnnouncement 
                        ? const Color(0xFF2E7D32) 
                        : Colors.grey,
                    radius: 20,
                    child: Icon(
                      isAnnouncement ? Icons.announcement : Icons.person,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              isAnnouncement ? "Chama Announcement" : "Member Post",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (isAnnouncement) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2E7D32).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  "Official",
                                  style: TextStyle(
                                    color: Color(0xFF2E7D32),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        Text(
                          createdAt != null ? _formatTime(createdAt) : "",
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (authorId == currentUserId || widget.isAdmin)
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == "delete") {
                          deletePost(postDoc.id);
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: "delete",
                          child: Row(
                            children: [
                              Icon(Icons.delete, color: Colors.red, size: 18),
                              SizedBox(width: 8),
                              Text("Delete", style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                content,
                style: const TextStyle(fontSize: 15),
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Colors.grey.shade200),
                  ),
                ),
                child: TextButton.icon(
                  onPressed: () => _replyToPost(postDoc.id, authorId),
                  icon: const Icon(Icons.reply, size: 18),
                  label: const Text("Reply"),
                ),
              ),
              _buildReplies(postDoc.id),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReplies(String postId) {
    return StreamBuilder<QuerySnapshot>(
      stream: firestore
          .collection("postReplies")
          .where("postId", isEqualTo: postId)
          .orderBy("createdAt")
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final replies = snapshot.data!.docs;

        return Column(
          children: replies.map((reply) {
            final data = reply.data() as Map<String, dynamic>;
            final content = data["content"] ?? "";
            final createdAt = data["createdAt"] as Timestamp?;

            return Container(
              margin: const EdgeInsets.only(top: 8, left: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.reply, size: 14, color: Color(0xFF2E7D32)),
                      const SizedBox(width: 4),
                      Text(
                        "Member Reply",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      ),
                      const Spacer(),
                      Text(
                        createdAt != null ? _formatTime(createdAt) : "",
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(content),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  @override
  void dispose() {
    _postController.dispose();
    super.dispose();
  }
}