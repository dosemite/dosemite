import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/medication_repository.dart';
import '../models/medication.dart';
import '../services/notification_service.dart';

class MedicationProvider extends ChangeNotifier {
  final MedicationRepository _repository = MedicationRepository();

  List<Medication> _medications = [];
  bool _isLoading = true;
  String? _error;
  bool _notificationsEnabled = true;

  // Getters
  List<Medication> get medications => _medications;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get notificationsEnabled => _notificationsEnabled;

  MedicationProvider() {
    _init();
  }

  Future<void> _init() async {
    await _loadPrefs();
    await refreshMedications();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
    notifyListeners();
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    if (_notificationsEnabled == enabled) return;

    _notificationsEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', enabled);
    notifyListeners();

    await _syncNotifications();
  }

  Future<void> refreshMedications() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final meds = await _repository.loadMedications();
      _medications = meds;
      _isLoading = false;
      notifyListeners();
      await _syncNotifications();
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> _syncNotifications() async {
    try {
      await NotificationService.instance.syncMedications(
        _medications,
        notificationsEnabled: _notificationsEnabled,
      );
    } catch (e) {
      debugPrint('Failed to sync notifications: $e');
    }
  }

  Future<void> addMedication(Medication medication) async {
    try {
      await _repository.addMedication(medication);
      await refreshMedications();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateMedication(Medication medication) async {
    try {
      await _repository.updateMedication(medication);
      await refreshMedications();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteMedication(DateTime createdAt) async {
    try {
      await _repository.deleteMedication(createdAt);
      await refreshMedications();
    } catch (e) {
      rethrow;
    }
  }

  Future<Medication?> markMedicationTaken(int index, DateTime timestamp) async {
    try {
      // Reload to ensure we have the latest state before modifying
      // (Though in a local-only app, _medications should be up to date)
      // For safety, we'll use the current list index if valid
      if (index < 0 || index >= _medications.length) {
        throw Exception('Invalid medication index');
      }

      final med = _medications[index];
      final updatedMedication = med.recordIntake(timestamp);

      // Optimistic update
      _medications[index] = updatedMedication;
      notifyListeners();

      // Save to disk
      // We save the WHOLE list because the repository API expects likely a rewrite
      // or we can use the repository to save just the list.
      // Looking at the original code:
      // await _medicationRepository.saveMedications(medications);
      await _repository.saveMedications(_medications);

      // Return the updated med for UI feedback (snacks)
      return updatedMedication;
    } catch (e) {
      // Revert optimistic update if needed?
      // For now just refresh to be safe
      await refreshMedications();
      rethrow;
    }
  }
}
