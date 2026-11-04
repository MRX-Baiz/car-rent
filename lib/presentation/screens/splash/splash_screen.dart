import 'package:flutter/material.dart';
import 'package:car_rent_manager/presentation/widgets/common/app_text.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/license/license_manager.dart';
import '../../providers/app_settings_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/reminder_provider.dart';

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
      licenseFeaturesSignal.value = license.data?.features ?? const {};

      // One-time cleanup of the token left by the old login screen, which
      // granted access without checking anything.
      await ref.read(clearLegacyAuthSessionProvider)();

      await ref.read(restoreRemindersOnLaunchProvider)(
        licenseExpiry: license.data?.expiryDate,
      );
      if (!mounted) return;

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
  Widget build(BuildContext context) => const SplashView();
}

/// The colour along the bottom edge of the splash artwork.
const _artEdge = Color(0xFFE9E3DC);

/// What the splash looks like: the artwork slowly pushing in, and a gold line
/// travelling along a track while the app starts. Kept apart from the startup
/// logic above so it can be rendered on its own.
class SplashView extends StatefulWidget {
  const SplashView({super.key});

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView>
    with SingleTickerProviderStateMixin {
  // Drives the gold loading line; stopped under reduced motion.
  late final AnimationController _line = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );
  bool _lineStarted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_lineStarted) return;
    _lineStarted = true;
    if (!MediaQuery.disableAnimationsOf(context)) _line.repeat();
  }

  @override
  void dispose() {
    _line.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // The artwork is fitted to the width so the whole logo and car are
          // always in view, whatever the phone's height; below it the picture
          // dissolves into its own edge colour, where the loader sits.
          const ColoredBox(color: _artEdge),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: still ? 1 : 0, end: 1),
            duration: still ? Duration.zero : const Duration(milliseconds: 700),
            curve: Curves.easeOut,
            builder: (context, fade, child) =>
                Opacity(opacity: fade, child: child),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: still ? 1.0 : 1.1, end: 1.0),
              duration: still ? Duration.zero : const Duration(seconds: 6),
              curve: Curves.easeOutCubic,
              builder: (context, scale, child) => Transform.scale(
                scale: scale,
                alignment: Alignment.topCenter,
                child: child,
              ),
              child: Align(
                alignment: Alignment.topCenter,
                // The fade is applied to the picture itself, so it dissolves
                // right at the picture's own bottom edge.
                child: ShaderMask(
                  blendMode: BlendMode.dstIn,
                  shaderCallback: (rect) => const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.white, Colors.white, Colors.transparent],
                    stops: [0, 0.86, 1],
                  ).createShader(rect),
                  child: Image.asset(
                    'assets/backgrounds/bg_splash.webp',
                    fit: BoxFit.fitWidth,
                    width: double.infinity,
                    filterQuality: FilterQuality.medium,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 56 + bottom,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 132,
                  height: 3,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: AnimatedBuilder(
                      animation: _line,
                      builder: (context, _) {
                        // A short gold segment travelling along the track.
                        final t = still
                            ? 0.5
                            : Curves.easeInOut.transform(_line.value);
                        return Align(
                          alignment: Alignment(-1 + 2 * t, 0),
                          child: FractionallySizedBox(
                            widthFactor: 0.34,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: AppColors.gold,
                                borderRadius: BorderRadius.circular(2),
                              ),
                              child: const SizedBox(height: 3),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const AppText(
                  'CHARGEMENT',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    letterSpacing: 3.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
