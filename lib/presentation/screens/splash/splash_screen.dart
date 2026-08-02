import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/license/license_manager.dart';
import '../../../core/notifications/notification_service.dart';
import '../../../data/repositories/app_settings_repository.dart';
import '../../providers/auth_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  final LicenseManager _licenseManager = LicenseManager();

  @override
  void initState() {
    super.initState();
    _checkLicense();
  }

  Future<void> _checkLicense() async {
    try {
      // 1. The licence decides whether the app may run at all.
      final license = await _licenseManager.validateRuntime();
      if (!mounted) return;

      if (!license.isValid) {
        context.go('/license');
        return;
      }

      // One-time cleanup of the token left by the old login screen, which
      // granted access without checking anything.
      await AppSettingsRepository.instance.clearLegacyAuthSession();

      // Reminders are re-armed on every launch: Android drops pending alarms
      // on force-stop, and the expiry moves whenever a new key is applied.
      final expiry = license.data?.expiryDate;
      if (expiry != null) {
        await NotificationService.instance.scheduleLicenseExpiry(expiry);
      }
      // No overdue alert here: the app is opening, so the user is about to see
      // the dashboard. Clear any summary left over from last time instead.
      await NotificationService.instance.dismissLateDigest();

      // 2. Read the lock state. This never unlocks — it only decides between
      // creating a PIN and asking for it — so the router's redirect takes it
      // from here.
      await ref.read(authProvider.notifier).refresh();
      if (!mounted) return;

      context.go('/dashboard');
    } catch (_) {
      if (!mounted) return;
      context.go('/license');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Image.asset(
                'assets/images/logo_new.png',
                width: 112,
                height: 112,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'CarRent Manager',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Gestion de location de véhicules',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 32),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}

