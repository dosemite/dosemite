import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/medication.dart';
import '../utils/translations.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _medicationChannel =
      AndroidNotificationChannel(
    'medication_reminders',
    'Medication Reminders',
    description: 'Dose reminders for your medication schedule',
    importance: Importance.max,
  );

  bool _initialized = false;
  bool _timezoneInitialized = false;

  Future<void> initialize() async {
    if (_initialized || kIsWeb) {
      return;
    }

    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
      macOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );

  await _plugin.initialize(initializationSettings);

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      final androidSpecific = _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await androidSpecific?.createNotificationChannel(_medicationChannel);
      await androidSpecific?.requestNotificationsPermission();
      try {
        await androidSpecific?.requestExactAlarmsPermission();
      } catch (error) {
        debugPrint(
            'NotificationService: exact alarm permission request failed: $error');
      }
    }

    await _ensureTimezone();
    _initialized = true;
  }

  Future<void> syncMedications(
    List<Medication> medications, {
    required bool notificationsEnabled,
  }) async {
    if (kIsWeb) {
      return;
    }

    await initialize();

    if (!notificationsEnabled) {
      await _plugin.cancelAll();
      return;
    }

    final notificationsAllowed = await _areNotificationsEnabled();
    if (!notificationsAllowed) {
      await _plugin.cancelAll();
      debugPrint(
          'NotificationService: platform notifications disabled, skipping scheduling.');
      return;
    }

    final hasExact = await _hasExactAlarmCapability();
    if (!hasExact) {
      debugPrint(
          'NotificationService: exact alarm capability unavailable. Reminders may be delayed.');
    }

    await _plugin.cancelAll();

    for (final entry in medications.asMap().entries) {
      final medication = entry.value;
      if (!medication.isCourseActive) {
        continue;
      }
      try {
        await _scheduleMedication(entry.key + 1, medication);
      } catch (error, stackTrace) {
        debugPrint(
            'NotificationService: unable to schedule ${medication.name} -> $error');
        debugPrint('$stackTrace');
      }
    }
  }

  Future<void> cancelAll() async {
    if (kIsWeb || !_initialized) {
      return;
    }
    await _plugin.cancelAll();
  }

  Future<void> _ensureTimezone() async {
    if (_timezoneInitialized || kIsWeb) {
      return;
    }

    tz.initializeTimeZones();
    try {
      final timezone = await FlutterTimezone.getLocalTimezone();
      final resolved = _resolveTimezoneName(timezone);
      final normalized = _normalizeTimezoneName(resolved);
      final location = tz.getLocation(normalized);
      tz.setLocalLocation(location);
      debugPrint('NotificationService: timezone set to ${location.name}');
    } catch (error) {
      debugPrint(
          'NotificationService: unable to resolve timezone, defaulting to UTC -> $error');
      tz.setLocalLocation(tz.getLocation('UTC'));
    }

    _timezoneInitialized = true;
  }

  Future<bool> _areNotificationsEnabled() async {
    if (kIsWeb) {
      return false;
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      final androidSpecific = _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      final enabled = await androidSpecific?.areNotificationsEnabled();
      return enabled ?? true;
    }

    return true;
  }

  Future<bool> _hasExactAlarmCapability() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return true;
    }

    final androidSpecific = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidSpecific == null) {
      return false;
    }
    try {
      final granted = await androidSpecific.canScheduleExactNotifications();
      return granted ?? true;
    } catch (_) {
      return false;
    }
  }

  String _resolveTimezoneName(dynamic timezone) {
    if (timezone is String && timezone.isNotEmpty) {
      return timezone;
    }
    try {
      final name = timezone?.name as String?;
      if (name != null && name.isNotEmpty) {
        return name;
      }
    } catch (_) {}
    try {
      final databaseName = timezone?.databaseName as String?;
      if (databaseName != null && databaseName.isNotEmpty) {
        return databaseName;
      }
    } catch (_) {}
    try {
      final alternate = timezone?.timezone as String?;
      if (alternate != null && alternate.isNotEmpty) {
        return alternate;
      }
    } catch (_) {}
    return 'UTC';
  }

  String _normalizeTimezoneName(String name) {
    if (name.isEmpty) {
      return 'UTC';
    }

    final trimmed = name.trim();
    if (trimmed == 'UTC' || trimmed == 'Etc/UTC') {
      return 'UTC';
    }

  final offsetMatch =
    RegExp(r'^(?:GMT|UTC)([+-])(\d{1,2})(?::(\d{2}))?$')
        .firstMatch(trimmed);
    if (offsetMatch != null) {
      final sign = offsetMatch.group(1)!;
      final hours = int.parse(offsetMatch.group(2)!);
      final minutes = offsetMatch.group(3);
      if (minutes == null || int.parse(minutes) == 0) {
        // IANA Etc/GMT has inverted sign convention.
        final etcSign = sign == '+' ? '-' : '+';
        return 'Etc/GMT$etcSign$hours';
      }
    }

    return trimmed;
  }

  Future<void> _scheduleMedication(int id, Medication medication) async {
    final scheduleDate = _nextInstanceOfTime(medication.time);

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _medicationChannel.id,
        _medicationChannel.name,
        channelDescription: _medicationChannel.description,
        importance: Importance.max,
        priority: Priority.high,
        ticker: 'medication',
      ),
      iOS: const DarwinNotificationDetails(),
      macOS: const DarwinNotificationDetails(),
    );

    await _plugin.zonedSchedule(
      id,
      Translations.reminderTitle(medication.name),
      Translations.reminderBody(medication.dose),
      scheduleDate,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );

  final readable =
    '${scheduleDate.toString()} (${scheduleDate.location.name})';
  debugPrint(
    'NotificationService: scheduled ${medication.name} (${medication.dose}) for $readable with id $id');
  }

  tz.TZDateTime _nextInstanceOfTime(TimeOfDay time) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }
}
