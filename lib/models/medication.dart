import 'package:flutter/material.dart';

enum MedicationPeriod { morning, afternoon, evening }

class Medication {
  Medication({
    required this.name,
    required this.dose,
    required this.times,
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
  final List<TimeOfDay> times;
  final MedicationPeriod period;
  final String? notes;
  final bool isEnabled;
  final bool isHistoric;
  final DateTime createdAt;
  final DateTime? courseEndDate;
  final int? totalQuantity;
  final int? remainingQuantity;
  final List<DateTime> intakeHistory;

  /// Backward compatibility: returns the first time in the list
  TimeOfDay get time =>
      times.isNotEmpty ? times.first : const TimeOfDay(hour: 8, minute: 0);

  factory Medication.fromJson(Map<String, dynamic> json) {
    final rawName = json['name'];
    final rawDose = json['dose'];
    final rawPeriod = json['period'];

    if (rawName is! String || rawDose is! String) {
      throw const FormatException(
        'Medication json missing required string fields',
      );
    }

    // Support both old 'time' (single string) and new 'times' (list) formats
    List<TimeOfDay> times;
    if (json['times'] is List) {
      times = (json['times'] as List)
          .map((t) => _parseTime(t as String))
          .toList();
    } else if (json['time'] is String) {
      // Backward compatibility: single time string
      times = [_parseTime(json['time'] as String)];
    } else {
      throw const FormatException('Medication json missing time/times field');
    }

    final period = _parsePeriod(rawPeriod);

    return Medication(
      name: rawName,
      dose: rawDose,
      times: times,
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
    'times': times.map((t) => _formatTime(t)).toList(),
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
    List<TimeOfDay>? times,
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
      times: times ?? this.times,
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

  bool get isCourseActive {
    final supplyAvailable = remainingQuantity == null || remainingQuantity! > 0;
    final now = DateTime.now();
    final withinCourse =
        courseEndDate == null ||
        now.isBefore(courseEndDate!) ||
        now.isAtSameMomentAs(courseEndDate!);
    return isEnabled && !isHistoric && supplyAvailable && withinCourse;
  }

  /// Returns the number of times per day this medication should be taken
  int get timesPerDay => times.length;

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
