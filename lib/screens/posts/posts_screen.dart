import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PostsScreen extends StatefulWidget {
  final String chamaId;
  final String organizationId;
  final bool isLeader;
  final String userId;

  const PostsScreen({
    super.key,
    required this.chamaId,
    required this.organizationId,
    required this.isLeader,
    required this.userId,
  });

  @override
  State<PostsScreen> createState() => _PostsScreenState();
}

class _PostsScreenState extends State<PostsScreen> {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final FirebaseAuth auth = FirebaseAuth.instance;
  final postController = TextEditingController();
  
  String chamaName = "Posts";
  String currentUserName = "";

  @override
  void initState() {
    super.initState();
    _loadChamaName();
    _loadUserName();
  }

  Future<void> _loadChamaName() async {
    final chamaDoc = await firestore
        .collection("organizations")
        .doc(widget.organizationId)
        .collection("chamas")
        .doc(widget.chamaId)
        .get();
    if (chamaDoc.exists && mounted) {
      setState(() => chamaName = chamaDoc.data()?["name"] ?? "Posts");
    }
  }

  Future<void> _loadUserName() async {
    final userDoc = await firestore.collection("users").doc(widget.userId).get();
    if (userDoc.exists && mounted) {
      setState(() => currentUserName = userDoc.data()?["name"] ?? "Member");
    }
  }

  Future<void> createPost() async {
    if (postController.text.trim().isEmpty) return;

    await firestore
        .collection("organizations")
        .doc(widget.organizationId)
        .collection("chamas")
        .doc(widget.chamaId)
        .collection("posts")
        .add({
      "message": postController.text.trim(),
      "createdBy": widget.userId,
      "createdByName": currentUserName,
      "createdAt": FieldValue.serverTimestamp(),
      "isAnnouncement": widget.isLeader,
    });

    postController.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Post created!")),
    );
  }

  Future<void> addReply(String postId, String postAuthorName) async {
    final replyController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Reply to $postAuthorName"),
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
                  .collection("posts")
                  .doc(postId)
                  .collection("replies")
                  .add({
                "message": replyController.text.trim(),
                "repliedBy": widget.userId,
                "repliedByName": currentUserName,
                "createdAt": FieldValue.serverTimestamp(),
              });
              
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Reply added!")),
              );
            },
            child: const Text("Reply"),
          ),
        ],
      ),
    );
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
          // Create Post Section
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey.shade50,
            child: Column(
              children: [
                TextField(
                  controller: postController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: widget.isLeader 
                        ? "Write an announcement or post..." 
                        : "Share something with the chama...",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: createPost,
                    icon: const Icon(Icons.send, size: 18),
                    label: Text(widget.isLeader ? "Post Announcement" : "Post"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          
          // Posts List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
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
                        Icon(Icons.article_outlined, size: 60, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text("No posts yet", style: TextStyle(color: Colors.grey[600])),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: posts.length,
                  itemBuilder: (context, index) {
                    final post = posts[index];
                    final isAnnouncement = post["isAnnouncement"] ?? false;
                    final authorName = post["createdByName"] ?? "Unknown";
                    final createdAt = (post["createdAt"] as Timestamp?)?.toDate();

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: isAnnouncement 
                            ? const BorderSide(color: Color(0xFF2E7D32), width: 2) 
                            : BorderSide.none,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: isAnnouncement 
                                      ? const Color(0xFF2E7D32) 
                                      : Colors.grey.shade300,
                                  child: Icon(
                                    isAnnouncement ? Icons.campaign : Icons.person,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            authorName,
                                            style: const TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                          if (isAnnouncement) ...[
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF2E7D32),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: const Text(
                                                "OFFICIAL",
                                                style: TextStyle(color: Colors.white, fontSize: 10),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      Text(
                                        _formatDate(createdAt),
                                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              post["message"] ?? "",
                              style: const TextStyle(fontSize: 15),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                TextButton.icon(
                                  onPressed: () => addReply(post.id, authorName),
                                  icon: const Icon(Icons.reply, size: 18),
                                  label: const Text("Reply"),
                                ),
                                const Spacer(),
                                TextButton(
                                  onPressed: () => _showReplies(post.id, authorName),
                                  child: const Text("View Replies"),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showReplies(String postId, String authorName) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text("Replies to $authorName", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: firestore
                    .collection("organizations")
                    .doc(widget.organizationId)
                    .collection("chamas")
                    .doc(widget.chamaId)
                    .collection("posts")
                    .doc(postId)
                    .collection("replies")
                    .orderBy("createdAt")
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final replies = snapshot.data!.docs;
                  
                  if (replies.isEmpty) {
                    return Center(
                      child: Text("No replies yet", style: TextStyle(color: Colors.grey[500])),
                    );
                  }

                  return ListView.builder(
                    controller: scrollController,
                    itemCount: replies.length,
                    itemBuilder: (context, index) {
                      final reply = replies[index];
                      return ListTile(
                        leading: CircleAvatar(
                          radius: 16,
                          backgroundColor: Colors.grey.shade200,
                          child: Text(
                            (reply["repliedByName"] ?? "M")[0].toUpperCase(),
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        title: Text(reply["repliedByName"] ?? "Member"),
                        subtitle: Text(reply["message"] ?? ""),
                        trailing: Text(
                          _formatDate((reply["createdAt"] as Timestamp?)?.toDate()),
                          style: TextStyle(fontSize: 10, color: Colors.grey[400]),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return "";
    final now = DateTime.now();
    final diff = now.difference(date);
    
    if (diff.inMinutes < 1) return "Just now";
    if (diff.inMinutes < 60) return "${diff.inMinutes}m ago";
    if (diff.inHours < 24) return "${diff.inHours}h ago";
    if (diff.inDays < 7) return "${diff.inDays}d ago";
    return "${date.day}/${date.month}/${date.year}";
  }
}