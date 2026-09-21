import '../../data/models/contract_model.dart';
import '../constants/app_colors.dart';
import 'format_utils.dart';

class ReturnStatus {
  const ReturnStatus(this.label, this.tone);
  final String label;
  final AppTone tone;
}

/// When the vehicle is due back, phrased for someone standing at the counter.
ReturnStatus returnStatusOf(ContractModel c, {DateTime? now}) {
  final at = now ?? DateTime.now();
  if (c.status == 'completed') {
    final returned = c.actualReturnDate;
    return ReturnStatus(
      returned == null ? 'Terminé' : 'Rendu le ${formatDate(returned)}',
      AppTone.neutral,
    );
  }

  final due = c.expectedReturnDate;
  if (at.isAfter(due)) {
    final late = at.difference(due);
    if (late.inHours < 24) {
      return ReturnStatus(
        'En retard de ${late.inHours < 1 ? 1 : late.inHours} h',
        AppTone.danger,
      );
    }
    return ReturnStatus('En retard de ${late.inDays} j', AppTone.danger);
  }

  final dayGap = dateOnly(due).difference(dateOnly(at)).inDays;
  if (dayGap == 0) {
    return ReturnStatus(
        'Retour aujourd’hui à ${formatTime(due)}', AppTone.warning);
  }
  if (dayGap == 1) {
    return ReturnStatus('Retour demain à ${formatTime(due)}', AppTone.info);
  }
  return ReturnStatus('Retour dans $dayGap j', AppTone.info);
}

class PaymentStatus {
  const PaymentStatus(this.label, this.tone, this.isSettled);
  final String label;
  final AppTone tone;
  final bool isSettled;
}

PaymentStatus paymentStatusOf(ContractModel c) {
  if (c.remainingAmount <= 0.009) {
    return const PaymentStatus('Payé', AppTone.success, true);
  }
  if (c.amountPaid > 0) {
    return PaymentStatus(
        'Reste ${formatMad(c.remainingAmount)}', AppTone.warning, false);
  }
  return PaymentStatus(
      'Non payé · ${formatMad(c.totalPrice)}', AppTone.danger, false);
}

/// Daily rate implied by a contract, net of the chauffeur's hours.
double? impliedDailyRate(ContractModel c) {
  final days = c.rentalDays < 1 ? 1 : c.rentalDays;
  final base = c.totalPrice - c.chauffeurHours * c.chauffeurHourlyRate;
  if (base <= 0) return null;
  return base / days;
}
