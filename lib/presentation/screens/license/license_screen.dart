import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/license/license_manager.dart';

class LicenseScreen extends ConsumerStatefulWidget {
  const LicenseScreen({super.key});

  @override
  ConsumerState<LicenseScreen> createState() => _LicenseScreenState();
}

class _LicenseScreenState extends ConsumerState<LicenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _licenseController = TextEditingController();
  final LicenseManager _licenseManager = LicenseManager();

  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _licenseController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final licenseKey = _licenseController.text.trim();

    try {
      final result = await _licenseManager.validateLicense(licenseKey);
      if (!mounted) return;

      if (result.isValid) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Licence activée avec succès.\nتم تفعيل الرخصة بنجاح.\nLicense activated successfully.',
            ),
          ),
        );
        context.go('/dashboard');
      } else {
        setState(() {
          _errorMessage = result.errorMessage ??
              'Clé de licence invalide.\nمفتاح الترخيص غير صالح.\nInvalid license key.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage =
            'Erreur lors de la validation de la licence.\nحدث خطأ أثناء التحقق من الرخصة.\nLicense validation error: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Activation de la licence'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.vpn_key_rounded,
                  size: 64,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  'Entrez votre clé de licence pour activer CarRent Manager.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'الرجاء إدخال مفتاح الترخيص لتفعيل النظام.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                Form(
                  key: _formKey,
                  child: TextFormField(
                    controller: _licenseController,
                    decoration: const InputDecoration(
                      labelText: 'Clé de licence / License key',
                      hintText: 'AUTO123-2026-05-13-XXXXXXXX',
                      border: OutlineInputBorder(),
                    ),
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _submit(),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'La clé de licence est requise.\nمطلوب مفتاح الترخيص.\nLicense key is required.';
                      }
                      if (!value.contains('-')) {
                        return 'Format de clé invalide.\nتنسيق المفتاح غير صالح.\nInvalid key format.';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 16),
                if (_errorMessage != null) ...[
                  Text(
                    _errorMessage!,
                    style: TextStyle(
                      color: theme.colorScheme.error,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                ],
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : _submit,
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.check_circle_outline),
                    label: Text(
                      _isSubmitting
                          ? 'Validation en cours...'
                          : 'Valider la licence',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

