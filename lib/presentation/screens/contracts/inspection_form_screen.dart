import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:car_rent_manager/core/localization/app_localizations.dart';
import 'package:car_rent_manager/presentation/widgets/common/app_text.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/vehicle_labels.dart';
import '../../../domain/entities/inspection.dart';
import '../../widgets/common/alert_banner.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/form_section.dart';
import '../../widgets/common/inspection_vehicle_photo.dart';
import '../../widgets/common/plate_badge.dart';
import '../../widgets/common/status_chip.dart';
import '../../providers/contract_progress_provider.dart';
import '../../providers/inspection_provider.dart';
import '../../providers/vehicle_provider.dart';
import 'client_signature_screen.dart';

class InspectionFormScreen extends ConsumerStatefulWidget {
  const InspectionFormScreen(
      {super.key, required this.contractId, required this.type});
  final int contractId;
  final String type;
  @override
  ConsumerState<InspectionFormScreen> createState() =>
      _InspectionFormScreenState();
}

class _InspectionFormScreenState extends ConsumerState<InspectionFormScreen> {
  final _form = GlobalKey<FormState>();
  final _mileage = TextEditingController();
  final _notes = TextEditingController();
  final _charges = TextEditingController();
  InspectionContext? _inspectionContext;
  String _condition = 'good';
  int _fuel = 100;
  final Map<String, File> _photos = {};
  Uint8List? _signature;
  bool _saving = false;
  bool get _departure => widget.type == InspectionKind.departure.storageValue;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _mileage.dispose();
    _notes.dispose();
    _charges.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final context = await ref.read(loadInspectionContextProvider)(
      contractId: widget.contractId,
      kind: InspectionKind.fromStorageValue(widget.type),
    );
    if (!mounted) return;
    setState(() {
      _inspectionContext = context;
      _mileage.text = context?.vehicle.currentMileage.toString() ?? '0';
      _condition = context?.vehicle.conditionStatus ?? 'good';
      _fuel = context?.vehicle.fuelLevel ?? 100;
    });
  }

  Future<void> _photo(String key) async {
    final source = await showModalBottomSheet<ImageSource>(
        context: context,
        builder: (c) => SafeArea(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
              ListTile(
                  leading: const Icon(Icons.camera_alt),
                  title: const AppText(AppCopy.takeAPhoto),
                  onTap: () => Navigator.pop(c, ImageSource.camera)),
              ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: const AppText(AppCopy.chooseFromPhone),
                  onTap: () => Navigator.pop(c, ImageSource.gallery))
            ])));
    if (source == null) return;
    final file =
        await ImagePicker().pickImage(source: source, imageQuality: 85);
    if (file != null && mounted) setState(() => _photos[key] = File(file.path));
  }

  Future<void> _sign() async {
    final value = await Navigator.of(context).push<Uint8List>(MaterialPageRoute(
        builder: (_) =>
            const ClientSignatureScreen(clientName: AppCopy.signatureForInspection)));
    if (value != null && mounted) setState(() => _signature = value);
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate() ||
        _saving ||
        _inspectionContext == null) {
      return;
    }
    if (_departure && _signature == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: AppText(AppCopy.theClientSignatureIsRequiredAtPickup)));
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(saveInspectionProvider)(
        InspectionDraft(
          contractId: widget.contractId,
          kind: InspectionKind.fromStorageValue(widget.type),
          mileage: int.parse(_mileage.text),
          fuelLevel: _fuel,
          conditionStatus: _condition,
          damageNotes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
          extraCharges: double.tryParse(_charges.text) ?? 0,
          photoSourcePaths:
              _photos.map((kind, file) => MapEntry(kind, file.path)),
          signature: _signature,
          createdAt: DateTime.now(),
        ),
      );
      ref.invalidate(contractProgressProvider(widget.contractId));
      await ref.read(vehiclesProvider.notifier).loadVehicles();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: AppText(AppCopy.inspectionSaved)));
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: AppText(context.trError(e))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  static const _fuelChoices = [
    (0, 'Vide'),
    (25, '1/4'),
    (50, '1/2'),
    (75, '3/4'),
    (100, 'Plein'),
  ];

  @override
  Widget build(BuildContext context) {
    final inspection = _inspectionContext;
    if (inspection == null) {
      return Scaffold(
        appBar: AppBar(title: const AppText(AppCopy.vehicleInspection)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final theme = Theme.of(context);
    final vehicle = inspection.vehicle;
    final labels = {
      'front': AppCopy.front,
      'back': AppCopy.back1a55ee,
      'left': AppCopy.left,
      'right': AppCopy.right,
      'damage': _departure ? AppCopy.existingDamage : AppCopy.newDamage
    };
    final enteredKm = int.tryParse(_mileage.text);
    final departureKm = inspection.departureReading?.mileage;

    return Scaffold(
      appBar: AppBar(
        title: AppText(
            _departure ? AppCopy.inspectionPickup : AppCopy.inspectionReturn),
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
          label: AppText(_saving ? AppCopy.saving : AppCopy.saveInspection),
        ),
      ),
      body: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppCard(
                child: Row(
                  children: [
                    SizedBox(
                      width: 72,
                      height: 56,
                      child: InspectionVehiclePhoto(
                        vehicle: vehicle,
                        iconSize: 28,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${vehicle.brand} ${vehicle.model}',
                              style: theme.textTheme.titleMedium),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              PlateBadge(vehicle.registrationNumber),
                              Text(inspection.contractNumber,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                      color: AppColors.textSecondary)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (inspection.departureReading != null) ...[
                const SizedBox(height: 12),
                AlertBanner(
                  tone: AppTone.info,
                  icon: Icons.compare_arrows,
                  title: AppCopy.pickupReading,
                  message: context.messages.departureReading(
                      (context.distance(inspection.departureReading!.mileage))
                          .toString(),
                      (inspection.departureReading!.fuelLevel).toString(),
                      context.tr((conditionName(
                              inspection.departureReading!.conditionStatus))
                          .toString())),
                ),
              ],
              const SizedBox(height: 16),
              FormSection(
                step: 1,
                title: AppCopy.vehicleReading,
                subtitle: _departure
                    ? AppCopy.whatYouObserveBeforeHandingOverTheKeys
                    : AppCopy.whatYouObserveAtReturn,
                children: [
                  TextFormField(
                    controller: _mileage,
                    keyboardType: TextInputType.number,
                    style: theme.textTheme.titleLarge,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: context.tr(_departure
                          ? AppCopy.mileageAtPickup
                          : AppCopy.mileageAtReturn),
                      suffixText: 'km',
                      prefixIcon: const Icon(Icons.speed_outlined),
                      helperText: departureKm != null &&
                              enteredKm != null &&
                              enteredKm >= departureKm
                          ? context.messages.distanceTravelled(
                              (context.distance(enteredKm - departureKm))
                                  .toString())
                          : null,
                      helperStyle: TextStyle(
                          color: AppTone.success.color,
                          fontWeight: FontWeight.w700),
                    ),
                    validator: (v) => int.tryParse(v ?? '') == null
                        ? AppCopy.mileageIsRequired
                        : null,
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppText(AppCopy.fuelLevel,
                          style: theme.textTheme.titleSmall),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final choice in _fuelChoices)
                            ChoiceChip(
                              label: AppText(choice.$2),
                              selected: _fuel == choice.$1,
                              onSelected: (_) =>
                                  setState(() => _fuel = choice.$1),
                            ),
                        ],
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppText(AppCopy.vehicleCondition,
                          style: theme.textTheme.titleSmall),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final value in const [
                            'good',
                            'check',
                            'damaged'
                          ])
                            ChoiceChip(
                              avatar: Icon(conditionIcon(value),
                                  size: 18, color: conditionTone(value).color),
                              label: AppText(conditionName(value)),
                              selected: _condition == value,
                              onSelected: (_) =>
                                  setState(() => _condition = value),
                            ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              FormSection(
                step: 2,
                title: AppCopy.photos,
                subtitle: context.messages.photosTaken(
                    (_photos.length).toString(), (labels.length).toString()),
                children: [
                  LayoutBuilder(builder: (context, constraints) {
                    const gap = 10.0;
                    final width = (constraints.maxWidth - gap) / 2;
                    return Wrap(
                      spacing: gap,
                      runSpacing: gap,
                      children: [
                        for (final entry in labels.entries)
                          SizedBox(
                            width: width,
                            height: width * 0.75,
                            child: _PhotoTile(
                              label: entry.value,
                              file: _photos[entry.key],
                              isDamage: entry.key == 'damage',
                              onTap: () => _photo(entry.key),
                            ),
                          ),
                      ],
                    );
                  }),
                ],
              ),
              const SizedBox(height: 16),
              FormSection(
                step: 3,
                title: _departure
                    ? AppCopy.existingDamagef545de
                    : AppCopy.newDamagefc6db9,
                subtitle: AppCopy.optionalDescribeScratchesDentsOrMissingItems,
                children: [
                  TextFormField(
                    controller: _notes,
                    maxLines: 3,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: context.tr(_departure
                          ? AppCopy.notesOnExistingDamage
                          : AppCopy.notesOnNewDamage),
                      alignLabelWithHint: true,
                    ),
                  ),
                  if (!_departure)
                    TextFormField(
                      controller: _charges,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: context.tr(AppCopy.additionalFees),
                        suffixText: 'MAD',
                        prefixIcon: const Icon(Icons.payments_outlined),
                        helperText:
                            context.tr(AppCopy.missingFuelCleaningRepair),
                      ),
                    ),
                ],
              ),
              if (_departure) ...[
                const SizedBox(height: 16),
                FormSection(
                  step: 4,
                  title: AppCopy.clientSignature,
                  subtitle: AppCopy.requiredToValidateThePickup,
                  children: [
                    if (_signature != null)
                      Container(
                        height: 90,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.outline),
                        ),
                        child: Image.memory(_signature!, fit: BoxFit.contain),
                      ),
                    OutlinedButton.icon(
                      onPressed: _sign,
                      icon: Icon(
                        _signature == null
                            ? Icons.draw_outlined
                            : Icons.check_circle,
                        color:
                            _signature == null ? null : AppTone.success.color,
                      ),
                      label: AppText(_signature == null
                          ? AppCopy.getTheClientSSignature
                          : AppCopy.signatureAddedRedo),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({
    required this.label,
    required this.file,
    required this.onTap,
    required this.isDamage,
  });

  final String label;
  final File? file;
  final VoidCallback onTap;
  final bool isDamage;

  @override
  Widget build(BuildContext context) {
    final taken = file != null;
    return Material(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: taken
            ? Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(file!, fit: BoxFit.cover),
                  Positioned(
                    left: 8,
                    bottom: 8,
                    child: StatusChip(
                      label: label,
                      tone: AppTone.success,
                      icon: Icons.check,
                      dense: true,
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isDamage
                        ? Icons.car_crash_outlined
                        : Icons.add_a_photo_outlined,
                    size: 30,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: 6),
                  AppText(label,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ],
              ),
      ),
    );
  }
}
