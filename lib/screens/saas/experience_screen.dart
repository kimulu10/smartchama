import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smartchama/providers/app_providers.dart';
import 'package:smartchama/services/security_service.dart';

/// Mobile & Web Experience: dark mode, biometrics, PWA and accessibility.
class ExperienceScreen extends ConsumerStatefulWidget {
  const ExperienceScreen({super.key});

  @override
  ConsumerState<ExperienceScreen> createState() => _ExperienceScreenState();
}

class _ExperienceScreenState extends ConsumerState<ExperienceScreen> {
  bool _biometricAvailable = false;
  bool _biometricEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadBiometrics();
  }

  Future<void> _loadBiometrics() async {
    _biometricAvailable =
        await BiometricService.isBiometricAvailable();
    _biometricEnabled = await SecureStorageService.isBiometricEnabled();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Mobile & Web Experience')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.dark_mode),
              title: const Text('Dark Mode'),
              subtitle: const Text('Reduce eye strain at night'),
              trailing: Switch(
                value: themeMode == ThemeMode.dark,
                onChanged: (on) {
                  ref.read(themeModeProvider.notifier).state =
                      on ? ThemeMode.dark : ThemeMode.light;
                },
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.fingerprint),
              title: const Text('Biometric Authentication'),
              subtitle: Text(_biometricAvailable
                  ? (_biometricEnabled
                      ? 'Enabled on this device'
                      : 'Available — tap to enable')
                  : 'Not available on this device'),
              trailing: Switch(
                value: _biometricEnabled,
                onChanged: _biometricAvailable
                    ? (on) async {
                        await SecureStorageService.saveBiometricEnabled(on);
                        setState(() => _biometricEnabled = on);
                      }
                    : null,
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.web),
              title: const Text('Progressive Web App'),
              subtitle: const Text(
                  'Installable, offline-capable web experience enabled'),
              trailing: const Chip(label: Text('Active')),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.accessibility),
              title: const Text('Accessibility'),
              subtitle: const Text(
                  'Large text, high contrast and screen-reader support'),
              trailing: const Icon(Icons.check_circle, color: Colors.green),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.animation),
              title: const Text('Smooth Animations'),
              subtitle: const Text('Fluid transitions across screens'),
              trailing: const Icon(Icons.check_circle, color: Colors.green),
            ),
          ),
        ],
      ),
    );
  }
}
