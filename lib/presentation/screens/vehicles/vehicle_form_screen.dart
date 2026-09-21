import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/storage/media_store.dart';
import '../../../data/models/vehicle_model.dart';
import '../../providers/vehicle_provider.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_text_field.dart';
import 'vehicle_form_date_field.dart';

class VehicleFormScreen extends ConsumerStatefulWidget {
  const VehicleFormScreen({
    super.key,
    this.vehicle,
  });

  final VehicleModel? vehicle;

  @override
  ConsumerState<VehicleFormScreen> createState() => _VehicleFormScreenState();
}

class _VehicleFormScreenState extends ConsumerState<VehicleFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _brandController;
  late final TextEditingController _modelController;
  late final TextEditingController _registrationController;
  late final TextEditingController _yearController;
  late final TextEditingController _mileageController;
  late final TextEditingController _oilMileageController;
  late final TextEditingController _distributionMileageController;

  String _status = 'available';
  String _transmission = 'manual';
  String _fuelType = 'petrol';
  String _condition = 'good';
  int _fuelLevel = 100;
  DateTime? _insuranceExpiry;
  DateTime? _technicalExpiry;
  DateTime? _vignetteDue;
  DateTime? _oilDue;
  DateTime? _distributionDue;
  File? _imageFile;

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final v = widget.vehicle;
    _brandController = TextEditingController(text: v?.brand ?? '');
    _modelController = TextEditingController(text: v?.model ?? '');
    _registrationController =
        TextEditingController(text: v?.registrationNumber ?? '');
    _yearController = TextEditingController(text: v?.year.toString() ?? '');
    _mileageController =
        TextEditingController(text: v?.currentMileage.toString() ?? '0');
    _oilMileageController =
        TextEditingController(text: v?.oilChangeDueMileage?.toString() ?? '');
    _distributionMileageController = TextEditingController(
        text: v?.distributionDueMileage?.toString() ?? '');
    _status = v?.status ?? 'available';
    _transmission = v?.transmission ?? 'manual';
    _fuelType = v?.fuelType ?? 'petrol';
    _condition = v?.conditionStatus ?? 'good';
    _fuelLevel = v?.fuelLevel ?? 100;
    _insuranceExpiry = v?.insuranceExpiryDate;
    _technicalExpiry = v?.technicalInspectionExpiryDate;
    _vignetteDue = v?.vignetteDueDate;
    _oilDue = v?.oilChangeDueDate;
    _distributionDue = v?.distributionDueDate;
  }

  @override
  void dispose() {
    _brandController.dispose();
    _modelController.dispose();
    _registrationController.dispose();
    _yearController.dispose();
    _mileageController.dispose();
    _oilMileageController.dispose();
    _distributionMileageController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _imageFile = File(picked.path);
      });
    }
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final year = int.parse(_yearController.text.trim());
      final now = DateTime.now();

      final imageBytes = _imageFile != null
          ? await _imageFile!.readAsBytes()
          : widget.vehicle?.imageBytes;

      final vehicle = VehicleModel(
        id: widget.vehicle?.id,
        brand: _brandController.text.trim(),
        model: _modelController.text.trim(),
        registrationNumber: _registrationController.text.trim(),
        year: year,
        status: _status,
        // The photo itself lives in image_blob, so a vehicle survived the
        // temp-path bug. Route the path through the media store anyway: it is
        // the display fallback, and a dangling one shows a broken thumbnail.
        imagePath: _imageFile == null
            ? widget.vehicle?.imagePath
            : await MediaStore.instance.save(_imageFile!, prefix: 'vehicule'),
        imageBytes: imageBytes,
        transmission: _transmission, fuelType: _fuelType,
        conditionStatus: _condition,
        currentMileage: int.tryParse(_mileageController.text.trim()) ?? 0,
        fuelLevel: _fuelLevel,
        insuranceExpiryDate: _insuranceExpiry,
        technicalInspectionExpiryDate: _technicalExpiry,
        vignetteDueDate: _vignetteDue, oilChangeDueDate: _oilDue,
        oilChangeDueMileage: int.tryParse(_oilMileageController.text.trim()),
        distributionDueDate: _distributionDue,
        distributionDueMileage:
            int.tryParse(_distributionMileageController.text.trim()),
        createdAt: widget.vehicle?.createdAt ?? now,
        updatedAt: now,
      );

      final notifier = ref.read(vehiclesProvider.notifier);

      if (widget.vehicle == null) {
        await notifier.addVehicle(vehicle);
      } else {
        await notifier.updateVehicle(vehicle);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.successSaved)),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Erreur lors de l’enregistrement du véhicule.\n'
            'حدث خطأ أثناء حفظ السيارة.\n'
            'Vehicle save error: $e',
          ),
        ),
      );
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
    final isEditing = widget.vehicle != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Modifier un véhicule' : 'Nouveau véhicule'),
      ),
      body: SingleChildScrollView(
        // Pad past the system navigation bar so the last control is
        // not trapped under the phone's back/home buttons.
        padding: EdgeInsets.fromLTRB(
            16, 16, 16, 16 + MediaQuery.viewPaddingOf(context).bottom),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: theme.colorScheme.surfaceContainerHighest,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: _imageFile != null
                          ? Image.file(
                              _imageFile!,
                              fit: BoxFit.cover,
                            )
                          : (widget.vehicle?.imageBytes != null
                              ? Image.memory(
                                  widget.vehicle!.imageBytes!,
                                  fit: BoxFit.cover,
                                )
                              : (MediaStore.instance.resolveFile(
                                          widget.vehicle?.imagePath) !=
                                      null
                                  ? Image.file(
                                      MediaStore.instance.resolveFile(
                                          widget.vehicle?.imagePath)!,
                                      fit: BoxFit.cover,
                                    )
                                  : Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.directions_car_filled,
                                            size: 48,
                                            color: theme.colorScheme.onSurface
                                                .withValues(alpha: 0.4),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Aucune photo',
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                              color: theme.colorScheme.onSurface
                                                  .withValues(alpha: 0.4),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ))),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton.icon(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.add_a_photo),
                      label: Text(_imageFile == null &&
                              widget.vehicle?.imagePath == null
                          ? 'Ajouter une photo'
                          : 'Modifier la photo'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    controller: _brandController,
                    label: 'Marque',
                    prefixIcon: Icons.directions_car,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'La marque est requise.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                      controller: _mileageController,
                      label: 'Kilométrage actuel',
                      keyboardType: TextInputType.number,
                      prefixIcon: Icons.speed,
                      validator: (v) => (int.tryParse(v ?? '') ?? -1) < 0
                          ? 'Kilométrage invalide.'
                          : null),
                  const SizedBox(height: 16),
                  Text('Caractéristiques',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                      value: _transmission,
                      decoration:
                          const InputDecoration(labelText: 'Boîte de vitesses'),
                      items: const [
                        DropdownMenuItem(
                            value: 'manual', child: Text('Manuelle')),
                        DropdownMenuItem(
                            value: 'automatic', child: Text('Automatique'))
                      ],
                      onChanged: (v) => setState(() => _transmission = v!)),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                      value: _fuelType,
                      decoration: const InputDecoration(labelText: 'Carburant'),
                      items: const [
                        DropdownMenuItem(
                            value: 'petrol', child: Text('Essence')),
                        DropdownMenuItem(
                            value: 'diesel', child: Text('Diesel')),
                        DropdownMenuItem(
                            value: 'hybrid', child: Text('Hybride')),
                        DropdownMenuItem(
                            value: 'electric', child: Text('Électrique')),
                        DropdownMenuItem(value: 'lpg', child: Text('GPL'))
                      ],
                      onChanged: (v) => setState(() => _fuelType = v!)),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                      value: _condition,
                      decoration:
                          const InputDecoration(labelText: 'État général'),
                      items: const [
                        DropdownMenuItem(
                            value: 'good', child: Text('Bon état')),
                        DropdownMenuItem(
                            value: 'check', child: Text('À contrôler')),
                        DropdownMenuItem(
                            value: 'damaged', child: Text('Endommagé'))
                      ],
                      onChanged: (v) => setState(() => _condition = v!)),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                      value: _fuelLevel,
                      decoration: const InputDecoration(
                          labelText: 'Niveau de carburant'),
                      items: const [0, 25, 50, 75, 100]
                          .map((value) => DropdownMenuItem(
                              value: value, child: Text('$value%')))
                          .toList(),
                      onChanged: (v) => setState(() => _fuelLevel = v!)),
                  const SizedBox(height: 20),
                  Text('Documents et entretien',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  VehicleDateField(
                      label: 'Assurance : date d’expiration',
                      value: _insuranceExpiry,
                      onChanged: (v) => setState(() => _insuranceExpiry = v)),
                  VehicleDateField(
                      label: 'Visite technique : date d’expiration',
                      value: _technicalExpiry,
                      onChanged: (v) => setState(() => _technicalExpiry = v)),
                  VehicleDateField(
                      label: 'Vignette : date limite',
                      value: _vignetteDue,
                      onChanged: (v) => setState(() => _vignetteDue = v)),
                  VehicleDateField(
                      label: 'Vidange : prochaine date',
                      value: _oilDue,
                      onChanged: (v) => setState(() => _oilDue = v)),
                  AppTextField(
                      controller: _oilMileageController,
                      label: 'Vidange : prochain kilométrage',
                      keyboardType: TextInputType.number,
                      prefixIcon: Icons.oil_barrel),
                  const SizedBox(height: 12),
                  VehicleDateField(
                      label: 'Courroie / chaîne : prochaine date',
                      value: _distributionDue,
                      onChanged: (v) => setState(() => _distributionDue = v)),
                  AppTextField(
                      controller: _distributionMileageController,
                      label: 'Courroie / chaîne : prochain kilométrage',
                      keyboardType: TextInputType.number,
                      prefixIcon: Icons.settings),
                  const SizedBox(height: 12),
                  AppTextField(
                    controller: _modelController,
                    label: 'Modèle',
                    prefixIcon: Icons.directions_car_filled,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Le modèle est requis.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    controller: _registrationController,
                    label: 'Immatriculation',
                    prefixIcon: Icons.numbers,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'L’immatriculation est requise.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    controller: _yearController,
                    label: 'Année',
                    keyboardType: TextInputType.number,
                    prefixIcon: Icons.calendar_today,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'L’année est requise.';
                      }
                      final year = int.tryParse(value);
                      if (year == null || year < 1920 || year > 2100) {
                        return 'Année invalide.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _status,
                    items: const [
                      DropdownMenuItem(
                        value: 'available',
                        child: Text('Disponible'),
                      ),
                      DropdownMenuItem(
                        value: 'rented',
                        child: Text('Loué'),
                      ),
                      DropdownMenuItem(
                        value: 'maintenance',
                        child: Text('Maintenance'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _status = value;
                        });
                      }
                    },
                    decoration: const InputDecoration(
                      labelText: 'Statut',
                    ),
                  ),
                  const SizedBox(height: 24),
                  AppButton(
                    label: isEditing ? 'Enregistrer' : 'Créer',
                    icon: Icons.save,
                    isLoading: _isSubmitting,
                    onPressed: _submit,
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
