import 'package:flutter/material.dart';

import '../data/medication_repository.dart';
import '../models/medication.dart';
import '../utils/translations.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final MedicationRepository _repository = MedicationRepository();
  late Future<List<Medication>> _medicationsFuture;

  @override
  void initState() {
    super.initState();
    _medicationsFuture = _repository.loadMedications();
  }

  Future<void> _refresh() async {
    setState(() {
      _medicationsFuture = _repository.loadMedications();
    });
    await _medicationsFuture;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(Translations.history)),
      body: FutureBuilder<List<Medication>>(
        future: _medicationsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      Translations.unableToLoadMedications,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _refresh,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          final medications = (snapshot.data ?? <Medication>[]).toList()
            ..sort(_compareMedicationHistory);

          return RefreshIndicator(
            onRefresh: _refresh,
            child: medications.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      const SizedBox(height: 120),
                      Center(
                        child: Text(
                          Translations.noHistoryYet,
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount: medications.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            Translations.tapMedicationForHistory,
                            style: TextStyle(
                              color:
                                  Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        );
                      }
                      return _MedicationHistoryTile(
                        medication: medications[index - 1],
                      );
                    },
                  ),
          );
        },
      ),
    );
  }
}

class _MedicationHistoryTile extends StatelessWidget {
  const _MedicationHistoryTile({required this.medication});

  final Medication medication;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitleParts = <String>[
      '${medication.dose} • ${medication.time.format(context)}',
      _labelForPeriod(medication.period),
    ];
    if (medication.remainingQuantity != null) {
      subtitleParts.add(Translations.remainingDoses(medication.remainingQuantity!));
    }
    if (medication.courseEndDate != null) {
      final dateLabel =
          MaterialLocalizations.of(context).formatFullDate(medication.courseEndDate!);
      subtitleParts.add(Translations.courseEndsOn(dateLabel));
    }

    final entries = medication.intakeHistory.toList()
      ..sort((a, b) => b.compareTo(a));

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        childrenPadding: const EdgeInsets.only(bottom: 12),
        title: Text(
          medication.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            subtitleParts.join(' • '),
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 13,
            ),
          ),
        ),
        children: entries.isEmpty
            ? [
                ListTile(
                  title: Text(Translations.noDosesLogged),
                ),
              ]
            : entries
                .map(
                  (entry) => ListTile(
                    leading: const Icon(Icons.check_circle_outline),
                    title: Text(_formatHistoryTimestamp(context, entry)),
                  ),
                )
                .toList(growable: false),
      ),
    );
  }
}

int _compareMedicationHistory(Medication a, Medication b) {
  final aLast = a.lastIntake ?? a.createdAt;
  final bLast = b.lastIntake ?? b.createdAt;
  final cmp = bLast.compareTo(aLast);
  if (cmp != 0) {
    return cmp;
  }
  return a.name.toLowerCase().compareTo(b.name.toLowerCase());
}

String _formatHistoryTimestamp(BuildContext context, DateTime time) {
  final localizations = MaterialLocalizations.of(context);
  final date = localizations.formatFullDate(time);
  final formattedTime = localizations.formatTimeOfDay(TimeOfDay.fromDateTime(time));
  return '$date • $formattedTime';
}

String _labelForPeriod(MedicationPeriod period) {
  switch (period) {
    case MedicationPeriod.morning:
      return Translations.morning;
    case MedicationPeriod.afternoon:
      return Translations.afternoon;
    case MedicationPeriod.evening:
      return Translations.evening;
  }
}
