import 'package:flutter/material.dart';
import 'package:car_rent_manager/core/localization/app_localizations.dart';
import 'package:car_rent_manager/presentation/widgets/common/app_text.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/format_utils.dart';
import '../../../data/models/client_model.dart';
import '../../providers/client_provider.dart';
import '../../widgets/common/adaptive_layout.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_shimmer.dart';
import '../../widgets/common/empty_state_widget.dart';
import '../../widgets/common/initials_avatar.dart';
import '../../widgets/common/status_chip.dart';
import '../../widgets/motion/backdrop_page.dart';

class ClientsListScreen extends ConsumerStatefulWidget {
  const ClientsListScreen({super.key});

  @override
  ConsumerState<ClientsListScreen> createState() => _ClientsListScreenState();
}

class _ClientsListScreenState extends ConsumerState<ClientsListScreen> {
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(clientsProvider.notifier).loadClients(),
    );
  }

  Future<bool> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const AppText(AppCopy.deleteClient),
        content: const AppText(AppStrings.confirmDeleteClient),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const AppText(AppCopy.cancel),
          ),
          FilledButton(
            style:
                FilledButton.styleFrom(backgroundColor: AppTone.danger.color),
            onPressed: () => Navigator.of(context).pop(true),
            child: const AppText(AppCopy.delete),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _delete(ClientModel client) async {
    try {
      if (client.id == null) return;
      await ref.read(clientsProvider.notifier).deleteClient(client.id!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: AppText(AppStrings.successDeleted)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: AppText(
            context.trError(e),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final clientsAsync = ref.watch(clientsProvider);

    return AdaptiveLayout(
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () =>
                context.canPop() ? context.pop() : context.go('/dashboard'),
            tooltip: context.tr(AppCopy.back),
          ),
          title: const AppText(AppCopy.clients),
        ),
        body: BackdropPage(
            child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: context.tr(AppCopy.searchByNameOrNationalID),
                ),
                onChanged: (value) {
                  setState(() => _searchQuery = value.trim());
                  ref.read(clientsProvider.notifier).search(value.trim());
                },
              ),
            ),
            Expanded(
              child: clientsAsync.when(
                data: (clients) {
                  if (clients.isEmpty) {
                    final searching = _searchQuery.isNotEmpty;
                    return EmptyStateWidget(
                      title: searching
                          ? AppCopy.noClientsFound
                          : AppCopy.noClientsSaved,
                      subtitle: searching
                          ? AppCopy.checkTheSpellingOrTryTheNationalID
                          : AppCopy.addAClientWithOrWithoutScanningTheir,
                      icon: Icons.person_outline,
                      actionLabel: searching ? null : AppCopy.addAClient,
                      onAction: () => context.push('/clients/add'),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: () =>
                        ref.read(clientsProvider.notifier).loadClients(),
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                      itemCount: clients.length,
                      itemBuilder: (context, index) {
                        final client = clients[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Dismissible(
                            key: ValueKey(client.id ?? index),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              decoration: BoxDecoration(
                                color: AppTone.danger.color,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              alignment: AlignmentDirectional.centerEnd,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 20),
                              child: const Icon(Icons.delete_forever,
                                  color: Colors.white),
                            ),
                            confirmDismiss: (_) => _confirmDelete(),
                            onDismissed: (_) => _delete(client),
                            child: ClientCard(
                              client: client,
                              onTap: () {
                                if (client.id != null) {
                                  context.push('/clients/${client.id}');
                                }
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
                loading: () => AppShimmer.listLayer(),
                error: (error, _) => Center(
                  child: AppText(
                    context.trError(error),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ],
        )),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => context.push('/clients/add'),
          icon: const Icon(Icons.person_add_outlined),
          label: const AppText(AppCopy.newClient),
          tooltip: context.tr(AppCopy.addAClient),
        ),
      ),
    );
  }
}

class ClientCard extends StatelessWidget {
  const ClientCard({super.key, required this.client, required this.onTap});

  final ClientModel client;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final licence = expiryOf(client.licenseExpiryDate);
    final hasCin = (client.cinImagePath ?? '').isNotEmpty;
    final hasLicence = (client.licenseImagePath ?? '').isNotEmpty;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      accent: licence.tone == AppTone.danger ? AppTone.danger.color : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Hero(
                tag: 'client_${client.id}',
                child: InitialsAvatar(name: client.fullName, radius: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      client.fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      context.messages.nationalIdValue((client.cin).toString()),
                      style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textSecondary),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.phone_outlined,
                  size: 18, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(client.phone, style: theme.textTheme.bodyMedium),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (client.licenseExpiryDate != null)
                StatusChip(
                  label: context.messages.licenceStatus(context.tr((licence.label).toString())),
                  tone: licence.tone,
                  icon: Icons.credit_card,
                  dense: true,
                ),
              StatusChip(
                label: hasCin ? AppCopy.nationalIDScanned : AppCopy.nationalIDMissing,
                tone: hasCin ? AppTone.success : AppTone.neutral,
                icon: hasCin ? Icons.check : Icons.add_a_photo_outlined,
                dense: true,
              ),
              StatusChip(
                label: hasLicence ? AppCopy.drivingLicenceScanned : AppCopy.drivingLicenceMissing,
                tone: hasLicence ? AppTone.success : AppTone.neutral,
                icon: hasLicence ? Icons.check : Icons.add_a_photo_outlined,
                dense: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
