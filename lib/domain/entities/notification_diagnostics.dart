/// Whether a reminder scheduled now would actually arrive on time.
class NotificationDiagnostics {
  const NotificationDiagnostics({
    required this.available,
    required this.notificationsAllowed,
    required this.exactAlarmsAllowed,
    required this.pending,
  });

  /// False on platforms with no local-notification support.
  final bool available;

  /// Android 13+ blocks everything until the user has been asked.
  final bool notificationsAllowed;

  /// Without this, Android 12+ downgrades an exact alarm to an inexact one and
  /// Doze holds it until the device next wakes — so a reminder set for 14:37
  /// can arrive whenever the phone is picked up, with no error anywhere.
  final bool exactAlarmsAllowed;

  /// How many reminders are currently queued with the OS.
  final int pending;

  bool get isFullyGranted => notificationsAllowed && exactAlarmsAllowed;
}
