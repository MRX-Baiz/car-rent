import 'package:flutter/material.dart';
import 'package:car_rent_manager/core/localization/app_localizations.dart';
import 'package:car_rent_manager/presentation/widgets/common/app_text.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../data/models/chauffeur_model.dart';
import '../../../core/ocr/ocr_service.dart';
import '../../providers/chauffeur_provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/format_utils.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_shimmer.dart';
import '../../widgets/common/empty_state_widget.dart';
import '../../widgets/common/form_section.dart';
import '../../widgets/common/initials_avatar.dart';
import '../../widgets/common/status_badge.dart';
import '../../widgets/common/status_chip.dart';
import '../../widgets/motion/backdrop_page.dart';

class ChauffeursScreen extends ConsumerStatefulWidget {
  const ChauffeursScreen({super.key});

  @override
  ConsumerState<ChauffeursScreen> createState() => _ChauffeursScreenState();
}

class _ChauffeursScreenState extends ConsumerState<ChauffeursScreen> {
  String _query = '';
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(chauffeursProvider);
    return Scaffold(
      appBar: AppBar(
        title: const AppText(AppCopy.drivers),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: context.tr(AppCopy.back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/dashboard'),
        ),
      ),
      body: BackdropPage(
          child: data.when(
        data: (items) => _content(context, items),
        loading: () => AppShimmer.listLayer(),
        error: (e, _) => Center(child: AppText(context.trError(e))),
      )),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/chauffeurs/form'),
        icon: const Icon(Icons.person_add_alt_1_outlined),
        label: const AppText(AppCopy.newDriver),
      ),
    );
  }

  Widget _content(BuildContext context, List<ChauffeurModel> items) {
    if (items.isEmpty) {
      return EmptyStateWidget(
        title: AppCopy.noDrivers,
        subtitle: AppCopy.addYourAgencyDriversSoTheyCanBe,
        icon: Icons.badge_outlined,
        actionLabel: AppCopy.addADriver,
        onAction: () => context.push('/chauffeurs/form'),
      );
    }

    final available = items.where((c) => c.status == 'available').length;
    final filters = [
      (AppCopy.all, 'all', items.length),
      (AppCopy.available61af94, 'available', available),
      (AppCopy.busy9fadb4, 'assigned', items.length - available),
    ];
    final q = _query.toLowerCase();
    final filtered = items.where((c) {
      if (_filter == 'available' && c.status != 'available') return false;
      if (_filter == 'assigned' && c.status == 'available') return false;
      if (q.isEmpty) return true;
      return c.fullName.toLowerCase().contains(q) ||
          c.cin.toLowerCase().contains(q) ||
          c.phone.contains(q);
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: context.tr(AppCopy.nameNationalIDOrPhone),
            ),
            onChanged: (v) => setState(() => _query = v.trim()),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              for (final f in filters)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: ChoiceChip(
                    label: AppText('${context.tr(f.$1)} (${f.$3})'),
                    selected: _filter == f.$2,
                    onSelected: (_) => setState(() => _filter = f.$2),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? const EmptyStateWidget(
                  title: AppCopy.noDriversFound,
                  subtitle: AppCopy.changeTheSearchOrFilter,
                  icon: Icons.badge_outlined,
                )
              : RefreshIndicator(
                  onRefresh: () => ref.read(chauffeursProvider.notifier).load(),
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: ChauffeurCard(
                        chauffeur: filtered[i],
                        onTap: () => context.push('/chauffeurs/form',
                            extra: filtered[i]),
                        onToggleStatus: () => ref
                            .read(chauffeursProvider.notifier)
                            .save(filtered[i].copyWith(
                                status: filtered[i].status == 'available'
                                    ? 'assigned'
                                    : 'available')),
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

class ChauffeurCard extends StatelessWidget {
  const ChauffeurCard({
    super.key,
    required this.chauffeur,
    required this.onTap,
    required this.onToggleStatus,
  });

  final ChauffeurModel chauffeur;
  final VoidCallback onTap;
  final VoidCallback onToggleStatus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = chauffeur;
    final licence = expiryOf(c.licenseExpiryDate);
    final free = c.status == 'available';

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      accent: licence.tone == AppTone.danger ? AppTone.danger.color : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              InitialsAvatar(name: c.fullName, radius: 26),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium),
                    const SizedBox(height: 4),
                    StatusBadge(text: c.status),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  AppText(context.money(c.hourlyRate),
                      style: theme.textTheme.titleMedium
                          ?.copyWith(color: AppColors.primary)),
                  AppText(AppCopy.perHour,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: AppColors.textSecondary)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.phone_outlined,
                  size: 18, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              Expanded(child: Text(c.phone, style: theme.textTheme.bodyMedium)),
              if (c.licenseExpiryDate != null)
                Flexible(
                  child: StatusChip(
                    label: context.messages
                        .licenceStatus(context.tr((licence.label).toString())),
                    tone: licence.tone,
                    icon: Icons.credit_card,
                    dense: true,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton.icon(
              onPressed: onToggleStatus,
              icon: Icon(
                  free
                      ? Icons.do_not_disturb_on_outlined
                      : Icons.check_circle_outline,
                  size: 20),
              label:
                  AppText(free ? AppCopy.markAsBusy : AppCopy.markAsAvailable),
            ),
          ),
        ],
      ),
    );
  }
}

class ChauffeurFormScreen extends ConsumerStatefulWidget {
  const ChauffeurFormScreen({super.key, this.value});
  final ChauffeurModel? value;
  @override
  ConsumerState<ChauffeurFormScreen> createState() =>
      _ChauffeurFormScreenState();
}

class _ChauffeurFormScreenState extends ConsumerState<ChauffeurFormScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _first,
      _last,
      _cin,
      _license,
      _phone,
      _rate,
      _notes;
  DateTime? _expiry;
  String _status = 'available';
  bool _saving = false;
  bool _scanning = false;
  final _ocr = OcrService();
  @override
  void initState() {
    super.initState();
    final c = widget.value;
    _first = TextEditingController(text: c?.firstName ?? '');
    _last = TextEditingController(text: c?.lastName ?? '');
    _cin = TextEditingController(text: c?.cin ?? '');
    _license = TextEditingController(text: c?.licenseNumber ?? '');
    _phone = TextEditingController(text: c?.phone ?? '');
    _rate = TextEditingController(text: c?.hourlyRate.toString() ?? '');
    _notes = TextEditingController(text: c?.notes ?? '');
    _expiry = c?.licenseExpiryDate;
    _status = c?.status ?? 'available';
  }

  @override
  void dispose() {
    for (final c in [_first, _last, _cin, _license, _phone, _rate, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate() || _saving) return;
    setState(() => _saving = true);
    try {
      final now = DateTime.now();
      await ref.read(chauffeursProvider.notifier).save(ChauffeurModel(
          id: widget.value?.id,
          firstName: _first.text.trim(),
          lastName: _last.text.trim(),
          cin: _cin.text.trim(),
          licenseNumber: _license.text.trim(),
          phone: _phone.text.trim(),
          licenseExpiryDate: _expiry,
          hourlyRate: double.parse(_rate.text.trim()),
          status: _status,
          notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
          createdAt: widget.value?.createdAt ?? now,
          updatedAt: now));
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: AppText(context.trError(e))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _scan({required bool license}) async {
    if (_scanning) return;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const AppText(AppCopy.takeAPhoto),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera)),
          ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const AppText(AppCopy.chooseAPhoto),
              onTap: () => Navigator.pop(sheetContext, ImageSource.gallery)),
        ]),
      ),
    );
    if (source == null) return;
    final image =
        await ImagePicker().pickImage(source: source, imageQuality: 95);
    if (image == null) return;
    setState(() => _scanning = true);
    try {
      final text = await _ocr.extractText(image.path);
      final data =
          license ? _ocr.parseLicenseData(text) : _ocr.parseCINData(text);
      if (!mounted) return;
      setState(() {
        if ((data['firstName'] ?? '').isNotEmpty) {
          _first.text = data['firstName']!;
        }
        if ((data['lastName'] ?? '').isNotEmpty) _last.text = data['lastName']!;
        if ((data['cin'] ?? '').isNotEmpty) _cin.text = data['cin']!;
        if (license && (data['licenseNumber'] ?? '').isNotEmpty) {
          _license.text = data['licenseNumber']!;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              AppText(AppCopy.detailsFilledFromTheDocumentCheckThemBefore)));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: AppText(AppCopy.unableToReadTheDocumentEnterTheDetails)));
      }
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const AppText(AppCopy.deleteThisDriver),
        content: Text(context.messages
            .removeDriverConfirmation((widget.value!.fullName).toString())),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const AppText(AppCopy.cancel),
          ),
          FilledButton(
            style:
                FilledButton.styleFrom(backgroundColor: AppTone.danger.color),
            onPressed: () => Navigator.pop(context, true),
            child: const AppText(AppCopy.delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(chauffeursProvider.notifier).delete(widget.value!.id!);
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.value != null;
    final licence = expiryOf(_expiry);
    return Scaffold(
      appBar: AppBar(
        title: AppText(editing ? AppCopy.editDriver : AppCopy.newDriver),
        actions: editing
            ? [
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: context.tr(AppCopy.deleteDriver),
                  onPressed: _delete,
                ),
              ]
            : null,
      ),
      bottomNavigationBar: BottomActionBar(
        child: FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.save_outlined),
          label: AppText(_saving ? AppCopy.saving : AppCopy.save),
        ),
      ),
      body: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FormSection(
                    icon: Icons.badge_outlined,
                    title: AppCopy.identityAndDrivingLicence,
                    subtitle: AppCopy.youCanScanTheNationalIDOrDriving,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _first,
                              textCapitalization: TextCapitalization.words,
                              decoration: InputDecoration(
                                  labelText: context.tr(AppCopy.firstName)),
                              validator: _required,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              controller: _last,
                              textCapitalization: TextCapitalization.characters,
                              decoration: InputDecoration(
                                  labelText: context.tr(AppCopy.name)),
                              validator: _required,
                            ),
                          ),
                        ],
                      ),
                      _scanField(
                        controller: _cin,
                        label: AppCopy.nationalIDCard,
                        icon: Icons.badge_outlined,
                        tooltip: context.tr(AppCopy.scanNationalIDe0c6e8),
                        license: false,
                        validator: _required,
                      ),
                      _scanField(
                        controller: _license,
                        label: AppCopy.drivingLicenceNumber,
                        hint: '33/345678',
                        icon: Icons.credit_card,
                        tooltip: context.tr(AppCopy.scanDrivingLicence),
                        license: true,
                        validator: _licenseValidator,
                      ),
                      InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _expiry ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                          );
                          if (date != null) setState(() => _expiry = date);
                        },
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: context.tr(AppCopy.licenceExpiry),
                            prefixIcon: const Icon(Icons.event_outlined),
                            suffixIcon: const Icon(Icons.edit_calendar_outlined),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: AppText(
                                  _expiry == null
                                      ? AppCopy.notProvidedd6a3c5
                                      : formatDate(_expiry!),
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyLarge
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                              ),
                              if (_expiry != null)
                                StatusChip(
                                    label: licence.label,
                                    tone: licence.tone,
                                    dense: true),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  FormSection(
                    icon: Icons.payments_outlined,
                    title: AppCopy.contactAndRate,
                    children: [
                      TextFormField(
                        controller: _phone,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: context.tr(AppCopy.phone),
                          prefixIcon: const Icon(Icons.phone_outlined),
                        ),
                        validator: _required,
                      ),
                      TextFormField(
                        controller: _rate,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: InputDecoration(
                          labelText: context.tr(AppCopy.hourlyRate),
                          suffixText: context.tr(AppCopy.madH),
                          prefixIcon: const Icon(Icons.schedule),
                        ),
                        validator: (v) => double.tryParse(v ?? '') == null
                            ? context.tr(AppCopy.invalidPrice)
                            : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  FormSection(
                    icon: Icons.event_available_outlined,
                    title: AppCopy.availability,
                    subtitle: AppCopy.onlyAvailableDriversAreOfferedForANew,
                    children: [
                      SegmentedButton<String>(
                        showSelectedIcon: false,
                        segments: const [
                          ButtonSegment(
                              value: 'available',
                              label: AppText(AppCopy.available)),
                          ButtonSegment(
                              value: 'assigned', label: AppText(AppCopy.busy)),
                        ],
                        selected: {_status},
                        onSelectionChanged: (v) =>
                            setState(() => _status = v.first),
                      ),
                      TextFormField(
                        controller: _notes,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: context.tr(AppCopy.notes),
                          alignLabelWithHint: true,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _scanField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String tooltip,
    required bool license,
    String? hint,
    String? Function(String?)? validator,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextFormField(
            controller: controller,
            decoration: InputDecoration(
              labelText: context.tr(label),
              hintText: hint == null ? null : context.tr(hint),
              prefixIcon: Icon(icon),
            ),
            validator: validator,
          ),
        ),
        const SizedBox(width: 8),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: IconButton.filledTonal(
            onPressed: _scanning ? null : () => _scan(license: license),
            icon: const Icon(Icons.document_scanner_outlined),
            tooltip: context.tr(tooltip),
            iconSize: 26,
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          ),
        ),
      ],
    );
  }

  String? _required(String? value) => value == null || value.trim().isEmpty
      ? context.tr(AppCopy.fieldRequired)
      : null;

  String? _licenseValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return context.tr(AppCopy.drivingLicenceIsRequired);
    }
    if (!RegExp(r'^\d{2}/\d{6}$').hasMatch(value.trim())) {
      return context.tr(AppCopy.expectedFormat33345678);
    }
    return null;
  }
}
