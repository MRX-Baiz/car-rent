import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/repositories/auth_repository.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/pin_pad.dart';
import '../../widgets/common/recovery_code_view.dart';

enum _Step { current, create, confirm, recoveryCode }

/// Creates the app PIN, or replaces an existing one.
///
/// [isChange] adds a step that checks the current PIN first, so reaching the
/// settings screen on an unlocked phone is not enough to lock the owner out.
class PinSetupScreen extends ConsumerStatefulWidget {
  const PinSetupScreen({super.key, this.isChange = false});

  final bool isChange;

  @override
  ConsumerState<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends ConsumerState<PinSetupScreen> {
  late _Step _step = widget.isChange ? _Step.current : _Step.create;

  String _pin = '';
  String _currentPin = '';
  String _firstEntry = '';
  String? _error;
  bool _busy = false;
  String? _recoveryCode;

  static const int _length = AuthRepository.pinLength;

  /// Rejects the codes people reach for first and attackers try first.
  static String? _weakness(String pin) {
    if (pin.split('').toSet().length == 1) {
      return 'Évitez un code composé du même chiffre.';
    }
    final digits = pin.split('').map(int.parse).toList();
    final ascending = List.generate(digits.length - 1, (i) => digits[i + 1] - digits[i]);
    if (ascending.every((d) => d == 1) || ascending.every((d) => d == -1)) {
      return 'Évitez une suite de chiffres consécutifs.';
    }
    return null;
  }

  Future<void> _onChanged(String value) async {
    setState(() {
      _pin = value;
      _error = null;
    });
    if (value.length < _length) return;

    switch (_step) {
      case _Step.current:
        await _checkCurrent(value);
      case _Step.create:
        _acceptFirstEntry(value);
      case _Step.confirm:
        await _confirm(value);
      case _Step.recoveryCode:
        break; // No keypad on that step.
    }
  }

  Future<void> _checkCurrent(String value) async {
    setState(() => _busy = true);
    final outcome = await ref
        .read(authRepositoryProvider)
        .verifyPin(value);
    if (!mounted) return;

    setState(() {
      _busy = false;
      _pin = '';
      switch (outcome) {
        case UnlockSuccess():
          _currentPin = value;
          _step = _Step.create;
        case UnlockLockedOut(:final remaining):
          _error = 'Trop de tentatives. Réessayez dans '
              '${remaining.inMinutes < 1 ? "${remaining.inSeconds} s" : "${remaining.inMinutes} min"}.';
        case UnlockWrongPin():
        case NoPinConfigured():
          _error = 'Code actuel incorrect.';
      }
    });
  }

  void _acceptFirstEntry(String value) {
    final weakness = _weakness(value);
    setState(() {
      _pin = '';
      if (weakness != null) {
        _error = weakness;
      } else {
        _firstEntry = value;
        _step = _Step.confirm;
      }
    });
  }

  Future<void> _confirm(String value) async {
    if (value != _firstEntry) {
      setState(() {
        _pin = '';
        _firstEntry = '';
        _step = _Step.create;
        _error = 'Les deux codes ne correspondent pas. Recommencez.';
      });
      return;
    }

    setState(() => _busy = true);

    if (widget.isChange) {
      await ref
          .read(authRepositoryProvider)
          .changePin(currentPin: _currentPin, newPin: value);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Code PIN modifié.')),
      );
      context.pop();
      return;
    }

    // First run. The PIN is stored but the app stays locked until the recovery
    // code has been acknowledged — unlocking now would let the router move on
    // and the code would never be seen.
    final code =
        await ref.read(authProvider.notifier).createPinAndRecoveryCode(value);
    if (!mounted) return;
    setState(() {
      _recoveryCode = code;
      _step = _Step.recoveryCode;
      _busy = false;
    });
  }

  ({String title, String subtitle}) get _copy {
    switch (_step) {
      case _Step.current:
        return (
          title: 'Code actuel',
          subtitle: 'Entrez votre code actuel pour continuer.',
        );
      case _Step.create:
        return (
          title: widget.isChange ? 'Nouveau code' : 'Créez votre code',
          subtitle:
              'Choisissez un code à $_length chiffres. Il protège vos clients, '
                  'contrats et documents sur cet appareil.',
        );
      case _Step.confirm:
        return (
          title: 'Confirmez le code',
          subtitle: 'Saisissez le même code une seconde fois.',
        );
      case _Step.recoveryCode:
        return (title: '', subtitle: '');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final copy = _copy;

    return Scaffold(
      appBar: widget.isChange
          ? AppBar(
              title: const Text('Modifier le code PIN'),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.pop(),
              ),
            )
          : null,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: _step == _Step.recoveryCode
                  ? RecoveryCodeView(
                      code: _recoveryCode!,
                      acknowledgeLabel: 'J\'ai noté ce code',
                      // Only now does the app unlock, so the code cannot be
                      // skipped past by the router.
                      onAcknowledged: () =>
                          ref.read(authProvider.notifier).completeSetup(),
                    )
                  : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!widget.isChange) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.asset(
                        'assets/images/logo_new.png',
                        width: 76,
                        height: 76,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  Text(
                    copy.title,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    copy.subtitle,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 32),
                  PinDots(
                    length: _length,
                    filled: _pin.length,
                    error: _error != null,
                  ),
                  SizedBox(
                    height: 52,
                    child: Center(
                      child: _error == null
                          ? null
                          : Text(
                              _error!,
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
                    maxLength: _length,
                    enabled: !_busy,
                    onChanged: _onChanged,
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

