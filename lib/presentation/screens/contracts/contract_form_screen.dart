import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/notifications/notification_service.dart';
import '../../../data/models/contract_model.dart';
import '../../../data/models/vehicle_model.dart';
import '../../../data/models/client_model.dart';
import '../../../data/repositories/contract_repository.dart';
import '../../providers/contract_provider.dart';
import '../../providers/vehicle_provider.dart';
import '../../providers/client_provider.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/empty_state_widget.dart';

class ContractFormScreen extends ConsumerStatefulWidget {
  const ContractFormScreen({super.key});

  @override
  ConsumerState<ContractFormScreen> createState() =>
      _ContractFormScreenState();
}

class _ContractFormScreenState extends ConsumerState<ContractFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final DateFormat _dateFormatter = DateFormat('dd/MM/yyyy HH:mm');

  VehicleModel? _selectedVehicle;
  ClientModel? _primaryDriver;
  ClientModel? _secondaryDriver;

  DateTime _startDate = DateTime.now();
  DateTime _expectedReturnDate = DateTime.now().add(const Duration(days: 1));
  int _durationDays = 1;

  double _amountPaid = 0;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ref.read(vehiclesProvider.notifier).loadVehicles();
      await ref.read(clientsProvider.notifier).loadClients();
    });
  }

  int get _rentalDays {
    final diff = _expectedReturnDate.difference(_startDate).inDays;
    return diff <= 0 ? 1 : diff;
  }

  double get _totalPrice {
    final vehicle = _selectedVehicle;
    if (vehicle == null) return 0;
    return vehicle.dailyPrice * _rentalDays;
  }

  double get _remaining => _totalPrice - _amountPaid;

  Future<void> _pickStartDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );
    if (date == null) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_startDate),
    );
    if (time == null) return;
    setState(() {
      _startDate = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
      if (!_expectedReturnDate.isAfter(_startDate)) {
        _expectedReturnDate = _startDate.add(const Duration(days: 1));
      }
    });
  }

  Future<void> _pickExpectedReturnDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _expectedReturnDate,
      firstDate: _startDate,
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );
    if (date == null) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_expectedReturnDate),
    );
    if (time == null) return;
    setState(() {
      _expectedReturnDate = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
      // Keep duration in sync when the end date is adjusted manually.
      final diff = _expectedReturnDate.difference(_startDate).inDays;
      _durationDays = diff <= 0 ? 1 : diff;
    });
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    if (_selectedVehicle == null || _primaryDriver == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Veuillez sélectionner un véhicule et un conducteur principal.\n'
            'المرجو اختيار سيارة وسائق رئيسي.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final repo = ContractRepository.instance;
      final contractNumber = await repo.generateContractNumber();
      final now = DateTime.now();

      final contract = ContractModel(
        id: null,
        contractNumber: contractNumber,
        vehicleId: _selectedVehicle!.id!,
        primaryDriverId: _primaryDriver!.id!,
        secondaryDriverId: _secondaryDriver?.id,
        startDate: _startDate,
        expectedReturnDate: _expectedReturnDate,
        actualReturnDate: null,
        totalPrice: _totalPrice,
        amountPaid: _amountPaid,
        status: 'active',
        notes: null,
        createdAt: now,
        updatedAt: now,
      );

      final newId = await repo.insertContract(contract);
      await ref.read(contractsProvider.notifier).loadContracts();

      await NotificationService.instance.scheduleReturnReminder(
        contractId: newId,
        registrationNumber: _selectedVehicle!.registrationNumber,
        returnDate: _expectedReturnDate,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.successSaved)),
      );
      context.go('/contracts');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Erreur lors de la création du contrat.\n'
            'حدث خطأ أثناء إنشاء العقد.\n'
            'Contract creation error: $e',
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
    final vehiclesAsync = ref.watch(vehiclesProvider);
    final clientsAsync = ref.watch(clientsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nouveau contrat'),
      ),
      body: vehiclesAsync.when(
        data: (vehicles) {
          final availableVehicles =
              vehicles.where((v) => v.status == 'available').toList();

          if (availableVehicles.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: EmptyStateWidget(
                title: 'Aucun véhicule disponible.',
                subtitle:
                    'Ajoutez un véhicule ou libérez un contrat existant.',
                icon: Icons.directions_car_filled_outlined,
              ),
            );
          }

          return clientsAsync.when(
            data: (clients) {
              if (clients.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: EmptyStateWidget(
                    title: 'Aucun client enregistré.',
                    subtitle:
                        'Ajoutez un client avant de créer un contrat.',
                    icon: Icons.person_outline,
                  ),
                );
              }

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 800),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            '1. Véhicule',
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<VehicleModel>(
                            value: _selectedVehicle,
                            items: availableVehicles
                                .map(
                                  (v) => DropdownMenuItem(
                                    value: v,
                                    child: Text(
                                      '${v.brand} ${v.model} (${v.registrationNumber})',
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) {
                              setState(() {
                                _selectedVehicle = v;
                              });
                            },
                            decoration: const InputDecoration(
                              labelText: 'Véhicule',
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '2. Conducteur principal',
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<ClientModel>(
                            value: _primaryDriver,
                            items: clients
                                .map(
                                  (c) => DropdownMenuItem(
                                    value: c,
                                    child: Text(
                                      '${c.fullName} (${c.cin})',
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (c) {
                              setState(() {
                                _primaryDriver = c;
                                if (c != null && _secondaryDriver?.id == c.id) {
                                  _secondaryDriver = null;
                                }
                              });
                            },
                            decoration: const InputDecoration(
                              labelText: 'Conducteur principal',
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '3. Conducteur secondaire (optionnel)',
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<ClientModel?>(
                            value: _secondaryDriver != null &&
                                    _primaryDriver != null &&
                                    _secondaryDriver!.id == _primaryDriver!.id
                                ? null
                                : _secondaryDriver,
                            items: [
                              const DropdownMenuItem<ClientModel?>(
                                value: null,
                                child: Text('Aucun'),
                              ),
                              ...clients
                                  .where((c) =>
                                      _primaryDriver == null ||
                                      c.id != _primaryDriver!.id)
                                  .map(
                                    (c) => DropdownMenuItem<ClientModel?>(
                                      value: c,
                                      child: Text(
                                        '${c.fullName} (${c.cin})',
                                      ),
                                    ),
                                  ),
                            ],
                            onChanged: (ClientModel? c) {
                              setState(() {
                                _secondaryDriver = c;
                              });
                            },
                            decoration: const InputDecoration(
                              labelText: 'Conducteur secondaire',
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '4. Période de location',
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Date de début'),
                                  subtitle: Text(
                                    _dateFormatter.format(_startDate),
                                  ),
                                  trailing:
                                      const Icon(Icons.date_range_outlined),
                                  // Start date is always "now" and not editable.
                                  onTap: null,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Retour prévu'),
                                  subtitle: Text(
                                    _dateFormatter.format(_expectedReturnDate),
                                  ),
                                  trailing:
                                      const Icon(Icons.date_range_outlined),
                                  onTap: _pickExpectedReturnDate,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Text('Durée:'),
                              const SizedBox(width: 8),
                              DropdownButton<int>(
                                value: _durationDays,
                                items: const [
                                  1,
                                  2,
                                  3,
                                  4,
                                  5,
                                  6,
                                  7,
                                  10,
                                  15,
                                  30,
                                ]
                                    .map(
                                      (d) => DropdownMenuItem<int>(
                                        value: d,
                                        child: Text('$d jours'),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) {
                                  if (value == null) return;
                                  setState(() {
                                    _durationDays = value;
                                    _expectedReturnDate =
                                        _startDate.add(Duration(days: value));
                                  });
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Nombre de jours: $_rentalDays',
                            style: theme.textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '5. Paiement',
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Total contrat: ${_totalPrice.toStringAsFixed(2)} MAD',
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            initialValue: _amountPaid.toStringAsFixed(2),
                            decoration: const InputDecoration(
                              labelText: 'Montant payé (MAD)',
                            ),
                            keyboardType:
                                const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            onChanged: (value) {
                              final v = double.tryParse(value);
                              setState(() {
                                _amountPaid = v ?? 0;
                              });
                            },
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Reste à payer: ${_remaining.toStringAsFixed(2)} MAD',
                            style: theme.textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 24),
                          AppButton(
                            label: 'Créer le contrat',
                            icon: Icons.check_circle_outline,
                            isLoading: _isSubmitting,
                            onPressed: _submit,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(
              child: Text(
                'Erreur lors du chargement des clients.\n'
                'خطأ أثناء تحميل الزبناء.\n'
                'Clients loading error: $error',
                textAlign: TextAlign.center,
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text(
            'Erreur lors du chargement des véhicules.\n'
            'خطأ أثناء تحميل السيارات.\n'
            'Vehicles loading error: $error',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

