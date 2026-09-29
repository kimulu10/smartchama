import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:smartchama/services/image_service.dart';

class ProfileScreen extends StatefulWidget {
  final String userId;
  final String organizationId;
  final String chamaId;

  const ProfileScreen({
    super.key,
    required this.userId,
    required this.organizationId,
    required this.chamaId,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirebaseAuth auth = FirebaseAuth.instance;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  bool isLoading = true;
  bool isSaving = false;
  
  String userName = "";
  String userEmail = "";
  String userRole = "";
  String? profileImageUrl;
  String? _localProfilePath;
  String chamaName = "";

  final nameController = TextEditingController();
  final phoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadProfile();
  }

  Future<void> loadProfile() async {
    try {
      final userDoc = await firestore.collection("users").doc(widget.userId).get();
      final data = userDoc.data() ?? {};
      
      setState(() {
        userName = data["name"] ?? "";
        userEmail = data["email"] ?? "";
        userRole = data["role"] ?? "member";
        profileImageUrl = data["profileImageUrl"];
        nameController.text = userName;
        phoneController.text = data["phone"] ?? "";
        isLoading = false;
      });

      final chamaDoc = await firestore
          .collection("organizations")
          .doc(widget.organizationId)
          .collection("chamas")
          .doc(widget.chamaId)
          .get();
      
      if (chamaDoc.exists && mounted) {
        setState(() {
          chamaName = chamaDoc.data()?["name"] ?? "Chama";
        });
      }
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  Future<void> pickImage() async {
    final XFile? pickedFile = await ImageService.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 80,
    );

    if (pickedFile == null || !mounted) return;

    // Show a local preview immediately before uploading so the user gets
    // instant visual feedback.
    setState(() {
      _localProfilePath = pickedFile.path;
      isSaving = true;
    });

    final downloadUrl = await ImageService.uploadImage(
      file: File(pickedFile.path),
      path: ImageUploadPath.profileImages,
      identifier: widget.userId,
      quality: 80,
      maxWidth: 800,
      maxHeight: 800,
    );

    if (!mounted) return;

    if (downloadUrl != null) {
      await firestore.collection("users").doc(widget.userId).set({
        "profileImageUrl": downloadUrl,
      }, SetOptions(merge: true));

      await firestore
          .collection("organizations")
          .doc(widget.organizationId)
          .collection("chamas")
          .doc(widget.chamaId)
          .collection("members")
          .doc(widget.userId)
          .set({
        "profileImageUrl": downloadUrl,
      }, SetOptions(merge: true));

      setState(() {
        profileImageUrl = downloadUrl;
        _localProfilePath = null;
        isSaving = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Profile picture updated!")),
        );
      }
    } else {
      setState(() => isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to upload profile picture.")),
        );
      }
    }
  }

  Future<void> saveProfile() async {
    if (nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Name cannot be empty")),
      );
      return;
    }

    setState(() => isSaving = true);

    try {
      await firestore.collection("users").doc(widget.userId).set({
        "name": nameController.text.trim(),
        "phone": phoneController.text.trim(),
      }, SetOptions(merge: true));

      // Also update in chama members
      await firestore
          .collection("organizations")
          .doc(widget.organizationId)
          .collection("chamas")
          .doc(widget.chamaId)
          .collection("members")
          .doc(widget.userId)
          .set({
        "name": nameController.text.trim(),
        "phone": phoneController.text.trim(),
      }, SetOptions(merge: true));

      setState(() {
        userName = nameController.text.trim();
        isSaving = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Profile updated!")),
        );
      }
    } catch (e) {
      setState(() => isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    }
  }

  Color _getRoleColor() {
    switch (userRole) {
      case 'admin':
        return Colors.red;
      case 'chairman':
        return Colors.purple;
      case 'treasurer':
        return Colors.orange;
      case 'secretary':
        return Colors.blue;
      default:
        return Colors.green;
    }
  }

  IconData _getRoleIcon() {
    switch (userRole) {
      case 'admin':
        return Icons.admin_panel_settings;
      case 'chairman':
        return Icons.emoji_events;
      case 'treasurer':
        return Icons.account_balance;
      case 'secretary':
        return Icons.edit_document;
      default:
        return Icons.person;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text("$chamaName - Profile"),
          backgroundColor: const Color(0xFF2E7D32),
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text("$chamaName - Profile"),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildProfileHeader(),
            const SizedBox(height: 24),
            _buildProfileForm(),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_getRoleColor(), _getRoleColor().withOpacity(0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _getRoleColor().withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Stack(
            children: [
              GestureDetector(
                onTap: pickImage,
                  child: CircleAvatar(
                   radius: 60,
                   backgroundColor: Colors.white,
                   backgroundImage: _localProfilePath != null
                       ? FileImage(File(_localProfilePath!)) as ImageProvider?
                       : profileImageUrl != null
                           ? NetworkImage(profileImageUrl!) as ImageProvider?
                           : null,
                  child: profileImageUrl == null
                      ? Icon(
                          Icons.person,
                          size: 60,
                          color: _getRoleColor(),
                        )
                      : null,
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 5,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.camera_alt,
                    size: 20,
                    color: _getRoleColor(),
                  ),
                ),
              ),
              if (isSaving)
                const Positioned.fill(
                  child: CircleAvatar(
                    backgroundColor: Colors.black54,
                    child: SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            userName,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            userEmail,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_getRoleIcon(), color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text(
                  userRole.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Tap the photo to change it",
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileForm() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.edit, color: Color(0xFF2E7D32)),
              SizedBox(width: 8),
              Text(
                "Edit Profile",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          TextField(
            controller: nameController,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: "Full Name",
              prefixIcon: const Icon(Icons.person_outline),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
            ),
          ),
          const SizedBox(height: 16),
          
          TextField(
            controller: phoneController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: "Phone Number",
              prefixIcon: const Icon(Icons.phone_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
              hintText: "e.g., 0712345678",
            ),
          ),
          const SizedBox(height: 16),
          
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.email_outlined, color: Colors.grey.shade600),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Email",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      Text(
                        userEmail,
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.lock_outline, color: Colors.grey.shade400, size: 18),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: isSaving ? null : saveProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      "Save Changes",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}