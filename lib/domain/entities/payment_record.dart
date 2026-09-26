/// A payment recorded against a rental contract.
class PaymentRecord {
  const PaymentRecord({
    required this.id,
    required this.contractId,
    required this.amount,
    required this.paidAt,
    required this.method,
    this.note,
  });

  final int? id;
  final int contractId;
  final double amount;
  final DateTime paidAt;
  final String method;
  final String? note;
}
