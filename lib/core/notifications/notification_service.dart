import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../../data/repositories/app_settings_repository.dart';
import '../../data/repositories/key_value_store.dart';
import '../../domain/entities/notification_diagnostics.dart';
import '../../domain/entities/reminder_plans.dart';
import '../database/database_helper.dart';
import '../localization/app_localizations.dart';
import 'android_daily_reminder.dart';
import 'notification_preferences.dart';

/// Route a notification tap should open, once the app is past the lock screen.
///
/// A tap cannot navigate directly: the lock guard would bounce it to /lock and
/// the destination would be lost. The app watches this instead and replays it
/// after unlocking.
final pendingNotificationRoute = ValueNotifier<String?>(null);

/// Local reminders: vehicle returns, overdue vehicles, payments, licence expiry.
///
/// Everything is scheduled on the device; there is no server and no push.
class NotificationService {
  NotificationService._internal();

  static final NotificationService instance = NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  NotificationPreferencesRepository _preferencesRepository =
      NotificationPreferencesRepository.instance;

  KeyValueStore _store = AppSettingsRepository.instance;

  bool _initialized = false;
  bool _available = false;

  /// Permissions are asked for at most once per run, so saving several
  /// contracts in a row does not mean several prompts.
  bool _permissionsChecked = false;

  /// Notifying someone who is already looking at the app is pure noise: the
  /// dashboard shows the same information. Kept up to date by CarRentApp.
  bool _appInForeground = true;

  set appInForeground(bool value) => _appInForeground = value;

  /// Which contracts the overdue digest last alerted about. Re-showing the
  /// same set would re-alert on Android, which is what made the reminder feel
  /// like it was firing over and over.
  static const String keyLateDigestSignature = 'late_digest_signature';

  /// Notification ids are grouped per contract: contract 7 owns 70 to 79.
  /// Cancelling a contract's reminders means clearing its whole block, so
  /// slots must stay stable across releases.
  static const int _slotsPerContract = 10;
  static const int _slotReturnLead = 0;
  static const int _slotReturnDue = 1;
  static const int _slotLateRepeat = 2;
  static const int _slotPickup = 3;
  static const int _slotPayment = 4;

  /// Far above any plausible contract id, so fixed notifications never collide
  /// with a contract block.
  static const int _idLateDigest = 1000000001;
  static const int _idLicenseBase = 1000000010;

  /// Days before licence expiry that earn a warning.
  static const List<int> licenseWarningDays = <int>[30, 7, 1];

  static const String _channelContracts = 'car_rent_contracts';
  static const String _channelLate = 'car_rent_late';
  static const String _channelPayments = 'car_rent_payments';
  static const String _channelLicense = 'car_rent_license';
  static const String _channelVehicle = 'car_rent_vehicle';
  static const int _idVehicleBase = 1100000000;
  static const List<int> vehicleDateWarningDays = <int>[30, 14, 7, 1];
  static const List<int> vehicleMileageWarningKm = <int>[1000, 500, 0];

  static const String _lateGroupKey = 'car_rent_late_group';

  static const String actionViewContract = 'view_contract';

  @visibleForTesting
  set preferencesRepositoryForTest(NotificationPreferencesRepository value) =>
      _preferencesRepository = value;

  // --------------------------------------------------------------- lifecycle

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      tz.initializeTimeZones();
      await _setLocalTimeZone();

      const androidSettings =
          AndroidInitializationSettings('@drawable/ic_stat_notification');
      // Permissions are requested later, from a screen that can explain why.
      // Asking here would prompt on the splash, before the user has seen
      // anything, which is the surest way to get refused.
      const darwinSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestSoundPermission: false,
        requestBadgePermission: false,
      );

      await _plugin.initialize(
        const InitializationSettings(
          android: androidSettings,
          iOS: darwinSettings,
          macOS: darwinSettings,
        ),
        onDidReceiveNotificationResponse: _handleResponse,
      );

      _available = true;
    } catch (e) {
      // Windows and Linux have no implementation; degrade to no reminders
      // rather than taking the app down.
      _available = false;
      if (kDebugMode) debugPrint('NotificationService.initialize: $e');
    }
  }

  /// The old code pinned this to UTC. One-off reminders still landed on the
  /// right instant, but the daily overdue repeat uses wall-clock matching, so
  /// in Morocco (UTC+1) it drifted an hour off every day.
  Future<void> _setLocalTimeZone() async {
    try {
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone.identifier));
    } catch (_) {
      // Better a fixed guess than a crash; UTC keeps instants correct even if
      // wall-clock repeats drift.
      tz.setLocalLocation(tz.getLocation('UTC'));
    }
  }

  static void _handleResponse(NotificationResponse response) {
    final payload = response.payload;
    if (payload != null && payload.isNotEmpty) {
      pendingNotificationRoute.value = payload;
    }
  }

  /// Picks up a tap that launched the app from cold, which never reaches
  /// [_handleResponse].
  Future<void> consumeLaunchNotification() async {
    if (!_available) return;
    try {
      final details = await _plugin.getNotificationAppLaunchDetails();
      final payload = details?.notificationResponse?.payload;
      if (details?.didNotificationLaunchApp == true &&
          payload != null &&
          payload.isNotEmpty) {
        pendingNotificationRoute.value = payload;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('consumeLaunchNotification: $e');
    }
  }

  // -------------------------------------------------------------- permission

  /// Everything that decides whether a reminder will actually arrive.
  ///
  /// Surfaced in settings because the failure is otherwise invisible: Android
  /// accepts a schedule it has no intention of delivering on time, and says
  /// nothing.
  Future<NotificationDiagnostics> diagnostics() async {
    await initialize();
    if (!_available) {
      return const NotificationDiagnostics(
        available: false,
        notificationsAllowed: false,
        exactAlarmsAllowed: false,
        pending: 0,
      );
    }

    var notificationsAllowed = true;
    var exactAlarmsAllowed = true;
    var pending = 0;

    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        notificationsAllowed = await android.areNotificationsEnabled() ?? false;
        exactAlarmsAllowed =
            await android.canScheduleExactNotifications() ?? false;
      }
      pending = (await _plugin.pendingNotificationRequests()).length;
    } catch (e) {
      if (kDebugMode) debugPrint('diagnostics: $e');
    }

    return NotificationDiagnostics(
      available: true,
      notificationsAllowed: notificationsAllowed,
      exactAlarmsAllowed: exactAlarmsAllowed,
      pending: pending,
    );
  }

  /// Asks for anything still missing, once per run.
  ///
  /// Called when a contract is saved rather than at launch: the prompt then
  /// arrives attached to an action that obviously needs reminders, instead of
  /// out of nowhere on the splash screen.
  Future<void> ensurePermissions() async {
    if (_permissionsChecked) return;
    _permissionsChecked = true;

    final preferences = await _preferencesRepository.load();
    if (!preferences.enabled) return;

    final status = await diagnostics();
    if (!status.available || status.isFullyGranted) return;

    await requestPermission();
  }

  /// True when the OS will actually deliver what we schedule.
  Future<bool> hasPermission() async {
    await initialize();
    if (!_available) return false;
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        return await android.areNotificationsEnabled() ?? false;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Asks for everything the reminders need. Call from a screen that has just
  /// explained what the reminders are for.
  Future<bool> requestPermission() async {
    await initialize();
    if (!_available) return false;

    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        final granted = await android.requestNotificationsPermission() ?? false;
        // Separate grant on Android 12+, and without it the scheduler quietly
        // downgrades to inexact timing — a return deadline could slip by hours.
        await android.requestExactAlarmsPermission();
        return granted;
      }

      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      if (ios != null) {
        return await ios.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            ) ??
            false;
      }

      final macos = _plugin.resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin>();
      if (macos != null) {
        return await macos.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            ) ??
            false;
      }
      return false;
    } catch (e) {
      if (kDebugMode) debugPrint('requestPermission: $e');
      return false;
    }
  }

  // --------------------------------------------------------------- scheduling

  /// Schedules every reminder a contract earns, replacing any it already had.
  Future<void> scheduleContractReminders({
    required int contractId,
    required String registrationNumber,
    required DateTime startDate,
    required DateTime expectedReturnDate,
    required double remainingAmount,
    bool requestPermissions = true,
  }) async {
    await initialize();
    if (!_available) return;

    // Rescheduling after an edit must not leave the previous times behind.
    await cancelContractNotifications(contractId);

    final preferences = await _preferencesRepository.load();
    if (!preferences.enabled) return;
    final language = await _language();

    // Saving a contract is the natural moment to discover the permissions are
    // missing — the alternative is scheduling reminders Android will silently
    // never deliver.
    if (requestPermissions) await ensurePermissions();

    try {
      final route = '/contracts/$contractId';
      final base = contractId * _slotsPerContract;
      final due = tz.TZDateTime.from(expectedReturnDate, tz.local);
      final pickup = tz.TZDateTime.from(startDate, tz.local);

      // Pickup, when the contract starts later than now.
      await _scheduleAt(
        id: base + _slotPickup,
        when: pickup.subtract(Duration(minutes: preferences.leadMinutes)),
        title:
            _copy(language, 'Départ prévu', 'Scheduled pickup', 'استلام مقرر'),
        body: _copy(
          language,
          'Le véhicule $registrationNumber doit être remis au client.',
          'Vehicle $registrationNumber must be handed to the client.',
          'يجب تسليم المركبة $registrationNumber إلى العميل.',
        ),
        channel: _channelContracts,
        channelName: _copy(language, 'Contrats', 'Contracts', 'العقود'),
        route: route,
        preferences: preferences,
      );

      await _scheduleAt(
        id: base + _slotReturnLead,
        when: due.subtract(Duration(minutes: preferences.leadMinutes)),
        title: _copy(
            language, 'Retour du véhicule', 'Vehicle return', 'إرجاع المركبة'),
        body: _copy(
          language,
          'Le véhicule $registrationNumber doit être retourné ${_describeLead(preferences.leadMinutes, language)}.',
          'Vehicle $registrationNumber must be returned ${_describeLead(preferences.leadMinutes, language)}.',
          'يجب إرجاع المركبة $registrationNumber ${_describeLead(preferences.leadMinutes, language)}.',
        ),
        channel: _channelContracts,
        channelName: _copy(language, 'Contrats', 'Contracts', 'العقود'),
        route: route,
        preferences: preferences,
      );

      await _scheduleAt(
        id: base + _slotReturnDue,
        when: due,
        title: _copy(
            language, 'Retour du véhicule', 'Vehicle return', 'إرجاع المركبة'),
        body: _copy(
          language,
          'Le véhicule $registrationNumber doit être retourné maintenant.',
          'Vehicle $registrationNumber must be returned now.',
          'يجب إرجاع المركبة $registrationNumber الآن.',
        ),
        channel: _channelContracts,
        channelName: _copy(language, 'Contrats', 'Contracts', 'العقود'),
        route: route,
        preferences: preferences,
        withViewAction: true,
      );

      // Daily nag while the vehicle is out, starting the day after the deadline.
      await _scheduleAt(
        id: base + _slotLateRepeat,
        when: firstOverdueReminderAt(due),
        title: _copy(
            language, 'Véhicule en retard', 'Late vehicle', 'مركبة متأخرة'),
        body: _copy(
          language,
          'Le véhicule $registrationNumber n\'a pas encore été retourné.',
          'Vehicle $registrationNumber has not been returned yet.',
          'لم تتم إعادة المركبة $registrationNumber بعد.',
        ),
        channel: _channelLate,
        channelName: _copy(language, 'Retards', 'Late returns', 'التأخيرات'),
        route: route,
        preferences: preferences,
        repeatDaily: true,
        allowPast: true,
        withViewAction: true,
      );

      if (preferences.paymentReminders && remainingAmount > 0) {
        await _scheduleAt(
          id: base + _slotPayment,
          when: due,
          title: _copy(language, 'Paiement en attente', 'Payment pending',
              'دفع قيد الانتظار'),
          body: _copy(
            language,
            '${remainingAmount.toStringAsFixed(0)} MAD restent à encaisser sur le contrat du véhicule $registrationNumber.',
            '${remainingAmount.toStringAsFixed(0)} MAD remain to be collected for vehicle $registrationNumber.',
            'يتبقى تحصيل ${remainingAmount.toStringAsFixed(0)} MAD لعقد المركبة $registrationNumber.',
          ),
          channel: _channelPayments,
          channelName: _copy(language, 'Paiements', 'Payments', 'المدفوعات'),
          route: route,
          preferences: preferences,
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('scheduleContractReminders: $e');
    }
  }

  Future<void> cancelContractNotifications(int contractId) async {
    await initialize();
    if (!_available) return;
    try {
      final base = contractId * _slotsPerContract;
      for (var slot = 0; slot < _slotsPerContract; slot++) {
        await _plugin.cancel(base + slot);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('cancelContractNotifications: $e');
    }
  }

  /// Date reminders are re-created every time a vehicle is saved. Mileage
  /// reminders are evaluated at that same moment because the odometer is only
  /// updated by the agency, not automatically by Android.
  Future<void> scheduleVehicleMaintenanceReminders(VehicleMaintenancePlan plan,
      {bool requestPermissions = true}) async {
    await initialize();
    if (!_available) return;
    final preferences = await _preferencesRepository.load();
    if (!preferences.enabled) return;
    final language = await _language();
    if (requestPermissions) await ensurePermissions();
    final dates = <({String name, DateTime? date})>[
      (name: 'Assurance', date: plan.insuranceExpiryDate),
      (name: 'Visite technique', date: plan.technicalInspectionExpiryDate),
      (name: 'Vignette', date: plan.vignetteDueDate),
      (name: 'Vidange', date: plan.oilChangeDueDate),
      (
        name: 'Courroie / chaîne de distribution',
        date: plan.distributionDueDate
      ),
    ];
    for (var category = 0; category < dates.length; category++) {
      for (var warning = 0;
          warning < vehicleDateWarningDays.length;
          warning++) {
        final id = _idVehicleBase + plan.vehicleId * 32 + category * 4 + warning;
        await _plugin.cancel(id);
        final due = dates[category].date;
        if (due == null) continue;
        final days = vehicleDateWarningDays[warning];
        await _scheduleAt(
          id: id,
          when:
              tz.TZDateTime.from(due, tz.local).subtract(Duration(days: days)),
          title: _renewalTitle(language, dates[category].name),
          body: _copy(
            language,
            '${plan.registrationNumber} : échéance dans $days jour${days > 1 ? 's' : ''}.',
            '${plan.registrationNumber}: due in $days day${days > 1 ? 's' : ''}.',
            '${plan.registrationNumber}: الاستحقاق خلال $days يوم.',
          ),
          channel: _channelVehicle,
          channelName: _copy(language, 'Véhicules', 'Vehicles', 'المركبات'),
          route: '/vehicles/${plan.vehicleId}',
          preferences: preferences,
        );
      }
    }
    await _evaluateMileageAlert(plan, 'oil', 'Vidange',
        plan.oilChangeDueMileage, preferences, 0, language);
    await _evaluateMileageAlert(plan, 'distribution', 'Courroie / chaîne',
        plan.distributionDueMileage, preferences, 1, language);
  }

  Future<void> _evaluateMileageAlert(
      VehicleMaintenancePlan plan,
      String key,
      String label,
      int? dueMileage,
      NotificationPreferences preferences,
      int category,
      AppLanguage language) async {
    if (dueMileage == null) return;
    final db = await DatabaseHelper.instance.database;
    await db.delete('vehicle_alert_history',
        where: 'vehicle_id = ? AND alert_key = ? AND due_mileage != ?',
        whereArgs: [plan.vehicleId, key, dueMileage]);
    final remaining = dueMileage - plan.currentMileage;
    for (var i = 0; i < vehicleMileageWarningKm.length; i++) {
      final threshold = vehicleMileageWarningKm[i];
      if (remaining > threshold) continue;
      final seen = await db.query('vehicle_alert_history',
          where:
              'vehicle_id = ? AND alert_key = ? AND threshold = ? AND due_mileage = ?',
          whereArgs: [plan.vehicleId, key, threshold, dueMileage],
          limit: 1);
      if (seen.isNotEmpty) continue;
      final body = remaining <= 0
          ? _copy(
              language,
              '${plan.registrationNumber} : entretien à faire maintenant.',
              '${plan.registrationNumber}: maintenance is due now.',
              '${plan.registrationNumber}: الصيانة مستحقة الآن.',
            )
          : _copy(
              language,
              '${plan.registrationNumber} : entretien dans $remaining km.',
              '${plan.registrationNumber}: maintenance due in $remaining km.',
              '${plan.registrationNumber}: الصيانة مستحقة خلال $remaining كم.',
            );
      await _show(
          id: _idVehicleBase + plan.vehicleId * 32 + 24 + category * 3 + i,
          title: _t(language, label),
          body: body,
          channel: _channelVehicle,
          channelName: _copy(language, 'Véhicules', 'Vehicles', 'المركبات'),
          route: '/vehicles/${plan.vehicleId}',
          preferences: preferences);
      await db.insert('vehicle_alert_history', {
        'vehicle_id': plan.vehicleId,
        'alert_key': key,
        'threshold': threshold,
        'due_mileage': dueMileage
      });
    }
  }

  /// Warns before the licence runs out, while there is still time to renew.
  Future<void> scheduleLicenseExpiry(DateTime expiryDate) async {
    await initialize();
    if (!_available) return;

    try {
      for (var i = 0; i < licenseWarningDays.length; i++) {
        await _plugin.cancel(_idLicenseBase + i);
      }

      final preferences = await _preferencesRepository.load();
      if (!preferences.enabled || !preferences.licenseAlerts) return;
      final language = await _language();

      final expiry = tz.TZDateTime.from(expiryDate, tz.local);
      for (var i = 0; i < licenseWarningDays.length; i++) {
        final days = licenseWarningDays[i];
        // 09:00 so the warning lands during working hours, not at midnight.
        final when = tz.TZDateTime(
          tz.local,
          expiry.year,
          expiry.month,
          expiry.day,
          9,
        ).subtract(Duration(days: days));

        await _scheduleAt(
          id: _idLicenseBase + i,
          when: when,
          title: _copy(language, 'Licence bientôt expirée',
              'Licence expiring soon', 'الترخيص سينتهي قريباً'),
          body: days == 1
              ? _copy(
                  language,
                  'Votre licence expire demain. Contactez votre fournisseur.',
                  'Your licence expires tomorrow. Contact your provider.',
                  'سينتهي ترخيصك غداً. تواصل مع مزودك.',
                )
              : _copy(
                  language,
                  'Votre licence expire dans $days jours. Pensez à la renouveler.',
                  'Your licence expires in $days days. Remember to renew it.',
                  'سينتهي ترخيصك خلال $days أيام. تذكّر تجديده.',
                ),
          channel: _channelLicense,
          channelName: _copy(language, 'Licence', 'Licence', 'الترخيص'),
          route: '/settings',
          preferences: preferences,
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('scheduleLicenseExpiry: $e');
    }
  }

  /// Identifies a set of overdue contracts, so an unchanged set can be
  /// recognised and left alone instead of alerting again.
  @visibleForTesting
  static String digestSignature(Iterable<int> contractIds) {
    final sorted = contractIds.toList()..sort();
    return sorted.join(',');
  }

  /// Clears the overdue summary. Called when the app comes to the foreground:
  /// the user is looking at the dashboard, which already shows the same count.
  Future<void> dismissLateDigest() async {
    await initialize();
    if (!_available) return;
    try {
      await _plugin.cancel(_idLateDigest);
    } catch (e) {
      if (kDebugMode) debugPrint('dismissLateDigest: $e');
    }
  }

  /// One summary for everything overdue, rather than a separate alert per
  /// vehicle.
  ///
  /// Safe to call repeatedly: it alerts only when the set of overdue vehicles
  /// has actually changed, and never while the app is open. Without both
  /// guards, every return to the app re-fired the alert — including the return
  /// caused by tapping the notification itself.
  Future<void> notifyLateVehicles() async {
    await initialize();
    if (!_available) return;
    if (_appInForeground) return;

    try {
      final preferences = await _preferencesRepository.load();
      if (!preferences.enabled) return;
      final language = await _language();

      final db = await DatabaseHelper.instance.database;
      final rows = await db.rawQuery('''
        SELECT c.id AS contract_id, c.expected_return_date, v.registration_number
        FROM contracts c
        JOIN vehicles v ON v.id = c.vehicle_id
        WHERE c.status = 'active' AND c.expected_return_date < ?
        ORDER BY c.expected_return_date ASC
      ''', [DateTime.now().toIso8601String()]);

      final now = tz.TZDateTime.now(tz.local);
      final eligibleRows = rows.where((row) {
        final due = tz.TZDateTime.from(
            DateTime.parse(row['expected_return_date'] as String), tz.local);
        return !firstOverdueReminderAt(due).isAfter(now);
      }).toList();

      if (eligibleRows.isEmpty) {
        await _plugin.cancel(_idLateDigest);
        await _store.deleteString(keyLateDigestSignature);
        return;
      }

      // Nothing new is overdue since the last alert, so stay quiet. Showing
      // the same notification again would sound and vibrate afresh.
      final signature = digestSignature(
        eligibleRows.map((row) => row['contract_id'] as int),
      );
      if (signature == await _store.getString(keyLateDigestSignature)) {
        return;
      }
      await _store.setString(keyLateDigestSignature, signature);

      final plates = eligibleRows
          .map((row) => row['registration_number'] as String?)
          .whereType<String>()
          .toList();

      final single = eligibleRows.length == 1;
      await _show(
        id: _idLateDigest,
        title: single
            ? _copy(
                language, 'Véhicule en retard', 'Late vehicle', 'مركبة متأخرة')
            : _copy(
                language,
                '${eligibleRows.length} véhicules en retard',
                '${eligibleRows.length} late vehicles',
                '${eligibleRows.length} مركبات متأخرة',
              ),
        body: single
            ? _copy(
                language,
                'Le véhicule ${plates.first} est en retard de retour.',
                'Vehicle ${plates.first} has a late return.',
                'إرجاع المركبة ${plates.first} متأخر.',
              )
            : plates.take(4).join(', ') + (plates.length > 4 ? '…' : ''),
        channel: _channelLate,
        channelName: _copy(language, 'Retards', 'Late returns', 'التأخيرات'),
        route: single
            ? '/contracts/${eligibleRows.first['contract_id']}'
            : '/contracts',
        preferences: preferences,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('notifyLateVehicles: $e');
    }
  }

  Future<void> cancelAll() async {
    await initialize();
    if (!_available) return;
    try {
      await _plugin.cancelAll();
    } catch (e) {
      if (kDebugMode) debugPrint('cancelAll: $e');
    }
  }

  // ------------------------------------------------------------------ helpers

  @visibleForTesting
  static tz.TZDateTime firstOverdueReminderAt(tz.TZDateTime due) =>
      tz.TZDateTime(due.location, due.year, due.month, due.day + 1, due.hour,
          due.minute, due.second);

  static String _describeLead(int minutes, AppLanguage language) {
    if (minutes >= 1440) {
      return _copy(language, 'demain', 'tomorrow', 'غداً');
    }
    if (minutes >= 60) {
      final hours = minutes ~/ 60;
      return _copy(
        language,
        'dans $hours heure${hours > 1 ? 's' : ''}',
        'in $hours hour${hours > 1 ? 's' : ''}',
        'خلال $hours ساعة',
      );
    }
    return _copy(language, 'dans $minutes minutes', 'in $minutes minutes',
        'خلال $minutes دقيقة');
  }

  Future<AppLanguage> _language() async => AppLanguage.fromCode(await _store
      .getString(AppSettingsRepository.keyLanguage, defaultValue: 'fr'));

  static String _t(AppLanguage language, String source) =>
      AppLocalizations.translate(language.locale, source);

  static String _copy(
    AppLanguage language,
    String french,
    String english,
    String arabic,
  ) =>
      switch (language) {
        AppLanguage.french => french,
        AppLanguage.english => english,
        AppLanguage.arabic => arabic,
      };

  static String _renewalTitle(AppLanguage language, String document) {
    final name = _t(language, document);
    return _copy(
        language, '$document à renouveler', '$name to renew', '$name للتجديد');
  }

  /// Moves [when] out of the user's quiet window, to the hour it ends.
  ///
  /// Pure and static so the wrap-around cases can be tested without a plugin.
  @visibleForTesting
  static tz.TZDateTime applyQuietHours(
    tz.TZDateTime when,
    NotificationPreferences preferences,
  ) {
    if (!preferences.isQuiet(when.hour)) {
      return when;
    }

    var target = tz.TZDateTime(
      when.location,
      when.year,
      when.month,
      when.day,
      preferences.quietEndHour,
    );
    // A quiet window that wraps midnight puts the late-evening hours before
    // the following morning's end time.
    if (!target.isAfter(when)) {
      target = target.add(const Duration(days: 1));
    }
    return target;
  }

  Future<void> _scheduleAt({
    required int id,
    required tz.TZDateTime when,
    required String title,
    required String body,
    required String channel,
    required String channelName,
    required String route,
    required NotificationPreferences preferences,
    bool repeatDaily = false,
    bool allowPast = false,
    bool withViewAction = false,
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    if (!allowPast && !when.isAfter(now)) {
      return;
    }

    var target = applyQuietHours(when, preferences);
    // A daily repeat anchored in the past never fires; walk it forward.
    if (repeatDaily) {
      while (!target.isAfter(now)) {
        target = firstOverdueReminderAt(target);
      }
    } else if (!target.isAfter(now)) {
      return;
    }

    final details = _details(
      channel: channel,
      channelName: channelName,
      grouped: channel == _channelLate,
      withViewAction: withViewAction,
    );
    if (repeatDaily && defaultTargetPlatform == TargetPlatform.android) {
      await AndroidDailyReminder.schedule(
        id: id,
        title: title,
        body: body,
        firstOccurrence: target,
        details: details.android!,
        route: route,
      );
      return;
    }

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      target,
      details,
      payload: route,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: repeatDaily ? DateTimeComponents.time : null,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> _show({
    required int id,
    required String title,
    required String body,
    required String channel,
    required String channelName,
    required String route,
    required NotificationPreferences preferences,
  }) async {
    final now = tz.TZDateTime.now(tz.local);

    // During quiet hours, hold it until the window ends rather than dropping
    // it: an overdue vehicle still needs chasing in the morning.
    if (preferences.isQuiet(now.hour)) {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        applyQuietHours(now, preferences),
        _details(
          channel: channel,
          channelName: channelName,
          grouped: true,
          onlyAlertOnce: true,
        ),
        payload: route,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      return;
    }

    await _plugin.show(
      id,
      title,
      body,
      _details(
        channel: channel,
        channelName: channelName,
        grouped: true,
        onlyAlertOnce: true,
      ),
      payload: route,
    );
  }

  NotificationDetails _details({
    required String channel,
    required String channelName,
    bool grouped = false,
    bool withViewAction = false,
    bool onlyAlertOnce = false,
  }) {
    final androidDetails = AndroidNotificationDetails(
      channel,
      channelName,
      channelDescription: 'Rappels de $channelName',
      importance: Importance.max,
      priority: Priority.high,
      // Updating a notification that is already on screen should refresh its
      // text silently, not sound and vibrate again.
      onlyAlertOnce: onlyAlertOnce,
      groupKey: grouped ? _lateGroupKey : null,
      actions: withViewAction
          ? <AndroidNotificationAction>[
              const AndroidNotificationAction(
                actionViewContract,
                'Voir le contrat',
                // Closing a contract may need a payment settled first, so the
                // action opens the app rather than mutating anything blind.
                showsUserInterface: true,
              ),
            ]
          : null,
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    return NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );
  }
}
