import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smartchama/screens/create_chama_screen.dart';
import 'package:smartchama/services/security_service.dart';
import '../dashboard/unified_dashboard.dart';

final _authRateLimiter = AuthRateLimiter();

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseAuth auth = FirebaseAuth.instance;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final inviteCodeController = TextEditingController();

  bool isLogin = true;
  bool isLoading = false;
  bool obscurePassword = true;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _animationController.forward();
    _checkBiometricAvailability();
  }

  bool _biometricAvailable = false;

  Future<void> _checkBiometricAvailability() async {
    final available = await BiometricService.isBiometricAvailable();
    if (mounted) {
      setState(() => _biometricAvailable = available);
    }
  }

  Future<void> _authenticateWithBiometrics() async {
    final authenticated = await BiometricService.authenticate();
    if (!authenticated || !mounted) return;

    final user = auth.currentUser;
    final storedEmail = await SecureStorageService.getStoredEmail();
    final sessionValid = await SessionManager.isSessionValid();

    if (user != null &&
        sessionValid &&
        storedEmail != null &&
        user.email?.toLowerCase() == storedEmail.toLowerCase()) {
      setState(() => isLoading = true);
      try {
        await SessionManager.refreshSession();
        if (mounted) await _navigateToDashboard(user.uid);
      } finally {
        if (mounted) setState(() => isLoading = false);
      }
      return;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Sign in with email and password first to enable biometric unlock",
          ),
        ),
      );
    }
  }

  Future<void> _navigateToDashboard(String uid) async {
    final userDoc = await firestore.collection("users").doc(uid).get();
    final data = userDoc.data();
    final chamaId = data?["chamaId"];
    final organizationId = data?["organizationId"];

    if (chamaId == null || organizationId == null) {
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const CreateChamaScreen()),
          (route) => false,
        );
      }
    } else {
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => UnifiedDashboard(userId: uid),
          ),
          (route) => false,
        );
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> handleAuth() async {
    final name = nameController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text.trim();
    final code = inviteCodeController.text.trim();

    if (email.isEmpty || password.isEmpty || (!isLogin && name.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Fill all required fields")),
      );
      return;
    }

    if (_authRateLimiter.isBlocked(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Too many attempts. Please wait a minute and try again."),
        ),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      UserCredential userCredential;

      if (isLogin) {
        userCredential = await auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      } else {
        userCredential = await auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );

        final user = userCredential.user;

        if (user != null) {
          String? chamaId;
          String? organizationId;

          if (code.isNotEmpty) {
            final orgs = await firestore.collection("organizations").get();

            for (var orgDoc in orgs.docs) {
              final chamas = await firestore
                  .collection("organizations")
                  .doc(orgDoc.id)
                  .collection("chamas")
                  .where("inviteCode", isEqualTo: code)
                  .get();

              if (chamas.docs.isNotEmpty) {
                final chama = chamas.docs.first;
                chamaId = chama.id;
                organizationId = orgDoc.id;

                await firestore
                    .collection("organizations")
                    .doc(organizationId)
                    .collection("chamas")
                    .doc(chamaId)
                    .collection("members")
                    .doc(user.uid)
                    .set({
                  "userId": user.uid,
                  "name": name,
                  "email": email,
                  "role": "member",
                  "status": "pending",
                  "joinedAt": Timestamp.now(),
                });
                break;
              }
            }
          }

          await firestore.collection("users").doc(user.uid).set({
            "name": name,
            "email": email,
            "chamaId": chamaId,
            "organizationId": organizationId,
            "role": "member",
            "status": "active",
            "createdAt": Timestamp.now(),
          });
        }
      }

      final currentUser = auth.currentUser;
      if (currentUser != null) {
        _authRateLimiter.reset(email);
        await SecureStorageService.saveEmail(email);
        await SecureStorageService.saveUserId(currentUser.uid);
        await SecureStorageService.saveBiometricEnabled(true);
        await SessionManager.createSession(userId: currentUser.uid);
        await Future.delayed(const Duration(milliseconds: 500));

        final userDoc =
            await firestore.collection("users").doc(currentUser.uid).get();

        final data = userDoc.data();
        final chamaId = data?["chamaId"];
        final organizationId = data?["organizationId"];

        if (!mounted) return;

        if (chamaId == null || organizationId == null) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const CreateChamaScreen()),
            (route) => false,
          );
        } else {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (_) => UnifiedDashboard(userId: currentUser.uid),
            ),
            (route) => false,
          );
        }
      }
    } catch (e) {
      _authRateLimiter.recordAttempt(email);
      final remaining = _authRateLimiter.getRemainingAttempts(email);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            remaining > 0
                ? "Error: ${e.toString()} ($remaining attempts left)"
                : "Error: ${e.toString()}",
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1B5E20),
              Color(0xFF4CAF50),
              Color(0xFF81C784),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  _buildLogo(),
                  const SizedBox(height: 30),
                  _buildFormCard(),
                  const SizedBox(height: 20),
                  _buildFooter(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Column(
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(25),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: const Icon(
            Icons.groups,
            size: 50,
            color: Color(0xFF1B5E20),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          "SmartChama",
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          isLogin ? "Welcome back!" : "Join your chama today!",
          style: TextStyle(
            fontSize: 16,
            color: Colors.white.withOpacity(0.9),
          ),
        ),
      ],
    );
  }

  Widget _buildFormCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildTabButton(true),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildTabButton(false),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (!isLogin) _buildNameField(),
          _buildEmailField(),
          const SizedBox(height: 16),
          _buildPasswordField(),
          if (!isLogin) ...[
            const SizedBox(height: 16),
            _buildInviteCodeField(),
          ],
          const SizedBox(height: 24),
          _buildSubmitButton(),
          const SizedBox(height: 16),
          _buildBiometricButton(),
        ],
      ),
    );
  }

  Widget _buildTabButton(bool login) {
    final isSelected = isLogin == login;
    return GestureDetector(
      onTap: () {
        setState(() => isLogin = login);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1B5E20) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF1B5E20) : Colors.grey.shade300,
          ),
        ),
        child: Center(
          child: Text(
            login ? "Login" : "Sign Up",
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey.shade600,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNameField() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: TextField(
        controller: nameController,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(
          hintText: "Full Name",
          prefixIcon: Icon(Icons.person_outline, color: Color(0xFF1B5E20)),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildEmailField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: TextField(
        controller: emailController,
        keyboardType: TextInputType.emailAddress,
        decoration: const InputDecoration(
          hintText: "Email Address",
          prefixIcon: Icon(Icons.email_outlined, color: Color(0xFF1B5E20)),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildPasswordField() {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: TextField(
        controller: passwordController,
        obscureText: obscurePassword,
        decoration: InputDecoration(
          hintText: "Password",
          prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF1B5E20)),
          border: InputBorder.none,
          suffixIcon: IconButton(
            icon: Icon(
              obscurePassword ? Icons.visibility_off : Icons.visibility,
              color: Colors.grey.shade600,
            ),
            onPressed: () => setState(() => obscurePassword = !obscurePassword),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildInviteCodeField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: TextField(
        controller: inviteCodeController,
        textCapitalization: TextCapitalization.characters,
        decoration: const InputDecoration(
          hintText: "Invite Code (Optional)",
          prefixIcon: Icon(Icons.card_membership, color: Color(0xFF1B5E20)),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: isLoading ? null : handleAuth,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1B5E20),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
        child: isLoading
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Text(
                isLogin ? "Welcome Back" : "Create Account",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  Widget _buildBiometricButton() {
    if (!_biometricAvailable || isLogin == false)
      return const SizedBox.shrink();

    return TextButton.icon(
      onPressed: _authenticateWithBiometrics,
      icon: const Icon(Icons.fingerprint, color: Color(0xFF1B5E20)),
      label: const Text(
        "Use Biometrics",
        style: TextStyle(color: Color(0xFF1B5E20)),
      ),
    );
  }

  Widget _buildFooter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          isLogin ? "Don't have an account? " : "Already have an account? ",
          style: TextStyle(color: Colors.white.withOpacity(0.9)),
        ),
        GestureDetector(
          onTap: () {
            setState(() => isLogin = !isLogin);
          },
          child: Text(
            isLogin ? "Sign Up" : "Login",
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
    );
  }
}
