import 'package:flutter/material.dart';

enum MedicationPeriod { morning, afternoon, evening }

class Medication {
  Medication({
    required this.name,
    required this.dose,
    required this.time,
    required this.period,
    this.notes,
    this.isEnabled = true,
    this.isHistoric = false,
    DateTime? createdAt,
    this.courseEndDate,
    this.totalQuantity,
    int? remainingQuantity,
    List<DateTime>? intakeHistory,
  }) : createdAt = createdAt ?? DateTime.now(),
       remainingQuantity = remainingQuantity ?? totalQuantity,
       intakeHistory = List<DateTime>.unmodifiable(
         intakeHistory ?? const <DateTime>[],
       );

  final String name;
  final String dose;
  final TimeOfDay time;
  final MedicationPeriod period;
  final String? notes;
  final bool isEnabled;
  final bool isHistoric;
  final DateTime createdAt;
  final DateTime? courseEndDate;
  final int? totalQuantity;
  final int? remainingQuantity;
  final List<DateTime> intakeHistory;

  factory Medication.fromJson(Map<String, dynamic> json) {
    final rawName = json['name'];
    final rawDose = json['dose'];
    final rawTime = json['time'];
    final rawPeriod = json['period'];

    if (rawName is! String || rawDose is! String || rawTime is! String) {
      throw const FormatException(
        'Medication json missing required string fields',
      );
    }

    final time = _parseTime(rawTime);
    final period = _parsePeriod(rawPeriod);

    return Medication(
      name: rawName,
      dose: rawDose,
      time: time,
      period: period,
      notes: json['notes'] as String?,
      isEnabled: json['isEnabled'] is bool ? json['isEnabled'] as bool : true,
      isHistoric: json['isHistoric'] is bool
          ? json['isHistoric'] as bool
          : false,
      createdAt: _parseDateTime(json['createdAt']) ?? DateTime.now(),
      courseEndDate: _parseDateTime(json['courseEndDate']),
      totalQuantity: _parseInt(json['totalQuantity']),
      remainingQuantity: _parseInt(json['remainingQuantity']),
      intakeHistory: _parseHistory(json['intakeHistory']),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'name': name,
    'dose': dose,
    'time': _formatTime(time),
    'period': _formatPeriod(period),
    if (notes != null) 'notes': notes,
    'isEnabled': isEnabled,
    'isHistoric': isHistoric,
    'createdAt': createdAt.toIso8601String(),
    if (courseEndDate != null)
      'courseEndDate': courseEndDate!.toIso8601String(),
    if (totalQuantity != null) 'totalQuantity': totalQuantity,
    if (remainingQuantity != null) 'remainingQuantity': remainingQuantity,
    if (intakeHistory.isNotEmpty)
      'intakeHistory': intakeHistory
          .map((dt) => dt.toIso8601String())
          .toList(growable: false),
  };

  Medication copyWith({
    String? name,
    String? dose,
    TimeOfDay? time,
    MedicationPeriod? period,
    String? notes,
    bool? isEnabled,
    bool? isHistoric,
    DateTime? createdAt,
    DateTime? courseEndDate,
    int? totalQuantity,
    int? remainingQuantity,
    List<DateTime>? intakeHistory,
  }) {
    return Medication(
      name: name ?? this.name,
      dose: dose ?? this.dose,
      time: time ?? this.time,
      period: period ?? this.period,
      notes: notes ?? this.notes,
      isEnabled: isEnabled ?? this.isEnabled,
      isHistoric: isHistoric ?? this.isHistoric,
      createdAt: createdAt ?? this.createdAt,
      courseEndDate: courseEndDate ?? this.courseEndDate,
      totalQuantity: totalQuantity ?? this.totalQuantity,
      remainingQuantity: remainingQuantity ?? this.remainingQuantity,
      intakeHistory: intakeHistory != null
          ? List<DateTime>.unmodifiable(intakeHistory)
          : this.intakeHistory,
    );
  }

  Medication recordIntake(DateTime timestamp) {
    final updatedHistory = List<DateTime>.from(intakeHistory)..add(timestamp);
    int? updatedRemaining = remainingQuantity;
    if (updatedRemaining != null) {
      updatedRemaining = updatedRemaining - 1;
      if (updatedRemaining < 0) {
        updatedRemaining = 0;
      }
    }

    final bool supplyFinished =
        updatedRemaining != null && updatedRemaining <= 0;
    final bool courseFinished =
        courseEndDate != null && !timestamp.isBefore(courseEndDate!);
    final bool shouldArchive = supplyFinished || courseFinished;

    return copyWith(
      intakeHistory: updatedHistory,
      remainingQuantity: updatedRemaining,
      isHistoric: shouldArchive ? true : isHistoric,
      isEnabled: shouldArchive ? false : isEnabled,
    );
  }

  DateTime? get lastIntake => intakeHistory.isEmpty
      ? null
      : intakeHistory.reduce((a, b) => a.isAfter(b) ? a : b);

  bool get hasLowStock {
    if (remainingQuantity == null ||
        totalQuantity == null ||
        totalQuantity! <= 0) {
      return false;
    }
    final threshold = (totalQuantity! * 0.2).ceil().clamp(1, totalQuantity!);
    return remainingQuantity! <= threshold;
  }

  /// Returns true if the medication was already taken today for its scheduled time.
  bool isTakenToday() {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));

    return intakeHistory.any(
      (intake) => intake.isAfter(todayStart) && intake.isBefore(todayEnd),
    );
  }

  /// Returns true if current time is within the allowed intake window.
  /// [windowMinutes] - configurable window (default 60 minutes before/after scheduled time)
  bool isWithinIntakeWindow({int windowMinutes = 60}) {
    final now = DateTime.now();
    final scheduledTime = DateTime(
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );
    final windowStart = scheduledTime.subtract(
      Duration(minutes: windowMinutes),
    );
    final windowEnd = scheduledTime.add(Duration(minutes: windowMinutes));

    return now.isAfter(windowStart) && now.isBefore(windowEnd);
  }

  /// Returns how many minutes until the intake window opens.
  /// Returns null if already in window or past the window.
  int? minutesUntilIntakeWindow({int windowMinutes = 60}) {
    final now = DateTime.now();
    final scheduledTime = DateTime(
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );
    final windowStart = scheduledTime.subtract(
      Duration(minutes: windowMinutes),
    );

    if (now.isBefore(windowStart)) {
      return windowStart.difference(now).inMinutes;
    }
    return null;
  }

  /// Returns true if the intake window has already passed for today.
  bool hasIntakeWindowPassed({int windowMinutes = 60}) {
    final now = DateTime.now();
    final scheduledTime = DateTime(
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );
    final windowEnd = scheduledTime.add(Duration(minutes: windowMinutes));

    return now.isAfter(windowEnd);
  }

  bool get isCourseActive {
    final supplyAvailable = remainingQuantity == null || remainingQuantity! > 0;
    final now = DateTime.now();
    final withinCourse =
        courseEndDate == null ||
        now.isBefore(courseEndDate!) ||
        now.isAtSameMomentAs(courseEndDate!);
    return isEnabled && !isHistoric && supplyAvailable && withinCourse;
  }

  static TimeOfDay _parseTime(String raw) {
    final pieces = raw.split(':');
    if (pieces.length != 2) {
      throw FormatException('Invalid time format "$raw"');
    }
    final hour = int.tryParse(pieces.first);
    final minute = int.tryParse(pieces.last);
    if (hour == null || minute == null) {
      throw FormatException('Invalid time format "$raw"');
    }
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      throw FormatException('Invalid time value "$raw"');
    }
    return TimeOfDay(hour: hour, minute: minute);
  }

  static String _formatTime(TimeOfDay time) {
    final twoDigitHour = time.hour.toString().padLeft(2, '0');
    final twoDigitMinute = time.minute.toString().padLeft(2, '0');
    return '$twoDigitHour:$twoDigitMinute';
  }

  static MedicationPeriod _parsePeriod(Object? raw) {
    if (raw is! String) {
      return MedicationPeriod.morning;
    }
    switch (raw.toLowerCase()) {
      case 'afternoon':
        return MedicationPeriod.afternoon;
      case 'evening':
        return MedicationPeriod.evening;
      case 'morning':
      default:
        return MedicationPeriod.morning;
    }
  }

  static String _formatPeriod(MedicationPeriod period) {
    switch (period) {
      case MedicationPeriod.morning:
        return 'morning';
      case MedicationPeriod.afternoon:
        return 'afternoon';
      case MedicationPeriod.evening:
        return 'evening';
    }
  }

  static DateTime? _parseDateTime(Object? raw) {
    if (raw is String && raw.isNotEmpty) {
      return DateTime.tryParse(raw)?.toLocal();
    }
    return null;
  }

  static int? _parseInt(Object? raw) {
    if (raw is int) {
      return raw;
    }
    if (raw is double) {
      return raw.toInt();
    }
    if (raw is String) {
      return int.tryParse(raw);
    }
    return null;
  }

  static List<DateTime> _parseHistory(Object? raw) {
    if (raw is List) {
      return raw
          .map((entry) => _parseDateTime(entry))
          .whereType<DateTime>()
          .toList(growable: false);
    }
    return const <DateTime>[];
  }
}
