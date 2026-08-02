import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/license/license_manager.dart';
import '../../../core/security/pin_reset_token.dart';
import '../../../core/security/recovery_code.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../providers/auth_provider.dart';

/// Two ways back in for someone who has forgotten their PIN.
///
/// Neither erases anything: a success clears the PIN only, and the router then
/// sends the user to choose a new one. Clients, contracts, payments and scanned
/// documents are all still there.
class PinRecoveryScreen extends ConsumerStatefulWidget {
  const PinRecoveryScreen({super.key});

  @override
  ConsumerState<PinRecoveryScreen> createState() => _PinRecoveryScreenState();
}

class _PinRecoveryScreenState extends ConsumerState<PinRecoveryScreen> {
  final _codeController = TextEditingController();
  final _tokenController = TextEditingController();

  String? _deviceId;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadDeviceId();
  }

  @override
  void dispose() {
    _codeController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  /// The vendor needs this to mint a token, and the customer is locked out of
  /// the app, so it has to be readable from here.
  Future<void> _loadDeviceId() async {
    final id = await LicenseManager().getDeviceId();
    if (mounted) setState(() => _deviceId = id);
  }

  Future<void> _submitRecoveryCode() async {
    final code = _codeController.text;
    if (!RecoveryCode.isComplete(code)) {
      _showMessage('Le code de récupération compte '
          '${RecoveryCode.length} chiffres.');
      return;
    }

    setState(() => _busy = true);
    final outcome =
        await ref.read(authProvider.notifier).redeemRecoveryCode(code);
    if (!mounted) return;
    setState(() => _busy = false);

    if (outcome is UnlockSuccess) {
      _onRecovered();
    } else {
      _showMessage(ref.read(authProvider).message ?? 'Code incorrect.');
    }
  }

  Future<void> _submitResetToken() async {
    final token = _tokenController.text.trim();
    if (token.isEmpty) {
      _showMessage('Collez le code fourni par votre vendeur.');
      return;
    }

    setState(() => _busy = true);
    final outcome =
        await ref.read(authProvider.notifier).redeemResetToken(token);
    if (!mounted) return;
    setState(() => _busy = false);

    if (outcome is ResetTokenAccepted) {
      _onRecovered();
    } else {
      _showMessage(ref.read(authProvider).message ?? 'Code invalide.');
    }
  }

  void _onRecovered() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Accès rétabli. Choisissez un nouveau code PIN.'),
      ),
    );
    // The lock state is now needsSetup, so the guard routes to /pin-setup on
    // its own; this just leaves the recovery page behind.
    if (context.canPop()) context.pop();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Code PIN oublié'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            24,
            24,
            24,
            24 + MediaQuery.viewPaddingOf(context).bottom,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer
                          .withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline,
                            color: theme.colorScheme.primary, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Vos données ne seront pas effacées. Seul le code '
                            'PIN est réinitialisé.',
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  Text(
                    'J\'ai mon code de récupération',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Les ${RecoveryCode.length} chiffres affichés lors de la '
                    'création de votre code PIN.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _codeController,
                    keyboardType: TextInputType.number,
                    enabled: !_busy,
                    maxLength: 17, // 12 digits plus the separators.
                    decoration: const InputDecoration(
                      labelText: 'Code de récupération',
                      hintText: '4821 9037 5566',
                      prefixIcon: Icon(Icons.vpn_key_outlined),
                      counterText: '',
                    ),
                    onSubmitted: (_) => _submitRecoveryCode(),
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: _busy ? null : _submitRecoveryCode,
                    child: const Text('Valider'),
                  ),

                  const SizedBox(height: 32),
                  const Divider(),
                  const SizedBox(height: 16),

                  Text(
                    'J\'ai perdu mon code de récupération',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Contactez votre vendeur et communiquez-lui l\'identifiant '
                    'ci-dessous. Il vous transmettra un code de déblocage '
                    'valable 24 heures.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),

                  Card(
                    margin: EdgeInsets.zero,
                    child: ListTile(
                      title: const Text('Identifiant de cet appareil'),
                      subtitle: SelectableText(
                        _deviceId ?? 'Chargement…',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.copy),
                        tooltip: 'Copier',
                        onPressed: _deviceId == null
                            ? null
                            : () async {
                                await Clipboard.setData(
                                  ClipboardData(text: _deviceId!),
                                );
                                if (!context.mounted) return;
                                _showMessage('Identifiant copié.');
                              },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: _tokenController,
                    enabled: !_busy,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Code de déblocage du vendeur',
                      hintText: 'Collez ici le code reçu',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: _busy ? null : _submitResetToken,
                    child: const Text('Débloquer'),
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
