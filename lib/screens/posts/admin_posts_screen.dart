import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class AdminPostsScreen extends StatefulWidget {
  final String chamaId;
  final String organizationId;
  final bool isAdmin;

  const AdminPostsScreen({
    super.key,
    required this.chamaId,
    required this.organizationId,
    this.isAdmin = false,
  });

  @override
  State<AdminPostsScreen> createState() => _AdminPostsScreenState();
}

class _AdminPostsScreenState extends State<AdminPostsScreen> {
  final postController = TextEditingController();
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final FirebaseAuth auth = FirebaseAuth.instance;
  String chamaName = "Posts";
  String? currentUserId;

  @override
  void initState() {
    super.initState();
    _loadChamaName();
    currentUserId = auth.currentUser?.uid;
  }

  Future<void> _loadChamaName() async {
    final chamaDoc = await FirebaseFirestore.instance
        .collection("organizations")
        .doc(widget.organizationId)
        .collection("chamas")
        .doc(widget.chamaId)
        .get();
    if (chamaDoc.exists && mounted) {
      setState(() {
        chamaName = chamaDoc.data()?["name"] ?? "Posts";
      });
    }
  }

  void createPost() async {
    final postsRef = FirebaseFirestore.instance
        .collection("organizations")
        .doc(widget.organizationId)
        .collection("chamas")
        .doc(widget.chamaId)
        .collection("posts");

    await postsRef.add({
      "message": postController.text,
      "authorId": currentUserId,
      "createdAt": FieldValue.serverTimestamp(),
    });

    postController.clear();
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Post created successfully")),
    );
  }

  Future<void> _replyToPost(String postId) async {
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
                  .collection("organizations")
                  .doc(widget.organizationId)
                  .collection("chamas")
                  .doc(widget.chamaId)
                  .collection("postReplies")
                  .add({
                "postId": postId,
                "authorId": currentUserId,
                "content": replyController.text.trim(),
                "createdAt": FieldValue.serverTimestamp(),
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

  String _formatTime(Timestamp? timestamp) {
    if (timestamp == null) return "";
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
        title: Text("$chamaName - Posts"),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
      ),

      body: Column(
        children: [
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
              children: [
                TextField(
                  controller: postController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: "Write an announcement...",
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
                    label: const Text("Post Announcement"),
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
            child: StreamBuilder(
              stream: firestore
                  .collection("organizations")
                  .doc(widget.organizationId)
                  .collection("chamas")
                  .doc(widget.chamaId)
                  .collection("posts")
                  .orderBy("createdAt", descending: true)
                  .snapshots(),
              builder: (context, snapshot) {

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final posts = snapshot.data!.docs;

                if (posts.isEmpty) {
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
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: posts.length,
                  itemBuilder: (context, index) {
                    final post = posts[index];
                    return _buildPostCard(post);
                  },
                );
              },
            ),
          )
        ],
      ),
    );
  }

  Widget _buildPostCard(QueryDocumentSnapshot post) {
    final data = post.data() as Map<String, dynamic>;
    final message = data["message"] ?? "";
    final authorId = data["authorId"];
    final createdAt = data["createdAt"] as Timestamp?;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Color(0xFF2E7D32),
                  radius: 20,
                  child: Icon(Icons.announcement, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Chama Announcement",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        _formatTime(createdAt),
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ),
                if (authorId == currentUserId)
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deletePost(post.id),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(message, style: const TextStyle(fontSize: 15)),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: TextButton.icon(
                onPressed: () => _replyToPost(post.id),
                icon: const Icon(Icons.reply, size: 18),
                label: const Text("Reply"),
              ),
            ),
            _buildReplies(post.id),
          ],
        ),
      ),
    );
  }

  Widget _buildReplies(String postId) {
    return StreamBuilder(
      stream: firestore
          .collection("organizations")
          .doc(widget.organizationId)
          .collection("chamas")
          .doc(widget.chamaId)
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
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.reply, size: 14, color: Color(0xFF2E7D32)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Reply",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(content),
                        const SizedBox(height: 4),
                        Text(
                          _formatTime(createdAt),
                          style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Future<void> _deletePost(String postId) async {
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
      await firestore
          .collection("organizations")
          .doc(widget.organizationId)
          .collection("chamas")
          .doc(widget.chamaId)
          .collection("posts")
          .doc(postId)
          .delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Post deleted")),
      );
    }
  }

  @override
  void dispose() {
    postController.dispose();
    super.dispose();
  }
}