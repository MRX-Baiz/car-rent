import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/format_utils.dart';
import '../../../core/utils/vehicle_labels.dart';
import '../../widgets/common/alert_banner.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/form_section.dart';
import '../../widgets/common/plate_badge.dart';
import '../../widgets/common/status_chip.dart';
import '../../widgets/common/vehicle_photo.dart';
import '../../../data/models/contract_model.dart';
import '../../../data/models/inspection_model.dart';
import '../../../data/models/vehicle_model.dart';
import '../../../data/repositories/contract_repository.dart';
import '../../../data/repositories/vehicle_repository.dart';
import '../../../data/repositories/inspection_repository.dart';
import 'client_signature_screen.dart';

class InspectionFormScreen extends StatefulWidget {
  const InspectionFormScreen(
      {super.key, required this.contractId, required this.type});
  final int contractId;
  final String type;
  @override
  State<InspectionFormScreen> createState() => _InspectionFormScreenState();
}

class _InspectionFormScreenState extends State<InspectionFormScreen> {
  final _form = GlobalKey<FormState>();
  final _mileage = TextEditingController();
  final _notes = TextEditingController();
  final _charges = TextEditingController();
  ContractModel? _contract;
  InspectionModel? _departureReading;
  VehicleModel? _vehicle;
  String _condition = 'good';
  int _fuel = 100;
  final Map<String, File> _photos = {};
  Uint8List? _signature;
  bool _saving = false;
  bool get _departure => widget.type == 'departure';
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
    final contract =
        await ContractRepository.instance.getContractById(widget.contractId);
    if (contract == null) return;
    final vehicle =
        await VehicleRepository.instance.getVehicleById(contract.vehicleId);
    final departure = widget.type == 'departure'
        ? null
        : await InspectionRepository.instance
            .get(widget.contractId, 'departure');
    if (!mounted) return;
    setState(() {
      _departureReading = departure;
      _contract = contract;
      _vehicle = vehicle;
      _mileage.text = vehicle?.currentMileage.toString() ?? '0';
      _condition = vehicle?.conditionStatus ?? 'good';
      _fuel = vehicle?.fuelLevel ?? 100;
    });
  }

  Future<void> _photo(String key) async {
    final source = await showModalBottomSheet<ImageSource>(
        context: context,
        builder: (c) => SafeArea(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
              ListTile(
                  leading: const Icon(Icons.camera_alt),
                  title: const Text('Prendre une photo'),
                  onTap: () => Navigator.pop(c, ImageSource.camera)),
              ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: const Text('Choisir depuis le téléphone'),
                  onTap: () => Navigator.pop(c, ImageSource.gallery))
            ])));
    if (source == null) return;
    final file =
        await ImagePicker().pickImage(source: source, imageQuality: 85);
    if (file != null && mounted) setState(() => _photos[key] = File(file.path));
  }

  Future<void> _sign() async {
    final value = await Navigator.of(context).push<Uint8List>(MaterialPageRoute(
        builder: (_) => ClientSignatureScreen(
            clientName: 'Signature pour l’état des lieux')));
    if (value != null && mounted) setState(() => _signature = value);
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate() ||
        _saving ||
        _contract == null ||
        _vehicle == null) return;
    if (_departure && _signature == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('La signature du client est requise au départ.')));
      return;
    }
    setState(() => _saving = true);
    try {
      await InspectionRepository.instance.save(
          inspection: InspectionModel(
              contractId: widget.contractId,
              type: widget.type,
              mileage: int.parse(_mileage.text),
              fuelLevel: _fuel,
              conditionStatus: _condition,
              damageNotes:
                  _notes.text.trim().isEmpty ? null : _notes.text.trim(),
              extraCharges: double.tryParse(_charges.text) ?? 0,
              createdAt: DateTime.now()),
          photos: _photos,
          signature: _signature);
      final updated = _vehicle!.copyWith(
          currentMileage: int.parse(_mileage.text),
          fuelLevel: _fuel,
          conditionStatus: _condition,
          updatedAt: DateTime.now());
      await VehicleRepository.instance.updateVehicle(updated);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('État des lieux enregistré.')));
        context.pop();
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erreur : $e')));
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
    if (_contract == null || _vehicle == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('État des lieux')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final theme = Theme.of(context);
    final vehicle = _vehicle!;
    final labels = {
      'front': 'Avant',
      'back': 'Arrière',
      'left': 'Gauche',
      'right': 'Droite',
      'damage': _departure ? 'Dégât existant' : 'Nouveau dégât'
    };
    final enteredKm = int.tryParse(_mileage.text);
    final departureKm = _departureReading?.mileage;

    return Scaffold(
      appBar: AppBar(
        title: Text(
            _departure ? 'État des lieux · départ' : 'État des lieux · retour'),
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
          label: Text(
              _saving ? 'Enregistrement...' : 'Enregistrer l’état des lieux'),
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
                      child: VehiclePhoto(vehicle: vehicle, iconSize: 28),
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
                              Text(_contract!.contractNumber,
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
              if (_departureReading != null) ...[
                const SizedBox(height: 12),
                AlertBanner(
                  tone: AppTone.info,
                  icon: Icons.compare_arrows,
                  title: 'Relevé au départ',
                  message:
                      '${formatKm(_departureReading!.mileage ?? 0)} · carburant '
                      '${_departureReading!.fuelLevel} % · '
                      '${conditionName(_departureReading!.conditionStatus)}',
                ),
              ],
              const SizedBox(height: 16),
              FormSection(
                step: 1,
                title: 'Relevé du véhicule',
                subtitle: _departure
                    ? 'Ce que vous constatez avant la remise des clés.'
                    : 'Ce que vous constatez au retour.',
                children: [
                  TextFormField(
                    controller: _mileage,
                    keyboardType: TextInputType.number,
                    style: theme.textTheme.titleLarge,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: _departure
                          ? 'Kilométrage au départ'
                          : 'Kilométrage au retour',
                      suffixText: 'km',
                      prefixIcon: const Icon(Icons.speed_outlined),
                      helperText: departureKm != null &&
                              enteredKm != null &&
                              enteredKm >= departureKm
                          ? '${formatKm(enteredKm - departureKm)} parcourus'
                          : null,
                      helperStyle: TextStyle(
                          color: AppTone.success.color,
                          fontWeight: FontWeight.w700),
                    ),
                    validator: (v) => int.tryParse(v ?? '') == null
                        ? 'Kilométrage requis.'
                        : null,
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Niveau de carburant',
                          style: theme.textTheme.titleSmall),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final choice in _fuelChoices)
                            ChoiceChip(
                              label: Text(choice.$2),
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
                      Text('État du véhicule',
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
                              label: Text(conditionName(value)),
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
                title: 'Photos',
                subtitle:
                    '${_photos.length}/${labels.length} prises · touchez une case pour photographier.',
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
                title: _departure ? 'Dégâts existants' : 'Nouveaux dégâts',
                subtitle:
                    'Optionnel. Décrivez rayures, chocs ou éléments manquants.',
                children: [
                  TextFormField(
                    controller: _notes,
                    maxLines: 3,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: _departure
                          ? 'Notes sur les dégâts existants'
                          : 'Notes sur les nouveaux dégâts',
                      alignLabelWithHint: true,
                    ),
                  ),
                  if (!_departure)
                    TextFormField(
                      controller: _charges,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Frais supplémentaires',
                        suffixText: 'MAD',
                        prefixIcon: Icon(Icons.payments_outlined),
                        helperText:
                            'Carburant manquant, nettoyage, réparation…',
                      ),
                    ),
                ],
              ),
              if (_departure) ...[
                const SizedBox(height: 16),
                FormSection(
                  step: 4,
                  title: 'Signature du client',
                  subtitle: 'Obligatoire pour valider le départ.',
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
                      label: Text(_signature == null
                          ? 'Faire signer le client'
                          : 'Signature ajoutée · refaire'),
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
                  Text(label,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ],
              ),
      ),
    );
  }
}
