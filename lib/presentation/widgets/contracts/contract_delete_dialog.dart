import 'package:car_rent_manager/core/localization/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:car_rent_manager/presentation/widgets/common/app_text.dart';

import '../../../core/constants/app_colors.dart';
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
      context.messages.deletePaymentsConfirmation((context.money(contract.amountPaid)).toString()),
    if (contract.status == 'active') AppCopy.theVehicleWillBecomeAvailableAgain,
    AppCopy.anyPDFPreparedForThisContractWillBe,
  ];

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const AppText(AppCopy.deleteThisContractbe8a00),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.messages.deleteContractConfirmation((contract.contractNumber).toString()),
          ),
          const SizedBox(height: 10),
          for (final line in consequences)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: AppText('•  ${context.tr(line)}'),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const AppText(AppCopy.cancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppTone.danger.color),
          onPressed: () => Navigator.of(context).pop(true),
          child: const AppText(AppCopy.delete),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
