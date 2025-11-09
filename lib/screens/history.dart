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

          final history = (snapshot.data ?? <Medication>[])
              .where((med) => med.isHistoric)
              .toList()
            ..sort((a, b) => _compareTimeDesc(a.time, b.time));

          return RefreshIndicator(
            onRefresh: _refresh,
            child: history.isEmpty
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
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount: history.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      return _HistoryTile(medication: history[index]);
                    },
                  ),
          );
        },
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.medication});

  final Medication medication;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitle = '${medication.dose} • ${medication.time.format(context)} • ${_labelForPeriod(medication.period)}';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: theme.colorScheme.primaryContainer,
            child: Text(
              medication.name.isNotEmpty
                  ? medication.name[0].toUpperCase()
                  : '?',
              style: TextStyle(
                color: theme.colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  medication.name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
                if (medication.notes != null && medication.notes!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      medication.notes!,
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Icon(Icons.check_circle, color: Colors.green),
        ],
      ),
    );
  }
}

int _compareTimeDesc(TimeOfDay a, TimeOfDay b) {
  final aMinutes = a.hour * 60 + a.minute;
  final bMinutes = b.hour * 60 + b.minute;
  return bMinutes.compareTo(aMinutes);
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
