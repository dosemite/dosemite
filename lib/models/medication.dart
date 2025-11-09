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
  });

  final String name;
  final String dose;
  final TimeOfDay time;
  final MedicationPeriod period;
  final String? notes;
  final bool isEnabled;
  final bool isHistoric;

  factory Medication.fromJson(Map<String, dynamic> json) {
    final rawName = json['name'];
    final rawDose = json['dose'];
    final rawTime = json['time'];
    final rawPeriod = json['period'];

    if (rawName is! String || rawDose is! String || rawTime is! String) {
      throw const FormatException('Medication json missing required string fields');
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
      isHistoric: json['isHistoric'] is bool ? json['isHistoric'] as bool : false,
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
      };

  Medication copyWith({
    String? name,
    String? dose,
    TimeOfDay? time,
    MedicationPeriod? period,
    String? notes,
    bool? isEnabled,
    bool? isHistoric,
  }) {
    return Medication(
      name: name ?? this.name,
      dose: dose ?? this.dose,
      time: time ?? this.time,
      period: period ?? this.period,
      notes: notes ?? this.notes,
      isEnabled: isEnabled ?? this.isEnabled,
      isHistoric: isHistoric ?? this.isHistoric,
    );
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
}
