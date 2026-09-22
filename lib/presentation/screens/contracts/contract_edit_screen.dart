import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/format_utils.dart';
import '../../../data/models/chauffeur_model.dart';
import '../../../data/models/client_model.dart';
import '../../../data/models/contract_model.dart';
import '../../../data/models/vehicle_model.dart';
import '../../providers/chauffeur_provider.dart';
import '../../providers/client_provider.dart';
import '../../providers/contract_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/vehicle_provider.dart';
import '../../widgets/common/detail_row.dart';
import '../../widgets/common/form_section.dart';
import '../../widgets/common/plate_badge.dart';
import '../../widgets/common/status_badge.dart';
import '../../widgets/common/status_chip.dart';

/// Fixes a contract created by mistake: wrong vehicle, wrong client, wrong
/// dates or price. Reachable from [ContractDetailScreen] only while no PDF has
/// been prepared for the contract yet — [ContractRepository.updateContract]
/// enforces that same rule server-side (frozen terms), this screen just avoids
/// sending the operator through a form that would then fail.
///
/// Deliberately smaller than [ContractFormScreen]: existing clients only (no
/// inline creation, no OCR), and the amount already paid is shown but not
/// editable — it is owned by the payments table, not by this form.
class ContractEditScreen extends ConsumerStatefulWidget {
  const ContractEditScreen({super.key, required this.contract});

  final ContractModel contract;

  @override
  ConsumerState<ContractEditScreen> createState() => _ContractEditScreenState();
}

class _ContractEditScreenState extends ConsumerState<ContractEditScreen> {
  static const List<int> _allowedDurations = [1, 2, 3, 4, 5, 6, 7, 10, 15, 30];

  int? _vehicleId;
  int? _primaryDriverId;
  bool _hasSecondaryDriver = false;
  int? _secondaryDriverId;
  int? _chauffeurId;

  late DateTime _startDate;
  late DateTime _expectedReturnDate;
  late int _durationDays;

  late final TextEditingController _chauffeurHoursController;
  late final TextEditingController _dailyPriceController;
  late final TextEditingController _totalPriceController;
  late final TextEditingController _notesController;

  double _totalPrice = 0;
  bool _isSubmitting = false;
  String _clientSearch = '';
  String _secondaryClientSearch = '';

  @override
  void initState() {
    super.initState();
    final c = widget.contract;
    _vehicleId = c.vehicleId;
    _primaryDriverId = c.primaryDriverId;
    _hasSecondaryDriver = c.secondaryDriverId != null;
    _secondaryDriverId = c.secondaryDriverId;
    _chauffeurId = c.chauffeurId;
    _startDate = c.startDate;
    _expectedReturnDate = c.expectedReturnDate;
    _durationDays = _normalizeDurationDays(
        _expectedReturnDate.difference(_startDate).inDays);
    _totalPrice = c.totalPrice;

    _chauffeurHoursController = TextEditingController(
        text: c.chauffeurHours == 0 ? '' : _trimZeros(c.chauffeurHours));
    final chauffeurCost = c.chauffeurHours * c.chauffeurHourlyRate;
    final days = _durationDays < 1 ? 1 : _durationDays;
    final daily = (c.totalPrice - chauffeurCost) / days;
    _dailyPriceController =
        TextEditingController(text: daily <= 0 ? '' : daily.toStringAsFixed(2));
    _totalPriceController =
        TextEditingController(text: c.totalPrice.toStringAsFixed(2));
    _notesController = TextEditingController(text: c.notes ?? '');

    Future.microtask(() async {
      await ref.read(vehiclesProvider.notifier).loadVehicles();
      await ref.read(clientsProvider.notifier).loadClients();
      await ref.read(chauffeursProvider.notifier).load();
    });
  }

  @override
  void dispose() {
    _chauffeurHoursController.dispose();
    _dailyPriceController.dispose();
    _totalPriceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  static int _normalizeDurationDays(int days) {
    final d = days <= 0 ? 1 : days;
    if (_allowedDurations.contains(d)) return d;
    var closest = _allowedDurations.first;
    var bestDiff = (closest - d).abs();
    for (final v in _allowedDurations) {
      final diff = (v - d).abs();
      if (diff < bestDiff) {
        closest = v;
        bestDiff = diff;
      }
    }
    return closest;
  }

  static String _trimZeros(double v) =>
      v % 1 == 0 ? v.toStringAsFixed(0) : v.toString();

  void _recomputeTotal(ChauffeurModel? chauffeur) {
    final dailyPrice = double.tryParse(_dailyPriceController.text) ?? 0;
    final hours = double.tryParse(_chauffeurHoursController.text) ?? 0;
    final total =
        dailyPrice * _durationDays + (chauffeur?.hourlyRate ?? 0) * hours;
    setState(() {
      _totalPrice = total;
      _totalPriceController.text = total == 0 ? '' : total.toStringAsFixed(2);
    });
  }

  Future<void> _pickStartDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
        context: context, initialTime: TimeOfDay.fromDateTime(_startDate));
    if (time == null || !mounted) return;
    setState(() {
      _startDate =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
      if (!_expectedReturnDate.isAfter(_startDate)) {
        _expectedReturnDate = _startDate.add(const Duration(days: 1));
      }
      _durationDays = _normalizeDurationDays(
          _expectedReturnDate.difference(_startDate).inDays);
    });
  }

  Future<void> _pickReturnDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _expectedReturnDate,
      firstDate: _startDate,
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_expectedReturnDate));
    if (time == null || !mounted) return;
    setState(() {
      _expectedReturnDate =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
      _durationDays = _normalizeDurationDays(
          _expectedReturnDate.difference(_startDate).inDays);
    });
  }

  void _warn(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  String _friendly(Object e) => 'Erreur : ${e.toString().replaceFirst(
        RegExp(r'^(Exception|Bad state): '),
        '',
      )}';

  Future<void> _submit(List<ChauffeurModel> chauffeurs) async {
    if (_isSubmitting) return;
    if (_vehicleId == null) {
      _warn('Sélectionnez un véhicule.');
      return;
    }
    if (_primaryDriverId == null) {
      _warn('Sélectionnez un conducteur principal.');
      return;
    }
    if (_hasSecondaryDriver && _secondaryDriverId == null) {
      _warn('Sélectionnez un conducteur secondaire, ou désactivez l’option.');
      return;
    }
    final total = double.tryParse(_totalPriceController.text) ?? _totalPrice;
    if (total <= 0) {
      _warn('Le prix total doit être supérieur à 0.');
      return;
    }

    setState(() => _isSubmitting = true);
    final chauffeur = _findChauffeur(chauffeurs, _chauffeurId);
    final original = widget.contract;
    final updated = ContractModel(
      id: original.id,
      contractNumber: original.contractNumber,
      vehicleId: _vehicleId!,
      primaryDriverId: _primaryDriverId!,
      secondaryDriverId: _hasSecondaryDriver ? _secondaryDriverId : null,
      chauffeurId: _chauffeurId,
      chauffeurHours: double.tryParse(_chauffeurHoursController.text) ?? 0,
      chauffeurHourlyRate: chauffeur?.hourlyRate ?? 0,
      startDate: _startDate,
      expectedReturnDate: _expectedReturnDate,
      actualReturnDate: original.actualReturnDate,
      totalPrice: total,
      amountPaid: original.amountPaid,
      status: original.status,
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      createdAt: original.createdAt,
      updatedAt: DateTime.now(),
    );

    try {
      await ref.read(contractsProvider.notifier).updateContract(updated);
      await ref.read(dashboardProvider.notifier).refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.successSaved)),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_friendly(e))));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  static VehicleModel? _findVehicle(List<VehicleModel> list, int? id) {
    if (id == null) return null;
    for (final v in list) {
      if (v.id == id) return v;
    }
    return null;
  }

  static ClientModel? _findClient(List<ClientModel> list, int? id) {
    if (id == null) return null;
    for (final c in list) {
      if (c.id == id) return c;
    }
    return null;
  }

  static ChauffeurModel? _findChauffeur(List<ChauffeurModel> list, int? id) {
    if (id == null) return null;
    for (final c in list) {
      if (c.id == id) return c;
    }
    return null;
  }

  static List<ClientModel> _filterClients(
      List<ClientModel> clients, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return clients;
    return clients
        .where((c) =>
            c.fullName.toLowerCase().contains(q) ||
            c.cin.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final vehiclesAsync = ref.watch(vehiclesProvider);
    final clientsAsync = ref.watch(clientsProvider);
    final chauffeurs =
        ref.watch(chauffeursProvider).value ?? const <ChauffeurModel>[];

    return Scaffold(
      appBar: AppBar(title: Text('Modifier ${widget.contract.contractNumber}')),
      body: vehiclesAsync.when(
        data: (vehicles) => clientsAsync.when(
          data: (clients) => _buildForm(context, vehicles, clients, chauffeurs),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('Erreur : $error')),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Erreur : $error')),
      ),
      bottomNavigationBar: BottomActionBar(
        child: FilledButton.icon(
          onPressed: _isSubmitting ? null : () => _submit(chauffeurs),
          icon: _isSubmitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.check_circle_outline),
          label: Text(_isSubmitting
              ? 'Enregistrement...'
              : 'Enregistrer les modifications'),
        ),
      ),
    );
  }

  Widget _buildForm(
    BuildContext context,
    List<VehicleModel> vehicles,
    List<ClientModel> clients,
    List<ChauffeurModel> chauffeurs,
  ) {
    final theme = Theme.of(context);

    // The vehicle/chauffeur currently on this contract stay selectable even
    // if they're not 'available' — they're rented/assigned by this very
    // contract, not free for someone else to pick.
    final vehicleOptions = [
      for (final v in vehicles)
        if (v.status == 'available' || v.id == _vehicleId) v,
    ];
    final vehicle = _findVehicle(vehicleOptions, _vehicleId);

    final filteredClients = _filterClients(clients, _clientSearch);
    final primary = _findClient(clients, _primaryDriverId);
    final secondaryOptions = _filterClients(clients, _secondaryClientSearch)
        .where((c) => c.id != _primaryDriverId)
        .toList();

    final chauffeurOptions = [
      for (final c in chauffeurs)
        if (c.status == 'available' || c.id == _chauffeurId) c,
    ];
    final chauffeur = _findChauffeur(chauffeurOptions, _chauffeurId);

    final liveTotal =
        double.tryParse(_totalPriceController.text) ?? _totalPrice;
    final remaining = liveTotal - widget.contract.amountPaid;

    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FormSection(
                icon: Icons.directions_car_outlined,
                title: 'Véhicule',
                children: [
                  DropdownButtonFormField<int>(
                    isExpanded: true,
                    value: vehicle?.id,
                    items: [
                      for (final v in vehicleOptions)
                        DropdownMenuItem(
                          value: v.id,
                          child: Text(
                            '${v.brand} ${v.model} · ${v.registrationNumber}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (id) => setState(() => _vehicleId = id),
                    decoration: const InputDecoration(
                      labelText: 'Véhicule',
                      prefixIcon: Icon(Icons.directions_car_outlined),
                    ),
                  ),
                  if (vehicle != null)
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        PlateBadge(vehicle.registrationNumber),
                        StatusBadge(text: vehicle.status),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 16),
              FormSection(
                icon: Icons.person_outline,
                title: 'Conducteur principal',
                children: [
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Rechercher un client',
                      hintText: 'Nom ou CIN',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (v) => setState(() => _clientSearch = v),
                  ),
                  DropdownButtonFormField<int>(
                    isExpanded: true,
                    value: filteredClients.any((c) => c.id == _primaryDriverId)
                        ? _primaryDriverId
                        : null,
                    items: [
                      for (final c in filteredClients)
                        DropdownMenuItem(
                          value: c.id,
                          child: Text('${c.fullName} (${c.cin})',
                              overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: (id) => setState(() {
                      _primaryDriverId = id;
                      if (_secondaryDriverId == id) _secondaryDriverId = null;
                    }),
                    decoration: const InputDecoration(labelText: 'Client'),
                  ),
                  if (primary != null)
                    StatusChip(
                        label: primary.phone,
                        icon: Icons.phone_outlined,
                        dense: true),
                ],
              ),
              const SizedBox(height: 16),
              FormSection(
                icon: Icons.person_add_alt_outlined,
                title: 'Conducteur secondaire',
                subtitle: 'Optionnel',
                trailing: Switch(
                  value: _hasSecondaryDriver,
                  onChanged: (v) => setState(() {
                    _hasSecondaryDriver = v;
                    if (!v) _secondaryDriverId = null;
                  }),
                ),
                children: _hasSecondaryDriver
                    ? [
                        TextFormField(
                          decoration: const InputDecoration(
                            labelText: 'Rechercher un conducteur secondaire',
                            hintText: 'Nom ou CIN',
                            prefixIcon: Icon(Icons.search),
                          ),
                          onChanged: (v) =>
                              setState(() => _secondaryClientSearch = v),
                        ),
                        DropdownButtonFormField<int?>(
                          isExpanded: true,
                          value: secondaryOptions
                                  .any((c) => c.id == _secondaryDriverId)
                              ? _secondaryDriverId
                              : null,
                          items: [
                            const DropdownMenuItem<int?>(
                                value: null, child: Text('Aucun')),
                            for (final c in secondaryOptions)
                              DropdownMenuItem<int?>(
                                value: c.id,
                                child: Text('${c.fullName} (${c.cin})',
                                    overflow: TextOverflow.ellipsis),
                              ),
                          ],
                          onChanged: (id) =>
                              setState(() => _secondaryDriverId = id),
                          decoration: const InputDecoration(
                              labelText: 'Conducteur secondaire'),
                        ),
                      ]
                    : const [],
              ),
              const SizedBox(height: 16),
              FormSection(
                icon: Icons.badge_outlined,
                title: 'Chauffeur de l’agence',
                subtitle: 'Optionnel',
                children: [
                  DropdownButtonFormField<int?>(
                    isExpanded: true,
                    value: chauffeurOptions.any((c) => c.id == _chauffeurId)
                        ? _chauffeurId
                        : null,
                    items: [
                      const DropdownMenuItem<int?>(
                          value: null, child: Text('Sans chauffeur')),
                      for (final c in chauffeurOptions)
                        DropdownMenuItem<int?>(
                          value: c.id,
                          child: Text(
                            '${c.fullName} — ${formatMad(c.hourlyRate)}/h',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (id) => setState(() {
                      _chauffeurId = id;
                      _recomputeTotal(_findChauffeur(chauffeurOptions, id));
                    }),
                    decoration: const InputDecoration(labelText: 'Chauffeur'),
                  ),
                  if (chauffeur != null)
                    TextFormField(
                      controller: _chauffeurHoursController,
                      decoration: const InputDecoration(
                        labelText: 'Nombre d’heures chauffeur',
                        prefixIcon: Icon(Icons.schedule),
                      ),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => _recomputeTotal(chauffeur),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              FormSection(
                icon: Icons.event_outlined,
                title: 'Période de location',
                subtitle: 'Durée : $_durationDays jour(s)',
                children: [
                  _DateTile(
                    label: 'Début',
                    value: formatDateTime(_startDate),
                    onTap: _pickStartDate,
                  ),
                  _DateTile(
                    label: 'Retour prévu',
                    value: formatDateTime(_expectedReturnDate),
                    onTap: _pickReturnDate,
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final d in _allowedDurations)
                        ChoiceChip(
                          label: Text('$d j'),
                          selected: _durationDays == d,
                          onSelected: (_) => setState(() {
                            _durationDays = d;
                            _expectedReturnDate =
                                _startDate.add(Duration(days: d));
                            _recomputeTotal(chauffeur);
                          }),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              FormSection(
                icon: Icons.sell_outlined,
                title: 'Prix',
                children: [
                  TextFormField(
                    controller: _dailyPriceController,
                    decoration: const InputDecoration(
                      labelText: 'Prix par jour',
                      suffixText: 'MAD',
                      prefixIcon: Icon(Icons.sell_outlined),
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => _recomputeTotal(chauffeur),
                  ),
                  TextFormField(
                    controller: _totalPriceController,
                    decoration: const InputDecoration(
                      labelText: 'Prix total du contrat',
                      suffixText: 'MAD',
                      prefixIcon: Icon(Icons.calculate_outlined),
                      helperText:
                          'Calculé automatiquement, modifiable à la main.',
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (value) => setState(() {
                      _totalPrice = double.tryParse(value) ?? _totalPrice;
                      if (_durationDays > 0 && value.isNotEmpty) {
                        final daily = _totalPrice / _durationDays;
                        _dailyPriceController.text = daily.toStringAsFixed(2);
                      }
                    }),
                  ),
                  DetailRow(
                    icon: Icons.payments_outlined,
                    label: 'Déjà payé',
                    value: formatMad(widget.contract.amountPaid),
                    trailing: Text(
                      'Reste ${formatMad(remaining < 0 ? 0 : remaining)}',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Text(
                    'Pour enregistrer un versement, utilisez « Ajouter un '
                    'paiement » sur la fiche du contrat.',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              FormSection(
                icon: Icons.notes_outlined,
                title: 'Notes',
                subtitle: 'Optionnel',
                children: [
                  TextFormField(
                    controller: _notesController,
                    maxLines: 3,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Notes internes',
                      alignLabelWithHint: true,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DateTile extends StatelessWidget {
  const _DateTile({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.event_outlined),
          suffixIcon: const Icon(Icons.edit_calendar_outlined),
        ),
        child: Text(
          value,
          style: Theme.of(context)
              .textTheme
              .bodyLarge
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
