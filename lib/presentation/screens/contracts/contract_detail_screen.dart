import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/pdf/contract_pdf_generator.dart';
import '../../../data/models/client_model.dart';
import '../../../data/models/contract_model.dart';
import '../../../data/models/payment_model.dart';
import '../../../data/repositories/client_repository.dart';
import '../../../data/repositories/contract_repository.dart';
import '../../../data/repositories/payment_repository.dart';
import '../../../data/repositories/vehicle_repository.dart';
import '../../providers/contract_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../widgets/common/empty_state_widget.dart';
import '../../widgets/common/status_badge.dart';
import '../../widgets/common/app_shimmer.dart';

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
  final DateFormat _dateFormatter = DateFormat('dd/MM/yyyy HH:mm');
  final PaymentRepository _paymentRepository = PaymentRepository.instance;
  final ContractRepository _contractRepository = ContractRepository.instance;
  final VehicleRepository _vehicleRepository = VehicleRepository.instance;
  final ClientRepository _clientRepository = ClientRepository.instance;
  final ContractPdfGenerator _pdfGenerator = ContractPdfGenerator();

  late Future<List<PaymentModel>> _paymentsFuture;

  String _savedPdfPath = ''; // Stores last downloaded PDF path for snackbar

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
    await ref.read(dashboardProvider.notifier).refresh();
  }

  Future<void> _addPayment(ContractModel contract) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final currencyFormatter = NumberFormat.currency(symbol: 'MAD', decimalDigits: 2);
    final remaining = contract.remainingAmount;

    final amount = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ajouter un paiement'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Reste à payer : ${currencyFormatter.format(remaining)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Montant à payer',
                  suffixText: 'MAD',
                  border: const OutlineInputBorder(),
                  helperText: 'Saisissez le montant versé par le client.',
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
                  if (v > remaining + 0.01) {
                    return 'Le montant dépasse le reste (${currencyFormatter.format(remaining)}).';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              if (remaining > 0)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      controller.text = remaining.toStringAsFixed(2);
                    },
                    child: const Text('Tout payer'),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              final v = double.parse(controller.text.trim());
              Navigator.of(context).pop(v);
            },
            child: const Text('Valider le paiement'),
          ),
        ],
      ),
    );

    if (amount == null) return;

    try {
      await ContractRepository.instance.addPaymentAndUpdateContract(contract.id!, amount);
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
      // If there's a remaining balance, ask to pay it
      final remaining = contract.remainingAmount;
      if (remaining > 0) {
        final payNow = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Reste à payer'),
            content: Text(
              'Il reste ${remaining.toStringAsFixed(2)} MAD à payer. '
              'Voulez-vous enregistrer ce paiement avant la clôture ?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('NON, PLUS TARD'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('OUI, PAYER TOUT'),
              ),
            ],
          ),
        );

        if (payNow == true) {
          await ContractRepository.instance
              .addPaymentAndUpdateContract(contract.id!, remaining);
          // Refresh local state before closing
          await _refreshPayments();
        }
      }

      await ref
          .read(contractsProvider.notifier)
          .closeContract(contract.id!, date);
      await ref.read(dashboardProvider.notifier).refresh();
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
                        Hero(
                          tag: 'contract_${contract.id}',
                          child: Text(
                            contract.contractNumber,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
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
                        final vehicle = await _vehicleRepository.getVehicleById(contract.vehicleId);
                        final primary = await _clientRepository.getClientById(contract.primaryDriverId);
                        if (vehicle == null || primary == null) {
                          if (!mounted) return;
                          // ignore: use_build_context_synchronously
                          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                            const SnackBar(content: Text('Véhicule ou client introuvable.')),
                          );
                          return;
                        }
                        ClientModel? secondary;
                        if (contract.secondaryDriverId != null) {
                          secondary = await _clientRepository.getClientById(contract.secondaryDriverId!);
                        }
                        final pdf = await _pdfGenerator.generateContract(
                          contract: contract,
                          vehicle: vehicle,
                          primaryDriver: primary,
                          secondaryDriver: secondary,
                        );
                        if (!mounted) return;
                        // Show options: Download or Share
                        await showModalBottomSheet(
                          context: context,
                          builder: (ctx) => SafeArea(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(height: 8),
                                ListTile(
                                  leading: const Icon(Icons.download_outlined),
                                  title: const Text('Télécharger le PDF'),
                                  subtitle: const Text('Sauvegarder dans Documents/CarRent_Contracts'),
                                  onTap: () async {
                                    Navigator.pop(ctx);
                                    try {
                                      final path = await _pdfGenerator.downloadContract(pdf);
                                      if (!mounted) return;
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('PDF sauvegardé : $path')),
                                      );
                                    } catch (e) {
                                      if (!mounted) return;
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Erreur téléchargement: $e')),
                                      );
                                    }
                                  },
                                ),
                                ListTile(
                                  leading: const Icon(Icons.share_outlined),
                                  title: const Text('Partager le PDF'),
                                  onTap: () async {
                                    Navigator.pop(ctx);
                                    await _pdfGenerator.shareContract(pdf);
                                  },
                                ),
                                const SizedBox(height: 8),
                              ],
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                      label: const Text('Générer PDF'),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
        loading: () => AppShimmer.detailLayer(),
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
        onPressed: () => context.push('/contracts/new'),
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

