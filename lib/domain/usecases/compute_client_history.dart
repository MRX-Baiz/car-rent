import '../entities/client_history.dart';

/// Turns a client's rental records into the numbers that say whether the
/// next rental needs a second look: how many times they've rented, how
/// often late, what they currently owe, and how many rentals had damage.
///
/// Pure, like `ComputeVehicleProfitability` — no repository dependency. The
/// provider layer joins the already-loaded contract/inspection data and
/// hands this plain records.
class ComputeClientHistory {
  const ComputeClientHistory();

  ClientHistorySummary call({
    required int clientId,
    required Iterable<ClientRentalRecord> rentals,
    DateTime? now,
  }) {
    final today = now ?? DateTime.now();
    var lateReturns = 0;
    var totalUnpaid = 0.0;
    var damageIncidents = 0;
    var total = 0;

    for (final rental in rentals) {
      total++;
      final actual = rental.actualReturnDate;
      final isLate = actual != null
          ? actual.isAfter(rental.expectedReturnDate)
          : rental.isActive && today.isAfter(rental.expectedReturnDate);
      if (isLate) lateReturns++;

      if (rental.isActive && rental.remainingAmount > 0.009) {
        totalUnpaid += rental.remainingAmount;
      }

      if (rental.hadDamage) damageIncidents++;
    }

    return ClientHistorySummary(
      clientId: clientId,
      totalRentals: total,
      lateReturnCount: lateReturns,
      totalUnpaidBalance: totalUnpaid,
      damageIncidentCount: damageIncidents,
    );
  }
}
