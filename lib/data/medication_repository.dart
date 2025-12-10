import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/medication.dart';

class MedicationRepository {
  MedicationRepository();

  static const String _fileName = 'medications.json';

  Future<List<Medication>> loadMedications() async {
    final file = await _localFile();
    if (!await file.exists()) {
      return <Medication>[];
    }

    final raw = await file.readAsString();
    if (raw.trim().isEmpty) {
      return <Medication>[];
    }

    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      throw const FormatException('Medication data is not a list');
    }

    return decoded
        .map((entry) => Medication.fromJson(
              Map<String, dynamic>.from(entry as Map),
            ))
        .toList();
  }

  Future<void> saveMedications(List<Medication> medications) async {
    final file = await _localFile();
    await file.create(recursive: true);
    final payload = medications.map((m) => m.toJson()).toList();
    await file.writeAsString(jsonEncode(payload));
  }

  Future<void> addMedication(Medication medication) async {
    final existing = await loadMedications();
    final updated = List<Medication>.from(existing)
      ..add(
        medication.copyWith(
          isEnabled: true,
          isHistoric: false,
        ),
      );
    await saveMedications(updated);
  }

  Future<File> _localFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$_fileName');
  }
}
