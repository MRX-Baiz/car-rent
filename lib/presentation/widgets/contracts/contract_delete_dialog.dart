import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/format_utils.dart';
import '../../../data/models/contract_model.dart';

/// Shared confirmation for deleting a contract, worded for what actually
/// happens — [ContractRepository.deleteContract] already frees the vehicle
/// (and the chauffeur, if any) when the contract was active, and removes its
/// payment history — rather than a generic "are you sure."
///
/// Used both from the contracts list (swipe to delete) and from a contract's
/// own detail page, so a mistaken contract can be removed from wherever the
/// operator happens to be, not just once it's completed.
Future<bool> confirmDeleteContract(
  BuildContext context,
  ContractModel contract,
) async {
  final consequences = <String>[
    if (contract.amountPaid > 0)
      'Les ${formatMad(contract.amountPaid)} de paiements enregistrés seront supprimés.',
    if (contract.status == 'active') 'Le véhicule redeviendra disponible.',
    'Le document PDF préparé pour ce contrat, s\'il existe, sera perdu.',
  ];

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Supprimer le contrat ?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Le contrat n° ${contract.contractNumber} sera supprimé '
            'définitivement. Cette action est irréversible.',
          ),
          const SizedBox(height: 10),
          for (final line in consequences)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('•  $line'),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Annuler'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppTone.danger.color),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Supprimer'),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
