import 'package:car_rent_manager/domain/entities/notification_diagnostics.dart';
import 'package:car_rent_manager/domain/entities/notification_preferences.dart';
import 'package:car_rent_manager/domain/entities/reminder_plans.dart';
import 'package:car_rent_manager/domain/repositories/backup_repository.dart';
import 'package:car_rent_manager/domain/repositories/reminder_preferences_repository.dart';
import 'package:car_rent_manager/domain/repositories/reminder_source_repository.dart';
import 'package:car_rent_manager/domain/services/reminder_scheduler.dart';
import 'package:car_rent_manager/domain/usecases/change_reminder_preferences.dart';
import 'package:car_rent_manager/domain/usecases/create_backup.dart';
import 'package:car_rent_manager/domain/usecases/load_reminder_settings.dart';
import 'package:car_rent_manager/domain/usecases/request_reminder_permissions.dart';
import 'package:car_rent_manager/domain/usecases/restore_backup.dart';
import 'package:car_rent_manager/domain/usecases/restore_contract_reminders.dart';
import 'package:car_rent_manager/domain/usecases/restore_reminders_on_launch.dart';
import 'package:car_rent_manager/domain/usecases/sync_contract_reminders.dart';
import 'package:car_rent_manager/domain/usecases/sync_vehicle_maintenance_reminders.dart';
import 'package:flutter_test/flutter_test.dart';

ContractReminderPlan _contract(int id, {bool active = true}) =>
    ContractReminderPlan(
      contractId: id,
      isActive: active,
      registrationNumber: 'A-$id',
      startDate: DateTime(2026, 9, 1),
      expectedReturnDate: DateTime(2026, 9, 3),
      remainingAmount: 100,
    );

VehicleMaintenancePlan _vehicle(int id) => VehicleMaintenancePlan(
      vehicleId: id,
      registrationNumber: 'V-$id',
      currentMileage: 1000,
    );

void main() {
  late _FakeScheduler scheduler;
  late _FakeSource source;

  setUp(() {
    scheduler = _FakeScheduler();
    source = _FakeSource();
  });

  group('SyncContractReminders', () {
    test('arms an active contract and passes the permission choice through',
        () async {
      source.contracts[7] = _contract(7);

      await SyncContractReminders(source, scheduler)(7);
      await SyncContractReminders(source, scheduler)(7,
          requestPermissions: false);

      expect(scheduler.events, ['schedule:7:prompt', 'schedule:7:silent']);
    });

    test('clears the reminders of a contract that is no longer active',
        () async {
      source.contracts[7] = _contract(7, active: false);

      await SyncContractReminders(source, scheduler)(7);

      expect(scheduler.events, ['cancel:7']);
    });

    test('clears the reminders of a contract that was deleted', () async {
      await SyncContractReminders(source, scheduler)(7);

      expect(scheduler.events, ['cancel:7']);
    });
  });

  group('RestoreContractReminders', () {
    test('re-arms active contracts, clears completed ones, never prompts',
        () async {
      source.contracts[1] = _contract(1);
      source.contracts[2] = _contract(2, active: false);

      await RestoreContractReminders(source, scheduler)();

      expect(scheduler.events, ['schedule:1:silent', 'cancel:2']);
    });

    test('can prompt when the operator has just asked for reminders', () async {
      source.contracts[1] = _contract(1);

      await RestoreContractReminders(source, scheduler)(
          requestPermissions: true);

      expect(scheduler.events, ['schedule:1:prompt']);
    });
  });

  group('SyncVehicleMaintenanceReminders', () {
    test('arms the reminders of a saved vehicle', () async {
      source.vehicles[3] = _vehicle(3);

      await SyncVehicleMaintenanceReminders(source, scheduler)(3);

      expect(scheduler.events, ['vehicle:3:prompt']);
    });

    test('does nothing for a vehicle that no longer exists', () async {
      await SyncVehicleMaintenanceReminders(source, scheduler)(3);

      expect(scheduler.events, isEmpty);
    });
  });

  group('RestoreRemindersOnLaunch', () {
    test('re-arms everything silently, then clears the overdue summary',
        () async {
      source.contracts[1] = _contract(1);
      source.contracts[2] = _contract(2, active: false);
      source.vehicles[3] = _vehicle(3);

      await RestoreRemindersOnLaunch(source, scheduler)(
        licenseExpiry: DateTime(2027, 1, 1),
      );

      expect(scheduler.events, [
        'schedule:1:silent',
        'cancel:2',
        'vehicle:3:silent',
        'license:2027-01-01',
        'dismissDigest',
      ]);
    });

    test('has no licence reminder to set when there is no expiry', () async {
      await RestoreRemindersOnLaunch(source, scheduler)();

      expect(scheduler.events, ['dismissDigest']);
    });
  });

  group('ChangeReminderPreferences', () {
    late _FakePreferences preferences;
    late ChangeReminderPreferences change;

    setUp(() {
      preferences = _FakePreferences();
      change = ChangeReminderPreferences(
        preferences,
        scheduler,
        RestoreContractReminders(source, scheduler),
      );
      source.contracts[1] = _contract(1);
    });

    test('a refused permission leaves the previous choice untouched', () async {
      scheduler.grantPermission = false;

      final result = await change(
        const NotificationPreferences(enabled: true),
        permissionGranted: false,
      );

      expect(result.saved, isFalse);
      expect(result.permissionGranted, isFalse);
      expect(preferences.saved, isNull);
      expect(scheduler.events, ['requestPermission']);
    });

    test(
        'turning reminders on asks once, saves, and re-arms with the new '
        'preferences', () async {
      final result = await change(
        const NotificationPreferences(enabled: true, leadMinutes: 120),
        permissionGranted: false,
      );

      expect(result.saved, isTrue);
      expect(result.permissionGranted, isTrue);
      expect(preferences.saved!.leadMinutes, 120);
      expect(scheduler.events, ['requestPermission', 'schedule:1:prompt']);
    });

    test('does not ask again when the permission is already granted', () async {
      await change(
        const NotificationPreferences(enabled: true),
        permissionGranted: true,
      );

      expect(scheduler.events, ['schedule:1:prompt']);
    });

    test('turning reminders off silences what is already scheduled', () async {
      final result = await change(
        const NotificationPreferences(enabled: false),
        permissionGranted: false,
      );

      expect(result.saved, isTrue);
      expect(preferences.saved!.enabled, isFalse);
      expect(scheduler.events, ['cancelAll']);
    });
  });

  group('reminder settings', () {
    test('loads the choices together with what the OS will honour', () async {
      final preferences = _FakePreferences()
        ..stored = const NotificationPreferences(leadMinutes: 30);

      final settings = await LoadReminderSettings(preferences, scheduler)();

      expect(settings.preferences.leadMinutes, 30);
      expect(settings.status.pending, 4);
    });

    test('asking for permission reports the fresh state', () async {
      final preferences = _FakePreferences();
      final settings = await RequestReminderPermissions(
        scheduler,
        LoadReminderSettings(preferences, scheduler),
      )();

      expect(scheduler.events, ['requestPermission']);
      expect(settings.status.notificationsAllowed, isTrue);
    });
  });

  group('backup', () {
    test('creating a backup returns the archive the repository made', () async {
      final repository = _FakeBackupRepository();

      final archive = await CreateBackup(repository)();

      expect(archive.path, '/backups/carrent.zip');
    });

    test('restoring clears alarms only after validation, then re-arms',
        () async {
      final repository = _FakeBackupRepository(events: scheduler.events);
      source.contracts[1] = _contract(1);

      await RestoreBackup(repository, scheduler,
          RestoreContractReminders(source, scheduler))('/in/backup.zip');

      expect(scheduler.events, [
        'backup:validated',
        'cancelAll',
        'backup:replaced',
        'schedule:1:silent',
      ]);
    });

    test('a bad archive leaves working reminders alone', () async {
      final repository = _FakeBackupRepository(
        events: scheduler.events,
        failValidation: true,
      );
      source.contracts[1] = _contract(1);

      await expectLater(
        RestoreBackup(repository, scheduler,
            RestoreContractReminders(source, scheduler))('/in/bad.zip'),
        throwsA(isA<FormatException>()),
      );

      expect(scheduler.events, isNot(contains('cancelAll')));
      expect(scheduler.events, isNot(contains('schedule:1:silent')));
    });
  });
}

class _FakeScheduler implements ReminderScheduler {
  final events = <String>[];
  bool grantPermission = true;

  @override
  Future<void> scheduleContractReminders(ContractReminderPlan plan,
      {bool requestPermissions = true}) async {
    events.add(
        'schedule:${plan.contractId}:${requestPermissions ? 'prompt' : 'silent'}');
  }

  @override
  Future<void> cancelContractReminders(int contractId) async =>
      events.add('cancel:$contractId');

  @override
  Future<void> scheduleVehicleMaintenanceReminders(VehicleMaintenancePlan plan,
      {bool requestPermissions = true}) async {
    events.add(
        'vehicle:${plan.vehicleId}:${requestPermissions ? 'prompt' : 'silent'}');
  }

  @override
  Future<void> scheduleLicenseExpiry(DateTime expiryDate) async =>
      events.add('license:${expiryDate.toIso8601String().substring(0, 10)}');

  @override
  Future<void> dismissLateDigest() async => events.add('dismissDigest');

  @override
  Future<void> cancelAll() async => events.add('cancelAll');

  @override
  Future<NotificationDiagnostics> diagnostics() async =>
      const NotificationDiagnostics(
        available: true,
        notificationsAllowed: true,
        exactAlarmsAllowed: true,
        pending: 4,
      );

  @override
  Future<bool> requestPermission() async {
    events.add('requestPermission');
    return grantPermission;
  }
}

class _FakeSource implements ReminderSourceRepository {
  final contracts = <int, ContractReminderPlan>{};
  final vehicles = <int, VehicleMaintenancePlan>{};

  @override
  Future<ContractReminderPlan?> contractPlan(int contractId) async =>
      contracts[contractId];

  @override
  Future<List<ContractReminderPlan>> allContractPlans() async =>
      contracts.values.toList();

  @override
  Future<VehicleMaintenancePlan?> vehiclePlan(int vehicleId) async =>
      vehicles[vehicleId];

  @override
  Future<List<VehicleMaintenancePlan>> allVehiclePlans() async =>
      vehicles.values.toList();
}

class _FakePreferences implements ReminderPreferencesRepository {
  NotificationPreferences stored = const NotificationPreferences();
  NotificationPreferences? saved;

  @override
  Future<NotificationPreferences> load() async => stored;

  @override
  Future<void> save(NotificationPreferences preferences) async =>
      saved = preferences;
}

class _FakeBackupRepository implements BackupRepository {
  _FakeBackupRepository({List<String>? events, this.failValidation = false})
      : events = events ?? <String>[];

  final List<String> events;
  final bool failValidation;

  @override
  Future<BackupArchive> create() async =>
      const BackupArchive('/backups/carrent.zip');

  @override
  Future<void> restore(
    String archivePath, {
    Future<void> Function()? beforeReplace,
  }) async {
    if (failValidation) throw const FormatException('not a backup');
    events.add('backup:validated');
    await beforeReplace?.call();
    events.add('backup:replaced');
  }
}
