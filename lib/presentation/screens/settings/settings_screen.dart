import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/license/license_manager.dart';
import '../../../data/repositories/app_settings_repository.dart';
import '../../providers/app_settings_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _companyNameController = TextEditingController();
  final _companyAddressController = TextEditingController();
  final _companyPhoneController = TextEditingController();
  final _licenseKeyController = TextEditingController();

  final LicenseManager _licenseManager = LicenseManager();

  bool _loadingLicense = true;
  String? _licenseInfo;
  bool _savingCompany = false;

  @override
  void initState() {
    super.initState();
    _loadLicenseInfo();
    _loadCompanySettings();
  }

  @override
  void dispose() {
    _companyNameController.dispose();
    _companyAddressController.dispose();
    _companyPhoneController.dispose();
    _licenseKeyController.dispose();
    super.dispose();
  }

  Future<void> _loadCompanySettings() async {
    final repo = AppSettingsRepository.instance;
    _companyNameController.text = await repo.getCompanyName();
    _companyAddressController.text = await repo.getCompanyAddress();
    _companyPhoneController.text = await repo.getCompanyPhone();
    if (mounted) setState(() {});
  }

  Future<void> _saveCompanySettings() async {
    if (_savingCompany) return;
    setState(() => _savingCompany = true);
    try {
      final repo = AppSettingsRepository.instance;
      await repo.setCompanyName(_companyNameController.text.trim());
      await repo.setCompanyAddress(_companyAddressController.text.trim());
      await repo.setCompanyPhone(_companyPhoneController.text.trim());
      ref.invalidate(companyNameProvider);
      ref.invalidate(companyAddressProvider);
      ref.invalidate(companyPhoneProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.successSaved)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    } finally {
      if (mounted) setState(() => _savingCompany = false);
    }
  }

  Future<void> _loadLicenseInfo() async {
    setState(() => _loadingLicense = true);
    try {
      final active = await _licenseManager.isLicenseActive();
      if (!mounted) return;
      setState(() {
        _licenseInfo = active
            ? 'Licence active.\nالرخصة مفعلة.\nLicense is active and valid.'
            : 'Licence inactive ou expirée.\nالترخيص غير مفعل أو منتهي الصلاحية.';
        _loadingLicense = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _licenseInfo = 'Erreur: $e\nخطأ أثناء تحميل بيانات الرخصة.';
        _loadingLicense = false;
      });
    }
  }

  Future<void> _saveLicense() async {
    final key = _licenseKeyController.text.trim();
    if (key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'La clé de licence est requise.\nمطلوب مفتاح الترخيص.',
          ),
        ),
      );
      return;
    }
    try {
      await _licenseManager.saveLicense(key);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.successSaved)),
      );
      await _loadLicenseInfo();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Erreur lors de l\'enregistrement de la licence.\n'
            'حدث خطأ أثناء حفظ الرخصة.\n'
            'License save error: $e',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/dashboard'),
          tooltip: 'Retour au tableau de bord',
        ),
        title: const Text('Paramètres'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Informations de la société',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _companyNameController,
                  decoration: const InputDecoration(
                    labelText: 'Nom de la société',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _companyAddressController,
                  decoration: const InputDecoration(
                    labelText: 'Adresse',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _companyPhoneController,
                  decoration: const InputDecoration(
                    labelText: 'Téléphone',
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: _savingCompany ? null : _saveCompanySettings,
                  icon: _savingCompany
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: const Text('Enregistrer les informations'),
                ),
                const SizedBox(height: 24),
                Text(
                  'Licence',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                if (_loadingLicense)
                  const LinearProgressIndicator()
                else if (_licenseInfo != null)
                  Text(
                    _licenseInfo!,
                    style: theme.textTheme.bodyMedium,
                  ),
                const SizedBox(height: 12),
                TextField(
                  controller: _licenseKeyController,
                  decoration: const InputDecoration(
                    labelText: 'Nouvelle clé de licence',
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: _saveLicense,
                  icon: const Icon(Icons.vpn_key),
                  label: const Text('Enregistrer la licence'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
