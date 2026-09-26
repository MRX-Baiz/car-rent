import '../../core/notifications/notification_service.dart';
import '../../domain/entities/notification_diagnostics.dart';
import '../../domain/entities/reminder_plans.dart';
import '../../domain/services/reminder_scheduler.dart';

/// Delivers reminders through the device's local-notification service.
class NotificationReminderScheduler implements ReminderScheduler {
  NotificationReminderScheduler._();

  static final instance = NotificationReminderScheduler._();

  NotificationService get _service => NotificationService.instance;

  @override
  Future<void> scheduleContractReminders(
    ContractReminderPlan plan, {
    bool requestPermissions = true,
  }) {
    return _service.scheduleContractReminders(
      contractId: plan.contractId,
      registrationNumber: plan.registrationNumber,
      startDate: plan.startDate,
      expectedReturnDate: plan.expectedReturnDate,
      remainingAmount: plan.remainingAmount,
      requestPermissions: requestPermissions,
    );
  }

  @override
  Future<void> cancelContractReminders(int contractId) =>
      _service.cancelContractNotifications(contractId);

  @override
  Future<void> scheduleVehicleMaintenanceReminders(
    VehicleMaintenancePlan plan, {
    bool requestPermissions = true,
  }) {
    return _service.scheduleVehicleMaintenanceReminders(
      plan,
      requestPermissions: requestPermissions,
    );
  }

  @override
  Future<void> scheduleLicenseExpiry(DateTime expiryDate) =>
      _service.scheduleLicenseExpiry(expiryDate);

  @override
  Future<void> dismissLateDigest() => _service.dismissLateDigest();

  @override
  Future<void> cancelAll() => _service.cancelAll();

  @override
  Future<NotificationDiagnostics> diagnostics() => _service.diagnostics();

  @override
  Future<bool> requestPermission() => _service.requestPermission();
}
