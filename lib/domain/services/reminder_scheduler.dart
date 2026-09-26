import '../entities/notification_diagnostics.dart';
import '../entities/reminder_plans.dart';

/// Puts reminders in front of the operator through the device.
///
/// The business layer decides what is reminded about and when it must be
/// cleared; how an alarm reaches the OS (Android alarms, Doze, permissions,
/// quiet hours) is an implementation detail behind this port.
abstract interface class ReminderScheduler {
  Future<void> scheduleContractReminders(
    ContractReminderPlan plan, {
    bool requestPermissions = true,
  });

  Future<void> cancelContractReminders(int contractId);

  Future<void> scheduleVehicleMaintenanceReminders(
    VehicleMaintenancePlan plan, {
    bool requestPermissions = true,
  });

  Future<void> scheduleLicenseExpiry(DateTime expiryDate);

  /// Clears the "vehicles are overdue" summary left in the notification shade.
  Future<void> dismissLateDigest();

  /// Silences everything already scheduled, not just future reminders.
  Future<void> cancelAll();

  Future<NotificationDiagnostics> diagnostics();

  /// Asks the OS for notification and exact-alarm permission; true if the
  /// operator has granted notifications.
  Future<bool> requestPermission();
}
