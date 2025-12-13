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
            AndroidFlutterLocalNotificationsPlugin
          >();
      await androidSpecific?.createNotificationChannel(_medicationChannel);
      await androidSpecific?.requestNotificationsPermission();
      try {
        await androidSpecific?.requestExactAlarmsPermission();
      } catch (error) {
        debugPrint(
          'NotificationService: exact alarm permission request failed: $error',
        );
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
        'NotificationService: platform notifications disabled, skipping scheduling.',
      );
      return;
    }

    final hasExact = await _hasExactAlarmCapability();
    if (!hasExact) {
      debugPrint(
        'NotificationService: exact alarm capability unavailable. Reminders may be delayed.',
      );
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
          'NotificationService: unable to schedule ${medication.name} -> $error',
        );
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

  /// Forces re-detection of the timezone. Call this to fix timezone issues.
  Future<String> forceReinitializeTimezone() async {
    if (kIsWeb) {
      return 'Web platform - not applicable';
    }

    _timezoneInitialized = false;
    tz.initializeTimeZones();

    // Get the actual system offset first
    final now = DateTime.now();
    final systemOffset = now.timeZoneOffset;
    final systemOffsetHours = systemOffset.inHours;
    final systemOffsetMinutes = systemOffset.inMinutes.remainder(60).abs();
    final systemOffsetStr =
        '${systemOffset.isNegative ? "-" : "+"}${systemOffsetHours.abs().toString().padLeft(2, "0")}:${systemOffsetMinutes.toString().padLeft(2, "0")}';

    debugPrint('NotificationService: System offset is $systemOffsetStr');

    // Try FlutterTimezone first, but validate the result
    try {
      final timezone = await FlutterTimezone.getLocalTimezone();
      final resolved = _resolveTimezoneName(timezone);
      final normalized = _normalizeTimezoneName(resolved);

      // Check if FlutterTimezone returned UTC but system offset is not 0
      if ((normalized == 'UTC' || normalized == 'Etc/UTC') &&
          systemOffset.inMinutes != 0) {
        debugPrint(
          'NotificationService: FlutterTimezone returned UTC but system offset is $systemOffsetStr, using fallback',
        );
      } else {
        final location = tz.getLocation(normalized);
        tz.setLocalLocation(location);
        _timezoneInitialized = true;
        debugPrint('NotificationService: timezone set to ${location.name}');
        return 'Set to: ${location.name} (from FlutterTimezone, system: $systemOffsetStr)';
      }
    } catch (error) {
      debugPrint('NotificationService: FlutterTimezone failed: $error');
    }

    // Fallback: Use a known timezone for the system offset
    try {
      // Map of UTC offsets to known IANA timezone names
      final offsetToTimezone = <int, String>{
        -12: 'Etc/GMT+12',
        -11: 'Pacific/Midway',
        -10: 'Pacific/Honolulu',
        -9: 'America/Anchorage',
        -8: 'America/Los_Angeles',
        -7: 'America/Denver',
        -6: 'America/Chicago',
        -5: 'America/New_York',
        -4: 'America/Halifax',
        -3: 'America/Sao_Paulo',
        -2: 'Atlantic/South_Georgia',
        -1: 'Atlantic/Azores',
        0: 'UTC',
        1: 'Europe/Paris',
        2: 'Europe/Helsinki',
        3: 'Europe/Istanbul',
        4: 'Asia/Dubai',
        5: 'Asia/Karachi',
        6: 'Asia/Dhaka',
        7: 'Asia/Bangkok',
        8: 'Asia/Singapore',
        9: 'Asia/Tokyo',
        10: 'Australia/Sydney',
        11: 'Pacific/Noumea',
        12: 'Pacific/Auckland',
      };

      final targetTimezone = offsetToTimezone[systemOffsetHours];
      if (targetTimezone != null && systemOffsetMinutes == 0) {
        final location = tz.getLocation(targetTimezone);
        tz.setLocalLocation(location);
        _timezoneInitialized = true;
        debugPrint('NotificationService: timezone set to ${location.name}');
        return 'Set to: ${location.name} (from system offset $systemOffsetStr)';
      } else {
        // Unknown offset or has minutes component
        tz.setLocalLocation(tz.getLocation('UTC'));
        _timezoneInitialized = true;
        return 'Set to UTC (unsupported offset: $systemOffsetStr)';
      }
    } catch (error) {
      debugPrint('NotificationService: Fallback failed: $error');
      tz.setLocalLocation(tz.getLocation('UTC'));
      _timezoneInitialized = true;
      return 'Fallback to UTC (error: $error)';
    }
  }

  Future<void> _ensureTimezone() async {
    if (_timezoneInitialized || kIsWeb) {
      return;
    }

    tz.initializeTimeZones();

    // Get the actual system offset
    final now = DateTime.now();
    final systemOffset = now.timeZoneOffset;

    // Try FlutterTimezone first
    try {
      final timezone = await FlutterTimezone.getLocalTimezone();
      final resolved = _resolveTimezoneName(timezone);
      final normalized = _normalizeTimezoneName(resolved);

      // Validate result - if FlutterTimezone returns UTC but system offset is not 0, use fallback
      if ((normalized == 'UTC' || normalized == 'Etc/UTC') &&
          systemOffset.inMinutes != 0) {
        debugPrint(
          'NotificationService: FlutterTimezone returned UTC but system offset is non-zero, using fallback',
        );
      } else {
        final location = tz.getLocation(normalized);
        tz.setLocalLocation(location);
        debugPrint('NotificationService: timezone set to ${location.name}');
        _timezoneInitialized = true;
        return;
      }
    } catch (error) {
      debugPrint(
        'NotificationService: FlutterTimezone failed: $error, trying fallback...',
      );
    }

    // Fallback: Use a known timezone for the system offset
    try {
      final offsetHours = systemOffset.inHours;
      final offsetMinutes = systemOffset.inMinutes.remainder(60).abs();

      debugPrint(
        'NotificationService: System offset is ${systemOffset.isNegative ? "-" : "+"}${offsetHours.abs()}:${offsetMinutes.toString().padLeft(2, "0")}',
      );

      // Map of UTC offsets to known IANA timezone names
      final offsetToTimezone = <int, String>{
        -12: 'Etc/GMT+12',
        -11: 'Pacific/Midway',
        -10: 'Pacific/Honolulu',
        -9: 'America/Anchorage',
        -8: 'America/Los_Angeles',
        -7: 'America/Denver',
        -6: 'America/Chicago',
        -5: 'America/New_York',
        -4: 'America/Halifax',
        -3: 'America/Sao_Paulo',
        -2: 'Atlantic/South_Georgia',
        -1: 'Atlantic/Azores',
        0: 'UTC',
        1: 'Europe/Paris',
        2: 'Europe/Helsinki',
        3: 'Europe/Istanbul',
        4: 'Asia/Dubai',
        5: 'Asia/Karachi',
        6: 'Asia/Dhaka',
        7: 'Asia/Bangkok',
        8: 'Asia/Singapore',
        9: 'Asia/Tokyo',
        10: 'Australia/Sydney',
        11: 'Pacific/Noumea',
        12: 'Pacific/Auckland',
      };

      final targetTimezone = offsetToTimezone[offsetHours];
      if (targetTimezone != null && offsetMinutes == 0) {
        final location = tz.getLocation(targetTimezone);
        tz.setLocalLocation(location);
        debugPrint(
          'NotificationService: timezone set to ${location.name} (from system offset)',
        );
        _timezoneInitialized = true;
        return;
      }
    } catch (error) {
      debugPrint('NotificationService: Offset detection failed: $error');
    }

    // Final fallback to UTC
    debugPrint('NotificationService: Falling back to UTC');
    tz.setLocalLocation(tz.getLocation('UTC'));
    _timezoneInitialized = true;
  }

  Future<bool> _areNotificationsEnabled() async {
    if (kIsWeb) {
      return false;
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      final androidSpecific = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
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
          AndroidFlutterLocalNotificationsPlugin
        >();
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

    final offsetMatch = RegExp(
      r'^(?:GMT|UTC)([+-])(\d{1,2})(?::(\d{2}))?$',
    ).firstMatch(trimmed);
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

  Future<void> _scheduleMedication(int baseId, Medication medication) async {
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

    // Schedule a notification for each time in the medication's times list
    for (var i = 0; i < medication.times.length; i++) {
      final time = medication.times[i];
      final scheduleDate = _nextInstanceOfTime(time);
      // Use unique ID for each time slot: baseId * 100 + time index
      final notificationId = baseId * 100 + i;

      await _plugin.zonedSchedule(
        notificationId,
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
        'NotificationService: scheduled ${medication.name} (${medication.dose}) for $readable with id $notificationId',
      );
    }
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

  /// Shows an immediate test notification to verify the notification system works.
  Future<bool> showTestNotification() async {
    if (kIsWeb) {
      debugPrint(
        'NotificationService: Web platform - notifications not supported',
      );
      return false;
    }

    await initialize();

    try {
      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          'test_channel',
          'Test Notifications',
          channelDescription: 'Test notification channel',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
        macOS: DarwinNotificationDetails(),
      );

      await _plugin.show(
        9999,
        'Test Notification',
        'If you see this, notifications are working!',
        details,
      );
      debugPrint('NotificationService: Test notification sent successfully');
      return true;
    } catch (error, stackTrace) {
      debugPrint(
        'NotificationService: Failed to show test notification: $error',
      );
      debugPrint('$stackTrace');
      return false;
    }
  }

  /// Schedules a test notification for 10 seconds from now.
  Future<String> showScheduledTestNotification() async {
    if (kIsWeb) {
      return 'Error: Web platform does not support scheduled notifications';
    }

    await initialize();

    try {
      final now = tz.TZDateTime.now(tz.local);
      final scheduledTime = now.add(const Duration(seconds: 10));

      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          'test_channel',
          'Test Notifications',
          channelDescription: 'Test notification channel',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
        macOS: DarwinNotificationDetails(),
      );

      await _plugin.zonedSchedule(
        9998,
        'Scheduled Test',
        'This notification was scheduled 10 seconds ago!',
        scheduledTime,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );

      final msg = 'Scheduled for: $scheduledTime (${tz.local.name})';
      debugPrint('NotificationService: $msg');
      return msg;
    } catch (error, stackTrace) {
      debugPrint('NotificationService: Failed to schedule test: $error');
      debugPrint('$stackTrace');
      return 'Error: $error';
    }
  }

  /// Returns diagnostic information about the notification system.
  Future<Map<String, dynamic>> getDiagnostics() async {
    final diagnostics = <String, dynamic>{
      'platform': defaultTargetPlatform.toString(),
      'isWeb': kIsWeb,
      'initialized': _initialized,
      'timezoneInitialized': _timezoneInitialized,
    };

    if (kIsWeb) {
      diagnostics['error'] = 'Notifications not supported on web';
      return diagnostics;
    }

    await initialize();

    try {
      diagnostics['timezone'] = tz.local.name;
    } catch (e) {
      diagnostics['timezone'] = 'Error: $e';
    }

    // Add system offset for comparison
    try {
      final offset = DateTime.now().timeZoneOffset;
      diagnostics['systemOffset'] =
          '${offset.isNegative ? "-" : "+"}${offset.inHours.abs()}:${(offset.inMinutes.remainder(60).abs()).toString().padLeft(2, "0")}';
    } catch (e) {
      diagnostics['systemOffset'] = 'Error: $e';
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      final androidSpecific = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

      if (androidSpecific != null) {
        try {
          diagnostics['notificationsEnabled'] =
              await androidSpecific.areNotificationsEnabled() ?? false;
        } catch (e) {
          diagnostics['notificationsEnabled'] = 'Error: $e';
        }

        try {
          diagnostics['canScheduleExactAlarms'] =
              await androidSpecific.canScheduleExactNotifications() ?? false;
        } catch (e) {
          diagnostics['canScheduleExactAlarms'] = 'Error: $e';
        }
      }
    }

    try {
      final pending = await _plugin.pendingNotificationRequests();
      diagnostics['pendingNotifications'] = pending.length;
      diagnostics['pendingIds'] = pending
          .map((p) => '${p.id}: ${p.title}')
          .toList();
    } catch (e) {
      diagnostics['pendingNotifications'] = 'Error: $e';
    }

    return diagnostics;
  }
}
