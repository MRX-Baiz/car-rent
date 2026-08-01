import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The filled/empty dots above the keypad.
class PinDots extends StatelessWidget {
  const PinDots({
    super.key,
    required this.length,
    required this.filled,
    this.error = false,
  });

  final int length;
  final int filled;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeColor = error ? theme.colorScheme.error : theme.colorScheme.primary;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(length, (index) {
        final isFilled = index < filled;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin: const EdgeInsets.symmetric(horizontal: 8),
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isFilled ? activeColor : Colors.transparent,
            border: Border.all(
              color: isFilled
                  ? activeColor
                  : theme.colorScheme.outline.withValues(alpha: 0.6),
              width: 1.5,
            ),
          ),
        );
      }),
    );
  }
}

/// Numeric keypad for entering a PIN.
///
/// The parent owns the digits: this widget only reports edits, so the same pad
/// serves the lock screen and the two-step setup screen.
class PinPad extends StatelessWidget {
  const PinPad({
    super.key,
    required this.value,
    required this.maxLength,
    required this.onChanged,
    this.onBiometric,
    this.enabled = true,
  });

  final String value;
  final int maxLength;
  final ValueChanged<String> onChanged;

  /// Shown in the bottom-left slot when the device offers biometrics.
  final VoidCallback? onBiometric;

  final bool enabled;

  void _append(String digit) {
    if (value.length >= maxLength) return;
    HapticFeedback.selectionClick();
    onChanged(value + digit);
  }

  void _backspace() {
    if (value.isEmpty) return;
    HapticFeedback.selectionClick();
    onChanged(value.substring(0, value.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Keep the pad thumb-sized on a phone without letting it sprawl on a
        // tablet or desktop window.
        final width = constraints.maxWidth.clamp(0.0, 320.0);
        final keySize = (width / 3) - 16;

        return SizedBox(
          width: width,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final row in const [
                ['1', '2', '3'],
                ['4', '5', '6'],
                ['7', '8', '9'],
              ])
                _buildRow(
                  context,
                  keySize,
                  row.map((d) => _digitKey(context, d, keySize)).toList(),
                ),
              _buildRow(context, keySize, [
                if (onBiometric != null)
                  _actionKey(
                    context,
                    keySize,
                    Icons.fingerprint,
                    enabled ? onBiometric : null,
                    tooltip: 'Déverrouiller par empreinte',
                  )
                else
                  SizedBox(width: keySize, height: keySize),
                _digitKey(context, '0', keySize),
                _actionKey(
                  context,
                  keySize,
                  Icons.backspace_outlined,
                  enabled && value.isNotEmpty ? _backspace : null,
                  tooltip: 'Effacer',
                ),
              ]),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRow(BuildContext context, double keySize, List<Widget> keys) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: keys,
      ),
    );
  }

  Widget _digitKey(BuildContext context, String digit, double size) {
    final theme = Theme.of(context);
    return SizedBox(
      width: size,
      height: size,
      child: Material(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? () => _append(digit) : null,
          child: Center(
            child: Text(
              digit,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w500,
                color: enabled
                    ? theme.colorScheme.onSurface
                    : theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _actionKey(
    BuildContext context,
    double size,
    IconData icon,
    VoidCallback? onTap, {
    required String tooltip,
  }) {
    return SizedBox(
      width: size,
      height: size,
      child: IconButton(
        onPressed: onTap,
        icon: Icon(icon),
        iconSize: size * 0.4,
        tooltip: tooltip,
      ),
    );
  }
}
