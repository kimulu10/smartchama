class UserModel {
  final String uid;
  final String email;
  final String role;
  final String organizationId;
  final String? position;
  final List<String> responsibilities;

  UserModel({
    required this.uid,
    required this.email,
    required this.role,
    required this.organizationId,
    this.position,
    this.responsibilities = const [],
  });

  static List<String> getResponsibilities(String role) {
    switch (role) {
      case 'chairman':
        return ['Manage chama', 'Approve loans', 'View analytics', 'Manage members', 'Oversee finances'];
      case 'secretary':
        return ['Create posts', 'Manage votes', 'Schedule meetings', 'Communicate with members'];
      case 'treasurer':
        return ['Manage contributions', 'Track loans', 'View analytics', 'Financial reports'];
      case 'admin':
        return ['Manage chama', 'Manage members', 'Approve loans', 'View analytics', 'Manage finances', 'Create posts', 'Schedule meetings'];
      default:
        return ['Contribute', 'Request loans', 'Vote', 'Participate in discussions'];
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'role': role,
      'organizationId': organizationId,
      'position': position,
      'responsibilities': responsibilities.isNotEmpty ? responsibilities : getResponsibilities(role),
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'],
      email: map['email'],
      role: map['role'] ?? 'member',
      organizationId: map['organizationId'] ?? '',
      position: map['position'],
      responsibilities: List<String>.from(map['responsibilities'] ?? getResponsibilities(map['role'] ?? 'member')),
    );
  }
}