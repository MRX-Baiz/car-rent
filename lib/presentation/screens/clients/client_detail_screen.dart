import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/storage/media_store.dart';
import '../../../data/models/client_model.dart';
import '../../providers/client_provider.dart';
import '../../widgets/common/empty_state_widget.dart';
import '../../widgets/common/app_shimmer.dart';
import '../../widgets/common/document_viewer.dart';

class ClientDetailScreen extends ConsumerWidget {
  const ClientDetailScreen({
    super.key,
    required this.clientId,
  });

  final int clientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clientsAsync = ref.watch(clientsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Détails du client'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
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
      body: clientsAsync.when(
        data: (clients) {
          final client = _findClient(clients, clientId);
          if (client == null) {
            return const EmptyStateWidget(
              title: 'Client introuvable.',
              subtitle: 'Ce client a peut-être été supprimé.',
              icon: Icons.person_off_outlined,
            );
          }

          final initials = (client.firstName.isNotEmpty
                      ? client.firstName[0]
                      : '') +
                  (client.lastName.isNotEmpty ? client.lastName[0] : '')
              .toUpperCase();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 700),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Hero(
                          tag: 'client_${client.id}',
                          child: CircleAvatar(
                            radius: 32,
                            child: Text(
                              initials,
                              style: const TextStyle(fontSize: 20),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                client.fullName,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text('CIN: ${client.cin}'),
                              const SizedBox(height: 2),
                              Text('Permis: ${client.licenseNumber}'),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Coordonnées',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Téléphone: ${client.phone}'),
                            const SizedBox(height: 4),
                            Text('Email: ${client.email ?? '-'}'),
                            const SizedBox(height: 4),
                            Text('Adresse: ${client.address ?? '-'}'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Documents',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'CIN',
                                style: theme.textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 4),
                              _DocumentThumbnail(
                                imagePath: client.cinImagePath,
                                title: 'CIN',
                                placeholder: Icons.badge_outlined,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Permis',
                                style: theme.textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 4),
                              _DocumentThumbnail(
                                imagePath: client.licenseImagePath,
                                title: 'Permis',
                                placeholder: Icons.credit_card,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          onPressed: () async {
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Supprimer le client'),
                                content: const Text(
                                  AppStrings.confirmDeleteClient,
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(false),
                                    child: const Text('Annuler'),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(true),
                                    child: const Text('Supprimer'),
                                  ),
                                ],
                              ),
                            );
                            if (confirmed != true) return;

                            try {
                              if (client.id != null) {
                                await ref
                                    .read(clientsProvider.notifier)
                                    .deleteClient(client.id!);
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(AppStrings.successDeleted),
                                  ),
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
                          },
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Supprimer'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
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
      ),
    );
  }

  ClientModel? _findClient(List<ClientModel>? list, int id) {
    if (list == null) return null;
    try {
      return list.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
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
      height: 90,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: theme.colorScheme.surfaceContainerHighest,
      ),
      clipBehavior: Clip.antiAlias,
      child: hasImage
          ? Stack(
              fit: StackFit.expand,
              children: [
                Image.file(File(resolved), fit: BoxFit.cover),
                // Hint that the thumbnail opens a larger view.
                Positioned(
                  right: 4,
                  bottom: 4,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.zoom_in,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            )
          : Icon(placeholder, color: theme.colorScheme.onSurfaceVariant),
    );

    if (!hasImage) return thumbnail;

    return Semantics(
      button: true,
      label: 'Agrandir $title',
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => DocumentViewer.open(
          context,
          imagePath: resolved,
          title: title,
        ),
        child: Hero(tag: 'document-$resolved', child: thumbnail),
      ),
    );
  }
}
