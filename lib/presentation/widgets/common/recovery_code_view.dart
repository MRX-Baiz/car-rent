import 'package:car_rent_manager/core/localization/app_localizations.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:car_rent_manager/presentation/widgets/common/app_text.dart';
import 'package:flutter/services.dart';

import '../../../core/security/recovery_code.dart';

/// Shows a recovery code once, and only once.
///
/// Only the hash is stored, so this really is the last time it can be
/// displayed. The acknowledge button stays disabled for a few seconds because
/// the natural reflex on a screen full of text is to dismiss it — and here that
/// reflex costs the customer their way back in.
class RecoveryCodeView extends StatefulWidget {
  const RecoveryCodeView({
    super.key,
    required this.code,
    required this.onAcknowledged,
    this.acknowledgeLabel = AppCopy.iNotedThisCode,
  });

  final String code;
  final VoidCallback onAcknowledged;
  final String acknowledgeLabel;

  @override
  State<RecoveryCodeView> createState() => _RecoveryCodeViewState();
}

class _RecoveryCodeViewState extends State<RecoveryCodeView> {
  static const Duration _readingTime = Duration(seconds: 5);

  Timer? _timer;
  int _secondsLeft = _readingTime.inSeconds;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) timer.cancel();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ready = _secondsLeft <= 0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(
          Icons.vpn_key_outlined,
          size: 48,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(height: 16),
        AppText(
          AppCopy.recoveryCode,
          textAlign: TextAlign.center,
          style:
              theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        AppText(
          AppCopy.writeThisCodeDownAndKeepItSomewhere,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: SelectableText(
            RecoveryCode.format(widget.code),
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () async {
            await Clipboard.setData(
              ClipboardData(text: RecoveryCode.format(widget.code)),
            );
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: AppText(AppCopy.codeCopied)),
            );
          },
          icon: const Icon(Icons.copy, size: 18),
          label: const AppText(AppCopy.copyCode),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.errorContainer.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  color: theme.colorScheme.error, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: AppText(
                  AppCopy.itWillNeverBeShownAgain,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onErrorContainer,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: ready ? widget.onAcknowledged : null,
          child: AppText(
            ready
                ? widget.acknowledgeLabel
                : '${context.tr(widget.acknowledgeLabel)} ($_secondsLeft)',
          ),
        ),
      ],
    );
  }
}
