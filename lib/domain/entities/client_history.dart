/// The minimal shape a contract needs to expose for a client's rental
/// history, mapped from `ContractModel` (plus whether any of its inspections
/// flagged damage) at the data boundary — the same idea as
/// `ProfitabilityContract`.
class ClientRentalRecord {
  const ClientRentalRecord({
    required this.contractId,
    required this.startDate,
    required this.expectedReturnDate,
    required this.actualReturnDate,
    required this.isActive,
    required this.remainingAmount,
    required this.hadDamage,
  });

  final int contractId;
  final DateTime startDate;
  final DateTime expectedReturnDate;

  /// Set once the rental is over. Null while [isActive].
  final DateTime? actualReturnDate;
  final bool isActive;
  final double remainingAmount;

  /// True if any inspection on this contract recorded damage — a non-empty
  /// note, an extra charge, or a condition worse than "good".
  final bool hadDamage;
}

/// A client's rollup: how many times they've rented, how often they've
/// returned late, what they currently owe, and how many rentals involved
/// damage. Licence expiry and the "requires manager approval" flag are not
/// part of this — they're plain fields already on the client record, read
/// straight off it, not computed.
class ClientHistorySummary {
  const ClientHistorySummary({
    required this.clientId,
    required this.totalRentals,
    required this.lateReturnCount,
    required this.totalUnpaidBalance,
    required this.damageIncidentCount,
  });

  final int clientId;
  final int totalRentals;
  final int lateReturnCount;
  final double totalUnpaidBalance;
  final int damageIncidentCount;
}
