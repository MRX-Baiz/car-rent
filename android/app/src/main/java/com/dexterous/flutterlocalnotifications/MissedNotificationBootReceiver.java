package com.dexterous.flutterlocalnotifications;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;

import androidx.annotation.Keep;

import com.dexterous.flutterlocalnotifications.models.NotificationDetails;
import com.dexterous.flutterlocalnotifications.models.ScheduledNotificationRepeatFrequency;
import com.google.gson.Gson;
import com.google.gson.reflect.TypeToken;

import java.lang.reflect.Type;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.time.ZonedDateTime;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.Iterator;

/**
 * Android removes alarms while the phone is off. The notification plugin restores
 * them after boot, but a one-time reminder whose time already passed stays lost.
 * Show such reminders on boot, remove the one-time entries, then let the plugin
 * restore the remaining future alarms.
 */
@Keep
public final class MissedNotificationBootReceiver extends BroadcastReceiver {
  private static final String SCHEDULED_NOTIFICATIONS = "scheduled_notifications";

  @Override
  public void onReceive(Context context, Intent intent) {
    String action = intent.getAction();
    if (!Intent.ACTION_BOOT_COMPLETED.equals(action)
        && !Intent.ACTION_MY_PACKAGE_REPLACED.equals(action)
        && !"android.intent.action.QUICKBOOT_POWERON".equals(action)
        && !"com.htc.intent.action.QUICKBOOT_POWERON".equals(action)) {
      return;
    }

    // Reinstalling an app update must restore future reminders but must not
    // replay a contract notification that was already stale before the update.
    if (Intent.ACTION_MY_PACKAGE_REPLACED.equals(action)) {
      FlutterLocalNotificationsPlugin.rescheduleNotifications(context);
      return;
    }

    SharedPreferences preferences =
        context.getSharedPreferences(SCHEDULED_NOTIFICATIONS, Context.MODE_PRIVATE);
    String json = preferences.getString(SCHEDULED_NOTIFICATIONS, null);
    if (json == null) {
      FlutterLocalNotificationsPlugin.rescheduleNotifications(context);
      return;
    }

    Gson gson = FlutterLocalNotificationsPlugin.buildGson();
    Type type = new TypeToken<ArrayList<NotificationDetails>>() {}.getType();
    ArrayList<NotificationDetails> notifications = gson.fromJson(json, type);
    if (notifications == null) {
      FlutterLocalNotificationsPlugin.rescheduleNotifications(context);
      return;
    }

    boolean changed = false;
    ZonedDateTime now = ZonedDateTime.now();
    for (Iterator<NotificationDetails> it = notifications.iterator(); it.hasNext(); ) {
      NotificationDetails notification = it.next();
      if (!hasPassed(notification, now)) {
        continue;
      }

      FlutterLocalNotificationsPlugin.showNotification(context, notification);
      changed = true;

      if (notification.scheduledNotificationRepeatFrequency == null) {
        it.remove();
      } else if (notification.scheduledNotificationRepeatFrequency
          == ScheduledNotificationRepeatFrequency.Daily) {
        notification.scheduledDateTime = nextDailyOccurrence(notification, now);
      }
    }

    if (changed) {
      preferences.edit().putString(SCHEDULED_NOTIFICATIONS, gson.toJson(notifications)).commit();
    }
    FlutterLocalNotificationsPlugin.rescheduleNotifications(context);
  }

  private static boolean hasPassed(NotificationDetails notification, ZonedDateTime now) {
    if (notification.scheduledDateTime == null || notification.timeZoneName == null) {
      return false;
    }
    ZoneId zone = ZoneId.of(notification.timeZoneName);
    ZonedDateTime scheduled = ZonedDateTime.of(
        LocalDateTime.parse(notification.scheduledDateTime), zone);
    return !scheduled.isAfter(now.withZoneSameInstant(zone));
  }

  private static String nextDailyOccurrence(NotificationDetails notification, ZonedDateTime now) {
    ZoneId zone = ZoneId.of(notification.timeZoneName);
    ZonedDateTime next = ZonedDateTime.of(
        LocalDateTime.parse(notification.scheduledDateTime), zone);
    ZonedDateTime localNow = now.withZoneSameInstant(zone);
    while (!next.isAfter(localNow)) {
      next = next.plusDays(1);
    }
    return DateTimeFormatter.ISO_LOCAL_DATE_TIME.format(next);
  }
}
