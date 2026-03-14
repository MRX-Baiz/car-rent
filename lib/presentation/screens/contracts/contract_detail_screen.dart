import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/notifications/notification_service.dart';
import '../../../core/pdf/contract_pdf_generator.dart';
import '../../../data/models/client_model.dart';
import '../../../data/models/contract_model.dart';
import '../../../data/models/payment_model.dart';
import '../../../data/models/vehicle_model.dart';
import '../../../data/repositories/payment_repository.dart';
import '../../providers/contract_provider.dart';
import '../../widgets/common/empty_state_widget.dart';
import '../../widgets/common/status_badge.dart';

class ContractDetailScreen extends ConsumerStatefulWidget {
  const ContractDetailScreen({
    super.key,
    required this.contractId,
  });

  final int contractId;

  @override
  ConsumerState<ContractDetailScreen> createState() =>
      _ContractDetailScreenState();
}

class _ContractDetailScreenState
    extends ConsumerState<ContractDetailScreen> {
  final DateFormat _dateFormatter = DateFormat('dd/MM/yyyy');
  final PaymentRepository _paymentRepository = PaymentRepository.instance;
  final ContractPdfGenerator _pdfGenerator = ContractPdfGenerator();

  late Future<List<PaymentModel>> _paymentsFuture;

  @override
  void initState() {
    super.initState();
    _paymentsFuture =
        _paymentRepository.getPaymentsByContractId(widget.contractId);
  }

  Future<void> _refreshPayments() async {
    setState(() {
      _paymentsFuture =
          _paymentRepository.getPaymentsByContractId(widget.contractId);
    });
    await ref
        .read(contractsProvider.notifier)
        .refreshPaymentsForContract(widget.contractId);
  }

  Future<void> _addPayment(ContractModel contract) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final amount = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ajouter un paiement'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Montant (MAD)',
            ),
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Le montant est requis.';
              }
              final v = double.tryParse(value);
              if (v == null || v <= 0) {
                return 'Montant invalide.';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              final v = double.parse(controller.text.trim());
              Navigator.of(context).pop(v);
            },
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );

    if (amount == null) return;

    try {
      final now = DateTime.now();
      final payment = PaymentModel(
        id: null,
        contractId: contract.id!,
        amount: amount,
        paymentDate: now,
        paymentMethod: 'cash',
        notes: null,
        createdAt: now,
      );
      await _paymentRepository.insertPayment(payment);
      await _refreshPayments();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.successSaved)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Erreur lors de l’ajout du paiement.\n'
            'حدث خطأ أثناء إضافة الأداء.\n'
            'Payment error: $e',
          ),
        ),
      );
    }
  }

  Future<void> _closeContract(ContractModel contract) async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: contract.startDate,
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null) return;

    try {
      await ref
          .read(contractsProvider.notifier)
          .closeContract(contract.id!, date);
      await NotificationService.instance
          .cancelContractNotifications(contract.id!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.successSaved)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Erreur lors de la clôture du contrat.\n'
            'حدث خطأ أثناء إغلاق العقد.\n'
            'Close contract error: $e',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final contractsAsync = ref.watch(contractsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Détails du contrat'),
      ),
      body: contractsAsync.when(
        data: (contracts) {
          final contract = _findContract(contracts, widget.contractId);
          if (contract == null) {
            return const EmptyStateWidget(
              title: 'Contrat introuvable.',
              subtitle: 'Ce contrat a peut-être été supprimé.',
              icon: Icons.receipt_long_outlined,
            );
          }

          return RefreshIndicator(
            onRefresh: _refreshPayments,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          contract.contractNumber,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Contrat pour véhicule #${contract.vehicleId}',
                        ),
                      ],
                    ),
                    StatusBadge(text: contract.status),
                  ],
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Période de location',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Début: ${_dateFormatter.format(contract.startDate)}',
                        ),
                        Text(
                          'Retour prévu: ${_dateFormatter.format(contract.expectedReturnDate)}',
                        ),
                        if (contract.actualReturnDate != null)
                          Text(
                            'Retour réel: ${_dateFormatter.format(contract.actualReturnDate!)}',
                          ),
                        const SizedBox(height: 8),
                        Text('Nombre de jours: ${contract.rentalDays}'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Paiements',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Total contrat: ${contract.totalPrice.toStringAsFixed(2)} MAD',
                        ),
                        Text(
                          'Payé: ${contract.amountPaid.toStringAsFixed(2)} MAD',
                        ),
                        Text(
                          'Reste: ${contract.remainingAmount.toStringAsFixed(2)} MAD',
                        ),
                        const SizedBox(height: 12),
                        FutureBuilder<List<PaymentModel>>(
                          future: _paymentsFuture,
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }
                            if (snapshot.hasError) {
                              return Text(
                                'Erreur lors du chargement des paiements.\n'
                                'خطأ أثناء تحميل الأداءات.\n'
                                'Payments loading error: ${snapshot.error}',
                              );
                            }
                            final payments = snapshot.data ?? [];
                            if (payments.isEmpty) {
                              return const Text(
                                'Aucun paiement enregistré pour ce contrat.',
                              );
                            }
                            return Column(
                              children: payments
                                  .map(
                                    (p) => ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      leading: const Icon(
                                        Icons.payments_outlined,
                                      ),
                                      title: Text(
                                        '${p.amount.toStringAsFixed(2)} MAD',
                                      ),
                                      subtitle: Text(
                                        _dateFormatter
                                            .format(p.paymentDate),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            );
                          },
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: contract.status == 'completed'
                                ? null
                                : () => _addPayment(contract),
                            icon: const Icon(Icons.add),
                            label: const Text('Ajouter un paiement'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      onPressed: contract.status == 'completed'
                          ? null
                          : () => _closeContract(contract),
                      icon: const Icon(Icons.lock_outline),
                      label: const Text('Clôturer le contrat'),
                    ),
                    TextButton.icon(
                      onPressed: () async {
                        // Generate a minimal PDF with placeholders for now.
                        // In a full implementation you would fetch related
                        // vehicle and client details here.
                        final tmpDir = Directory.systemTemp;
                        final tmpFile =
                            File('${tmpDir.path}/contract_${contract.id}.pdf');
                        if (!await tmpFile.exists()) {
                          await tmpFile.create(recursive: true);
                        }
                        final pdf = await _pdfGenerator.generateContract(
                          contract: contract,
                          vehicle: VehicleModel(
                            id: contract.vehicleId,
                            brand: 'N/A',
                            model: 'N/A',
                            registrationNumber: 'N/A',
                            year: 0,
                            status: 'available',
                            dailyPrice: 0,
                            imagePath: null,
                            createdAt: contract.createdAt,
                            updatedAt: contract.updatedAt,
                          ),
                          primaryDriver: ClientModel(
                            id: contract.primaryDriverId,
                            firstName: 'N/A',
                            lastName: '',
                            cin: '',
                            licenseNumber: '',
                            address: null,
                            phone: '',
                            email: null,
                            cinImagePath: null,
                            licenseImagePath: null,
                            createdAt: contract.createdAt,
                            updatedAt: contract.updatedAt,
                          ),
                        );
                        await _pdfGenerator.shareContract(pdf);
                      },
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                      label: const Text('Générer / partager PDF'),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text(
            'Erreur lors du chargement du contrat.\n'
            'خطأ أثناء تحميل العقد.\n'
            'Contract loading error: $error',
            textAlign: TextAlign.center,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/contracts/new'),
        child: const Icon(Icons.add),
      ),
    );
  }

  ContractModel? _findContract(List<ContractModel>? list, int id) {
    if (list == null) return null;
    try {
      return list.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }
}

