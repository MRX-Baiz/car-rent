/// Booking intervals are half-open: a car returned at 10:00 can be picked up
/// at 10:00. The same rule is used by the calendar and quote creation.
bool bookingIntervalsOverlap(
  DateTime firstStart,
  DateTime firstEnd,
  DateTime secondStart,
  DateTime secondEnd,
) =>
    firstStart.isBefore(secondEnd) && secondStart.isBefore(firstEnd);
