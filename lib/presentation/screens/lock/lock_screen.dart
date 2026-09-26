import 'package:car_rent_manager/core/localization/app_localizations.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:car_rent_manager/presentation/widgets/common/app_text.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/auth_provider.dart';
import '../../widgets/common/pin_pad.dart';

/// Asks for the PIN before the app data is reachable.
///
/// Nothing here navigates on success: the router's redirect watches the lock
/// state, so unlocking moves the app on its own.
class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  String _pin = '';
  bool _shake = false;
  Timer? _lockoutTicker;

  @override
  void initState() {
    super.initState();
    // Offer the fingerprint straight away so the common case is one touch.
    WidgetsBinding.instance.addPostFrameCallback((_) => _promptBiometric());
  }

  @override
  void dispose() {
    _lockoutTicker?.cancel();
    super.dispose();
  }

  Future<void> _promptBiometric() async {
    if (!mounted) return;
    final auth = ref.read(authProvider);
    if (!auth.biometricAvailable || auth.isLockedOut) return;
    await ref.read(authProvider.notifier).tryBiometric();
  }

  void _onChanged(String value) {
    setState(() => _pin = value);
    if (value.length == appPinLength) {
      _submit();
    }
  }

  Future<void> _submit() async {
    final ok = await ref.read(authProvider.notifier).submitPin(_pin);
    if (!mounted) return;
    if (!ok) {
      setState(() {
        _pin = '';
        _shake = true;
      });
      _startLockoutTicker();
      await Future<void>.delayed(const Duration(milliseconds: 400));
      if (mounted) setState(() => _shake = false);
    }
  }

  /// Counts the lockout down in place so the user is not left guessing, and
  /// re-enables the pad the moment it expires.
  void _startLockoutTicker() {
    _lockoutTicker?.cancel();
    if (!ref.read(authProvider).isLockedOut) return;

    _lockoutTicker = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }
      await ref.read(authProvider.notifier).refreshLockout();
      if (!ref.read(authProvider).isLockedOut) {
        timer.cancel();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = ref.watch(authProvider);
    final locked = auth.isLockedOut;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: Image.asset(
                      'assets/images/logo_new.png',
                      width: 88,
                      height: 88,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 24),
                  AppText(
                    'CarRent Manager',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  AppText(
                    locked
                        ? AppCopy.appLocked
                        : context.messages
                            .enterPinDigits((appPinLength).toString()),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 32),

                  AnimatedSlide(
                    offset: _shake ? const Offset(0.03, 0) : Offset.zero,
                    duration: const Duration(milliseconds: 80),
                    child: PinDots(
                      length: appPinLength,
                      filled: _pin.length,
                      error: auth.message != null,
                    ),
                  ),

                  SizedBox(
                    height: 48,
                    child: Center(
                      child: auth.message == null
                          ? null
                          : AppText(
                              auth.message!,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.error,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                    ),
                  ),

                  PinPad(
                    value: _pin,
                    maxLength: appPinLength,
                    enabled: !locked && !auth.busy,
                    onChanged: _onChanged,
                    onBiometric:
                        auth.biometricAvailable ? _promptBiometric : null,
                  ),

                  const SizedBox(height: 8),
                  // Reachable while locked out too: a long lockout is exactly
                  // when someone realises they have genuinely forgotten it.
                  TextButton(
                    onPressed: () => context.push('/lock/recovery'),
                    child: const AppText(AppCopy.forgotPINbeb8db),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
