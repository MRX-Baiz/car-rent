import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_strings.dart';
import '../../providers/client_provider.dart';
import '../../widgets/common/adaptive_layout.dart';
import '../../widgets/common/empty_state_widget.dart';
import '../../widgets/common/app_shimmer.dart';

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

  @override
  Widget build(BuildContext context) {
    final clientsAsync = ref.watch(clientsProvider);
    final theme = Theme.of(context);

    return AdaptiveLayout(
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () =>
              context.canPop() ? context.pop() : context.go('/dashboard'),
            tooltip: 'Retour',
          ),
          title: const Text('Clients'),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Rechercher par nom ou CIN',
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value.trim();
                  });
                  ref.read(clientsProvider.notifier).search(value.trim());
                },
              ),
            ),
            Expanded(
              child: clientsAsync.when(
                data: (clients) {
                  if (clients.isEmpty) {
                    return const EmptyStateWidget(
                      title: 'Aucun client enregistré.',
                      subtitle:
                          'Ajoutez un nouveau client ou utilisez la fonction de scan.',
                      icon: Icons.person_outline,
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: () =>
                        ref.read(clientsProvider.notifier).loadClients(),
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      itemCount: clients.length,
                      itemBuilder: (context, index) {
                        final client = clients[index];
                        final initials = (client.firstName.isNotEmpty
                                    ? client.firstName[0]
                                    : '') +
                                (client.lastName.isNotEmpty
                                    ? client.lastName[0]
                                    : '')
                            .toUpperCase();

                        return Dismissible(
                          key: ValueKey(client.id ?? index),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            color: theme.colorScheme.error,
                            alignment: Alignment.centerRight,
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16),
                            child: const Icon(
                              Icons.delete_forever,
                              color: Colors.white,
                            ),
                          ),
                          confirmDismiss: (_) async {
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
                            return confirmed ?? false;
                          },
                          onDismissed: (_) async {
                            try {
                              if (client.id != null) {
                                await ref
                                    .read(clientsProvider.notifier)
                                    .deleteClient(client.id!);
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(AppStrings.successDeleted),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (!mounted) return;
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
                          child: Card(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            child: ListTile(
                              onTap: () {
                                if (client.id != null) {
                                  context.push('/clients/${client.id}');
                                }
                              },
                              leading: Hero(
                                tag: 'client_${client.id}',
                                child: CircleAvatar(
                                  child: Text(initials),
                                ),
                              ),
                              title: Text(client.fullName),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'CIN: ${client.cin}',
                                    style: theme.textTheme.bodySmall,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    client.phone,
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
                loading: () => AppShimmer.listLayer(),
                error: (error, _) => Center(
                  child: Text(
                    'Erreur lors du chargement des clients.\n'
                    'خطأ أثناء تحميل الزبناء.\n'
                    'Clients loading error: $error',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => context.push('/clients/add'),
          icon: const Icon(Icons.person_add_outlined),
          label: const Text('Nouveau client'),
          tooltip: 'Ajouter un client',
        ),
      ),
    );
  }
}

