import 'package:flutter/material.dart';
import '../models/medication.dart';
import '../utils/translations.dart';

class AddMedicationSheet extends StatefulWidget {
  const AddMedicationSheet({super.key});

  @override
  State<AddMedicationSheet> createState() => _AddMedicationSheetState();
}

class _AddMedicationSheetState extends State<AddMedicationSheet> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _doseController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _assigneeNameController = TextEditingController();

  List<TimeOfDay> _selectedTimes = [];
  DateTime? _courseEndDate;
  String? _errorText;
  bool _isForSelf = true; // true = Self, false = Other person
  int _intervalDays = 1; // Default: daily

  @override
  void dispose() {
    _nameController.dispose();
    _doseController.dispose();
    _notesController.dispose();
    _quantityController.dispose();
    _assigneeNameController.dispose();
    super.dispose();
  }

  Future<void> _addTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        // Add the time and sort by hour/minute
        _selectedTimes = [..._selectedTimes, picked]
          ..sort((a, b) {
            final aMinutes = a.hour * 60 + a.minute;
            final bMinutes = b.hour * 60 + b.minute;
            return aMinutes.compareTo(bMinutes);
          });
        _errorText = null;
      });
    }
  }

  void _removeTime(int index) {
    setState(() {
      _selectedTimes = List<TimeOfDay>.from(_selectedTimes)..removeAt(index);
    });
  }

  Future<void> _pickCourseEndDate() async {
    final now = DateTime.now();
    final initialDate = _courseEndDate ?? now;
    final picked = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 5)),
      initialDate: initialDate,
    );
    if (picked != null) {
      setState(() {
        _courseEndDate = DateTime(picked.year, picked.month, picked.day);
        _errorText = null;
      });
    }
  }

  void _submit() {
    final name = _nameController.text.trim();
    final dose = _doseController.text.trim();
    final notes = _notesController.text.trim();
    final quantityText = _quantityController.text.trim();
    final parsedQuantity = int.tryParse(quantityText);

    if (name.isEmpty || dose.isEmpty || _selectedTimes.isEmpty) {
      setState(() {
        _errorText = Translations.medicationFormIncomplete;
      });
      return;
    }

    if (_courseEndDate == null) {
      setState(() {
        _errorText = Translations.courseEndRequired;
      });
      return;
    }

    if (parsedQuantity == null || parsedQuantity <= 0) {
      setState(() {
        _errorText = Translations.quantityRequired;
      });
      return;
    }

    FocusScope.of(context).unfocus();
    final period = _periodForTime(_selectedTimes.first);
    final courseEnd = DateTime(
      _courseEndDate!.year,
      _courseEndDate!.month,
      _courseEndDate!.day,
      23,
      59,
      59,
    );

    Navigator.of(context).pop(
      Medication(
        name: name,
        dose: dose,
        times: _selectedTimes,
        period: period,
        notes: notes.isEmpty ? null : notes,
        courseEndDate: courseEnd,
        totalQuantity: parsedQuantity,
        remainingQuantity: parsedQuantity,
        intakeHistory: const <DateTime>[],
        assignee: _isForSelf ? null : _assigneeNameController.text.trim(),
        intervalDays: _intervalDays,
      ),
    );
  }

  MedicationPeriod _periodForTime(TimeOfDay time) {
    if (time.hour < 12) {
      return MedicationPeriod.morning;
    }
    if (time.hour < 18) {
      return MedicationPeriod.afternoon;
    }
    return MedicationPeriod.evening;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.of(context);
    final localizations = MaterialLocalizations.of(context);

    return Padding(
      padding: EdgeInsets.only(bottom: mediaQuery.viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(Translations.addDrug, style: theme.textTheme.titleMedium),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: Translations.medicationName,
              ),
              onChanged: (_) {
                if (_errorText != null) {
                  setState(() {
                    _errorText = null;
                  });
                }
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _doseController,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: Translations.medicationDose,
              ),
              onChanged: (_) {
                if (_errorText != null) {
                  setState(() {
                    _errorText = null;
                  });
                }
              },
            ),
            const SizedBox(height: 12),
            const SizedBox(height: 12),
            Text(Translations.usageTime, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ..._selectedTimes.asMap().entries.map((entry) {
                  final index = entry.key;
                  final time = entry.value;
                  return InputChip(
                    label: Text(
                      localizations.formatTimeOfDay(
                        time,
                        alwaysUse24HourFormat: mediaQuery.alwaysUse24HourFormat,
                      ),
                    ),
                    deleteIcon: const Icon(Icons.close, size: 18),
                    onDeleted: () => _removeTime(index),
                  );
                }),
                ActionChip(
                  avatar: const Icon(Icons.add, size: 18),
                  label: Text(Translations.addTime),
                  onPressed: _addTime,
                ),
              ],
            ),
            if (_selectedTimes.isEmpty) ...[
              const SizedBox(height: 4),
              Text(
                Translations.addAtLeastOneTime,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Text(Translations.courseEndDate, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 6),
            OutlinedButton.icon(
              onPressed: _pickCourseEndDate,
              icon: const Icon(Icons.event),
              label: Text(
                _courseEndDate != null
                    ? MaterialLocalizations.of(
                        context,
                      ).formatFullDate(_courseEndDate!)
                    : Translations.selectCourseEndDate,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _quantityController,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(labelText: Translations.stockOnHand),
              onChanged: (_) {
                if (_errorText != null) {
                  setState(() {
                    _errorText = null;
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            Text(Translations.forWhom, style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: RadioListTile<bool>(
                    title: Text(Translations.self),
                    value: true,
                    groupValue: _isForSelf,
                    onChanged: (value) {
                      setState(() {
                        _isForSelf = value!;
                      });
                    },
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                Expanded(
                  child: RadioListTile<bool>(
                    title: Text(Translations.otherPerson),
                    value: false,
                    groupValue: _isForSelf,
                    onChanged: (value) {
                      setState(() {
                        _isForSelf = value!;
                      });
                    },
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
            if (!_isForSelf)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: TextField(
                  controller: _assigneeNameController,
                  decoration: InputDecoration(
                    labelText: Translations.personsName,
                    hintText: Translations.enterName,
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    Translations.takeEvery,
                    style: theme.textTheme.labelLarge,
                  ),
                ),
                DropdownButton<int>(
                  value: _intervalDays,
                  items: [
                    DropdownMenuItem(value: 1, child: Text(Translations.daily)),
                    DropdownMenuItem(
                      value: 2,
                      child: Text(Translations.every2Days),
                    ),
                    DropdownMenuItem(
                      value: 3,
                      child: Text(Translations.every3Days),
                    ),
                    DropdownMenuItem(
                      value: 7,
                      child: Text(Translations.weekly),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _intervalDays = value!;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              decoration: InputDecoration(
                labelText: Translations.medicationNotesOptional,
              ),
              maxLines: 2,
            ),
            if (_errorText != null) ...[
              const SizedBox(height: 12),
              Text(
                _errorText!,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submit,
                child: Text(Translations.save),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Result type for edit medication sheet
class EditMedicationResult {
  final Medication? updatedMedication;
  final bool shouldDelete;

  const EditMedicationResult({
    this.updatedMedication,
    this.shouldDelete = false,
  });
}

class EditMedicationSheet extends StatefulWidget {
  const EditMedicationSheet({super.key, required this.medication});

  final Medication medication;

  @override
  State<EditMedicationSheet> createState() => _EditMedicationSheetState();
}

class _EditMedicationSheetState extends State<EditMedicationSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _doseController;
  late final TextEditingController _notesController;
  late final TextEditingController _quantityController;
  late final TextEditingController _assigneeNameController;

  List<TimeOfDay> _selectedTimes = [];
  DateTime? _courseEndDate;
  String? _errorText;
  bool _isForSelf = true;
  int _intervalDays = 1;

  @override
  void initState() {
    super.initState();
    final med = widget.medication;
    _nameController = TextEditingController(text: med.name);
    _doseController = TextEditingController(text: med.dose);
    _notesController = TextEditingController(text: med.notes ?? '');
    _quantityController = TextEditingController(
      text: med.remainingQuantity?.toString() ?? '',
    );
    _assigneeNameController = TextEditingController(text: med.assignee ?? '');
    _selectedTimes = List<TimeOfDay>.from(med.times);
    _courseEndDate = med.courseEndDate;
    _isForSelf = med.assignee == null;
    _intervalDays = med.intervalDays;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _doseController.dispose();
    _notesController.dispose();
    _quantityController.dispose();
    _assigneeNameController.dispose();
    super.dispose();
  }

  Future<void> _addTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        // Add the time and sort by hour/minute
        _selectedTimes = [..._selectedTimes, picked]
          ..sort((a, b) {
            final aMinutes = a.hour * 60 + a.minute;
            final bMinutes = b.hour * 60 + b.minute;
            return aMinutes.compareTo(bMinutes);
          });
        _errorText = null;
      });
    }
  }

  void _removeTime(int index) {
    setState(() {
      _selectedTimes = List<TimeOfDay>.from(_selectedTimes)..removeAt(index);
    });
  }

  Future<void> _pickCourseEndDate() async {
    final now = DateTime.now();
    final initialDate = _courseEndDate ?? now;
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now.add(const Duration(days: 365 * 5)),
      initialDate: initialDate.isBefore(now) ? now : initialDate,
    );
    if (picked != null) {
      setState(() {
        _courseEndDate = DateTime(picked.year, picked.month, picked.day);
        _errorText = null;
      });
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(Translations.deleteMedication),
        content: Text(Translations.deleteMedicationConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(Translations.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(Translations.delete),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      Navigator.of(context).pop(const EditMedicationResult(shouldDelete: true));
    }
  }

  void _submit() {
    final name = _nameController.text.trim();
    final dose = _doseController.text.trim();
    final notes = _notesController.text.trim();
    final quantityText = _quantityController.text.trim();
    final parsedQuantity = int.tryParse(quantityText);

    if (name.isEmpty || dose.isEmpty || _selectedTimes.isEmpty) {
      setState(() {
        _errorText = Translations.medicationFormIncomplete;
      });
      return;
    }

    if (_courseEndDate == null) {
      setState(() {
        _errorText = Translations.courseEndRequired;
      });
      return;
    }

    if (parsedQuantity == null || parsedQuantity < 0) {
      setState(() {
        _errorText = Translations.quantityRequired;
      });
      return;
    }

    FocusScope.of(context).unfocus();
    final period = _periodForTime(_selectedTimes.first);
    final courseEnd = DateTime(
      _courseEndDate!.year,
      _courseEndDate!.month,
      _courseEndDate!.day,
      23,
      59,
      59,
    );

    final assigneeValue = _isForSelf
        ? null
        : (_assigneeNameController.text.trim().isEmpty
              ? null
              : _assigneeNameController.text.trim());

    // Create new medication to ensure assignee can be set to null
    final updated = Medication(
      name: name,
      dose: dose,
      times: _selectedTimes,
      period: period,
      notes: notes.isEmpty ? null : notes,
      courseEndDate: courseEnd,
      totalQuantity: widget.medication.totalQuantity,
      remainingQuantity: parsedQuantity,
      intakeHistory: widget.medication.intakeHistory,
      createdAt: widget.medication.createdAt,
      isEnabled: widget.medication.isEnabled,
      isHistoric: widget.medication.isHistoric,
      assignee: assigneeValue,
      intervalDays: _intervalDays,
    );

    Navigator.of(context).pop(EditMedicationResult(updatedMedication: updated));
  }

  MedicationPeriod _periodForTime(TimeOfDay time) {
    if (time.hour < 12) {
      return MedicationPeriod.morning;
    }
    if (time.hour < 18) {
      return MedicationPeriod.afternoon;
    }
    return MedicationPeriod.evening;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.of(context);
    final localizations = MaterialLocalizations.of(context);

    return Padding(
      padding: EdgeInsets.only(bottom: mediaQuery.viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  Translations.editMedication,
                  style: theme.textTheme.titleMedium,
                ),
                IconButton(
                  onPressed: _confirmDelete,
                  icon: Icon(
                    Icons.delete_outline,
                    color: theme.colorScheme.error,
                  ),
                  tooltip: Translations.deleteMedication,
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: Translations.medicationName,
              ),
              onChanged: (_) {
                if (_errorText != null) {
                  setState(() {
                    _errorText = null;
                  });
                }
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _doseController,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: Translations.medicationDose,
              ),
              onChanged: (_) {
                if (_errorText != null) {
                  setState(() {
                    _errorText = null;
                  });
                }
              },
            ),
            const SizedBox(height: 12),
            const SizedBox(height: 12),
            Text(Translations.usageTime, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ..._selectedTimes.asMap().entries.map((entry) {
                  final index = entry.key;
                  final time = entry.value;
                  return InputChip(
                    label: Text(
                      localizations.formatTimeOfDay(
                        time,
                        alwaysUse24HourFormat: mediaQuery.alwaysUse24HourFormat,
                      ),
                    ),
                    deleteIcon: const Icon(Icons.close, size: 18),
                    onDeleted: () => _removeTime(index),
                  );
                }),
                ActionChip(
                  avatar: const Icon(Icons.add, size: 18),
                  label: Text(Translations.addTime),
                  onPressed: _addTime,
                ),
              ],
            ),
            if (_selectedTimes.isEmpty) ...[
              const SizedBox(height: 4),
              Text(
                Translations.addAtLeastOneTime,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Text(Translations.courseEndDate, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 6),
            OutlinedButton.icon(
              onPressed: _pickCourseEndDate,
              icon: const Icon(Icons.event),
              label: Text(
                _courseEndDate != null
                    ? MaterialLocalizations.of(
                        context,
                      ).formatFullDate(_courseEndDate!)
                    : Translations.selectCourseEndDate,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _quantityController,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(labelText: Translations.stockOnHand),
              onChanged: (_) {
                if (_errorText != null) {
                  setState(() {
                    _errorText = null;
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            Text(Translations.forWhom, style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: RadioListTile<bool>(
                    title: Text(Translations.self),
                    value: true,
                    groupValue: _isForSelf,
                    onChanged: (value) => setState(() => _isForSelf = value!),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                Expanded(
                  child: RadioListTile<bool>(
                    title: Text(Translations.otherPerson),
                    value: false,
                    groupValue: _isForSelf,
                    onChanged: (value) => setState(() => _isForSelf = value!),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
            if (!_isForSelf)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: TextField(
                  controller: _assigneeNameController,
                  decoration: InputDecoration(
                    labelText: Translations.personsName,
                    hintText: Translations.enterName,
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    Translations.takeEvery,
                    style: theme.textTheme.labelLarge,
                  ),
                ),
                DropdownButton<int>(
                  value: _intervalDays,
                  items: [
                    DropdownMenuItem(value: 1, child: Text(Translations.daily)),
                    DropdownMenuItem(
                      value: 2,
                      child: Text(Translations.every2Days),
                    ),
                    DropdownMenuItem(
                      value: 3,
                      child: Text(Translations.every3Days),
                    ),
                    DropdownMenuItem(
                      value: 7,
                      child: Text(Translations.weekly),
                    ),
                  ],
                  onChanged: (value) => setState(() => _intervalDays = value!),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              decoration: InputDecoration(
                labelText: Translations.medicationNotesOptional,
              ),
              maxLines: 2,
            ),
            if (_errorText != null) ...[
              const SizedBox(height: 12),
              Text(
                _errorText!,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submit,
                child: Text(Translations.update),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
