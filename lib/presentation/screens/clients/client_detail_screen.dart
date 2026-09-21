import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/storage/media_store.dart';
import '../../../core/utils/format_utils.dart';
import '../../../data/models/client_model.dart';
import '../../providers/client_provider.dart';
import '../../providers/lookup_provider.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_shimmer.dart';
import '../../widgets/common/detail_row.dart';
import '../../widgets/common/document_viewer.dart';
import '../../widgets/common/empty_state_widget.dart';
import '../../widgets/common/initials_avatar.dart';
import '../../widgets/common/section_header.dart';
import '../../widgets/common/status_chip.dart';
import '../../widgets/contracts/contract_card.dart';
import '../../widgets/motion/backdrop_page.dart';

class ClientDetailScreen extends ConsumerWidget {
  const ClientDetailScreen({
    super.key,
    required this.clientId,
  });

  final int clientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clientsAsync = ref.watch(clientsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Client'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Modifier le client',
            onPressed: () {
              final client = _findClient(clientsAsync.value, clientId);
              if (client != null) {
                context.push('/clients/$clientId/edit', extra: client);
              }
            },
          ),
        ],
      ),
      body: BackdropPage(
          child: clientsAsync.when(
        data: (clients) {
          final client = _findClient(clients, clientId);
          if (client == null) {
            return const EmptyStateWidget(
              title: 'Client introuvable.',
              subtitle: 'Ce client a peut-être été supprimé.',
              icon: Icons.person_off_outlined,
            );
          }
          return _Body(
            client: client,
            onDelete: () => _delete(context, ref, client),
          );
        },
        loading: () => AppShimmer.detailLayer(),
        error: (error, _) => Center(
          child: Text(
            'Erreur lors du chargement du client.\n'
            'خطأ أثناء تحميل الزبون.\n'
            'Client loading error: $error',
            textAlign: TextAlign.center,
          ),
        ),
      )),
    );
  }

  Future<void> _delete(
      BuildContext context, WidgetRef ref, ClientModel client) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer le client'),
        content: const Text(AppStrings.confirmDeleteClient),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style:
                FilledButton.styleFrom(backgroundColor: AppTone.danger.color),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      if (client.id != null) {
        await ref.read(clientsProvider.notifier).deleteClient(client.id!);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.successDeleted)),
        );
        context.go('/clients');
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Erreur lors de la suppression.\n'
            'حدث خطأ أثناء الحذف.\n'
            'Delete error: $e',
          ),
        ),
      );
    }
  }

  ClientModel? _findClient(List<ClientModel>? list, int id) {
    if (list == null) return null;
    for (final c in list) {
      if (c.id == id) return c;
    }
    return null;
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.client, required this.onDelete});
  final ClientModel client;
  final VoidCallback onDelete;

  void _copy(BuildContext context, String label, String value) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('$label copié.')));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final licence = expiryOf(client.licenseExpiryDate);
    final id = client.id;
    final history = id == null ? null : ref.watch(clientContractsProvider(id));
    final lookups = ref.watch(lookupsProvider).value ?? const Lookups();

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
          16, 16, 16, 24 + MediaQuery.viewPaddingOf(context).bottom),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppCard(
                child: Row(
                  children: [
                    Hero(
                      tag: 'client_${client.id}',
                      child: InitialsAvatar(name: client.fullName, radius: 34),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(client.fullName,
                              style: theme.textTheme.titleLarge),
                          const SizedBox(height: 4),
                          Text('CIN ${client.cin}',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w600)),
                          if (client.licenseExpiryDate != null) ...[
                            const SizedBox(height: 8),
                            StatusChip(
                              label: 'Permis · ${licence.label}',
                              tone: licence.tone,
                              icon: Icons.credit_card,
                              dense: true,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SectionHeader(
                title: 'Identité et permis',
                padding: EdgeInsets.fromLTRB(4, 20, 4, 10),
              ),
              AppCard(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: DetailList(children: [
                  DetailRow(
                    icon: Icons.badge_outlined,
                    label: 'Carte d’identité (CIN)',
                    value: client.cin,
                    mono: true,
                    onTap: () => _copy(context, 'CIN', client.cin),
                  ),
                  DetailRow(
                    icon: Icons.credit_card,
                    label: 'Numéro de permis',
                    value: client.licenseNumber,
                    mono: true,
                    onTap: () => _copy(
                        context, 'Numéro de permis', client.licenseNumber),
                  ),
                  DetailRow(
                    icon: Icons.event_available_outlined,
                    label: 'Validité du permis',
                    value: client.licenseExpiryDate == null
                        ? ''
                        : formatDate(client.licenseExpiryDate!),
                    trailing: client.licenseExpiryDate == null
                        ? null
                        : StatusChip(
                            label: licence.label,
                            tone: licence.tone,
                            dense: true),
                  ),
                ]),
              ),
              const SectionHeader(
                title: 'Coordonnées',
                padding: EdgeInsets.fromLTRB(4, 20, 4, 10),
              ),
              AppCard(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: DetailList(children: [
                  DetailRow(
                    icon: Icons.phone_outlined,
                    label: 'Téléphone',
                    value: client.phone,
                    onTap: () => _copy(context, 'Téléphone', client.phone),
                    trailing: const Icon(Icons.copy_outlined,
                        size: 18, color: AppColors.textSecondary),
                  ),
                  DetailRow(
                    icon: Icons.mail_outline,
                    label: 'E-mail',
                    value: client.email ?? '',
                  ),
                  DetailRow(
                    icon: Icons.location_on_outlined,
                    label: 'Adresse',
                    value: client.address ?? '',
                  ),
                ]),
              ),
              const SectionHeader(
                title: 'Documents',
                subtitle: 'Touchez une image pour l’agrandir.',
                padding: EdgeInsets.fromLTRB(4, 20, 4, 10),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _DocumentThumbnail(
                      imagePath: client.cinImagePath,
                      title: 'CIN',
                      placeholder: Icons.badge_outlined,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _DocumentThumbnail(
                      imagePath: client.licenseImagePath,
                      title: 'Permis',
                      placeholder: Icons.credit_card,
                    ),
                  ),
                ],
              ),
              SectionHeader(
                title: 'Historique des contrats',
                padding: const EdgeInsets.fromLTRB(4, 20, 4, 10),
                actionLabel: 'Tous',
                onAction: () => context.go('/contracts'),
              ),
              if (history == null)
                const SizedBox.shrink()
              else
                history.when(
                  data: (contracts) => contracts.isEmpty
                      ? AppCard(
                          child: Text(
                            'Ce client n’a pas encore de contrat.',
                            style: theme.textTheme.bodyMedium,
                          ),
                        )
                      : Column(
                          children: [
                            for (final c in contracts.take(5))
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: ContractCard(
                                  contract: c,
                                  lookups: lookups,
                                  compact: true,
                                  onTap: () =>
                                      context.push('/contracts/${c.id}'),
                                ),
                              ),
                            if (contracts.length > 5)
                              Text(
                                '+ ${contracts.length - 5} autre(s) contrat(s)',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodySmall
                                    ?.copyWith(color: AppColors.textSecondary),
                              ),
                          ],
                        ),
                  loading: () => const AppShimmer.rectangular(height: 80),
                  error: (_, __) =>
                      const Text('Historique indisponible pour le moment.'),
                ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: onDelete,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTone.danger.color,
                  side: BorderSide(color: AppTone.danger.color),
                ),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Supprimer ce client'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tappable document thumbnail that opens the full-screen zoomable viewer.
class _DocumentThumbnail extends StatelessWidget {
  const _DocumentThumbnail({
    required this.imagePath,
    required this.title,
    required this.placeholder,
  });

  final String? imagePath;
  final String title;
  final IconData placeholder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // imagePath is a media-store name, and resolves to null when the file is
    // gone — which is the case for anything attached by a build that saved the
    // picker's temporary path. Those fall back to the placeholder icon.
    final resolved = MediaStore.instance.resolveSync(imagePath);
    final hasImage = resolved != null;

    final thumbnail = Container(
      height: 120,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: AppColors.primary.withValues(alpha: 0.06),
      ),
      clipBehavior: Clip.antiAlias,
      child: hasImage
          ? Stack(
              fit: StackFit.expand,
              children: [
                Image.file(File(resolved), fit: BoxFit.cover),
                // Hint that the thumbnail opens a larger view.
                Positioned(
                  right: 6,
                  bottom: 6,
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.zoom_in,
                        size: 18, color: Colors.white),
                  ),
                ),
              ],
            )
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(placeholder, size: 30, color: AppColors.textSecondary),
                const SizedBox(height: 6),
                Text('Non ajouté',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: AppColors.textSecondary)),
              ],
            ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 6),
          child: Text(title,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
        ),
        if (!hasImage)
          thumbnail
        else
          Semantics(
            button: true,
            label: 'Agrandir $title',
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => DocumentViewer.open(
                context,
                imagePath: resolved,
                title: title,
              ),
              child: Hero(tag: 'document-$resolved', child: thumbnail),
            ),
          ),
      ],
    );
  }
}
