import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smartchama/screens/create_entity_screen.dart';
import 'package:smartchama/screens/join_chama_screen.dart';
import 'package:smartchama/services/notification_service.dart';
import 'package:smartchama/services/offline_storage_service.dart';
import 'package:smartchama/services/security_service.dart';
import 'firebase_options.dart';

import 'screens/auth/auth_screen.dart';
import 'screens/dashboard/unified_dashboard.dart';
import 'screens/platform/super_admin_dashboard.dart';
import 'screens/subscription/subscription_screen.dart';
import 'screens/settings/branding_settings_screen.dart';
import 'screens/settings/white_label_settings_screen.dart';
import 'screens/wallet/wallet_screen.dart';
import 'screens/ai/ai_advisor_screen.dart';
import 'screens/ai/fraud_detection_screen.dart';
import 'screens/communication/communication_center_screen.dart';
import 'screens/reports/advanced_reports_screen.dart';
import 'screens/settings/api_integrations_screen.dart';
import 'screens/settings/payment_gateway_screen.dart';
import 'services/offline_sync_service.dart';
import 'providers/app_providers.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initializeAndNavigate();
  }

  Future<void> _initializeAndNavigate() async {
    // Only show the splash screen delay in debug builds; in release the
    // app should launch immediately.
    if (kDebugMode) {
      await Future.delayed(const Duration(seconds: 2));
    }
    if (!mounted) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user != null && await SessionManager.isSessionValid()) {
      final userDoc = await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .get();
      final chamaId = userDoc.data()?["chamaId"];
      final platformRole = userDoc.data()?["platformRole"];

      // A user that already has a chama is sent to the dashboard, which repairs
      // incomplete or legacy links before loading.
      final hasChama =
          chamaId != null && chamaId.toString().trim().isNotEmpty;

      if (mounted) {
        if (platformRole == "super_admin") {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (_) => const SuperAdminDashboard(),
            ),
            (route) => false,
          );
        } else if (hasChama) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (_) => UnifiedDashboard(userId: user.uid),
            ),
            (route) => false,
          );
        } else {
          Navigator.pushReplacementNamed(context, '/create');
        }
      }
    } else {
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/auth');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1B5E20),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25),
              ),
              child:
                  const Icon(Icons.groups, size: 50, color: Color(0xFF1B5E20)),
            ),
            const SizedBox(height: 20),
            const Text(
              "SmartChama",
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 30),
            const CircularProgressIndicator(color: Colors.white),
          ],
        ),
      ),
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize Crashlytics
  await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

  // Initialize Performance
  await FirebasePerformance.instance.setPerformanceCollectionEnabled(true);

  await OfflineStorageService.init();
  await OfflineSyncService.init();
  NotificationService.initializeTimezone();
  await NotificationService().initialize();

  runApp(const ProviderScope(child: SmartChamaApp()));
}

class SmartChamaApp extends ConsumerWidget {
  const SmartChamaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeAsync = ref.watch(brandingThemeProvider);
    return MaterialApp(
      title: "SmartChama",
      debugShowCheckedModeBanner: false,
      theme: themeAsync.when<ThemeData>(
        data: (theme) => theme,
        loading: () => ThemeData(
          primarySwatch: Colors.green,
          scaffoldBackgroundColor: Colors.grey[100],
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF1B5E20),
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1B5E20),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF1B5E20), width: 2),
            ),
          ),
        ),
        error: (_, __) => ThemeData(
          primarySwatch: Colors.green,
          scaffoldBackgroundColor: Colors.grey[100],
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF1B5E20),
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1B5E20),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF1B5E20), width: 2),
            ),
          ),
        ),
      ),
      initialRoute: '/',
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/':
            return MaterialPageRoute(builder: (_) => const SplashScreen());
          case '/auth':
            return MaterialPageRoute(builder: (_) => const AuthScreen());
          case '/create':
            return MaterialPageRoute(builder: (_) => const CreateEntityScreen());
          case '/joinChama':
            return MaterialPageRoute(builder: (_) => const JoinChamaScreen());
          case '/superAdmin':
            return MaterialPageRoute(builder: (_) => const SuperAdminDashboard());
          case '/subscription':
            final orgId = settings.arguments as String? ?? '';
            return MaterialPageRoute(builder: (_) => SubscriptionScreen(organizationId: orgId));
          case '/branding':
            final orgId = settings.arguments as String? ?? '';
            return MaterialPageRoute(builder: (_) => BrandingSettingsScreen(organizationId: orgId));
          case '/whiteLabel':
            final orgId = settings.arguments as String? ?? '';
            return MaterialPageRoute(builder: (_) => WhiteLabelSettingsScreen(organizationId: orgId));
          case '/wallet':
            final args = settings.arguments as Map<String, dynamic>? ?? {};
            return MaterialPageRoute(builder: (_) => WalletScreen(
              organizationId: args['organizationId'] ?? '',
              userId: args['userId'] ?? '',
              chamaId: args['chamaId'] ?? '',
            ));
          case '/aiAdvisor':
            final args = settings.arguments as Map<String, dynamic>? ?? {};
            return MaterialPageRoute(builder: (_) => AIAdvisorScreen(
              chamaId: args['chamaId'] ?? '',
              organizationId: args['organizationId'] ?? '',
            ));
          case '/fraudDetection':
            final args = settings.arguments as Map<String, dynamic>? ?? {};
            return MaterialPageRoute(builder: (_) => FraudDetectionScreen(
              chamaId: args['chamaId'] ?? '',
              organizationId: args['organizationId'] ?? '',
            ));
          case '/communication':
            final args = settings.arguments as Map<String, dynamic>? ?? {};
            return MaterialPageRoute(builder: (_) => CommunicationCenterScreen(
              organizationId: args['organizationId'] ?? '',
              chamaId: args['chamaId'] ?? '',
              userId: args['userId'] ?? '',
            ));
          case '/reports':
            final args = settings.arguments as Map<String, dynamic>? ?? {};
            return MaterialPageRoute(builder: (_) => AdvancedReportsScreen(
              chamaId: args['chamaId'] ?? '',
              organizationId: args['organizationId'] ?? '',
              chamaName: args['chamaName'] ?? 'Chama',
            ));
          case '/integrations':
            final orgId = settings.arguments as String? ?? '';
            return MaterialPageRoute(builder: (_) => ApiIntegrationsScreen(organizationId: orgId));
          case '/payments':
            final orgId = settings.arguments as String? ?? '';
            return MaterialPageRoute(builder: (_) => PaymentGatewayScreen(organizationId: orgId));
          default:
            return MaterialPageRoute(builder: (_) => const AuthScreen());
        }
      },
    );
  }
}