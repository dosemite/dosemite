import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/medication.dart';
import '../providers/medication_provider.dart';
import '../utils/translations.dart';
import '../widgets/dashboard_widgets.dart';
import '../widgets/medication_sheets.dart';
import 'drugstore_map.dart';
import 'history.dart';
import 'settings.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // 0 = Medicine Tracker, 1 = Drugstore Map
  int _selectedIndex = 0;
  String _userName = '';
  late PageController _pageController;
  final Set<int> _markingMedicationIndices = <int>{};

  // Search functionality
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _loadUserName();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUserName() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('user_name') ?? '';
    if (mounted) {
      setState(() {
        _userName = name;
      });
    }
  }

  Future<void> _onAddMedicationPressed() async {
    final medication = await showModalBottomSheet<Medication>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const AddMedicationSheet(),
    );

    if (medication == null || !mounted) return;

    try {
      await context.read<MedicationProvider>().addMedication(medication);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(Translations.medicationAdded)));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(Translations.unableToSaveMedication)),
        );
      }
    }
  }

  Future<void> _markMedicationTaken(int index, Medication med) async {
    if (_markingMedicationIndices.contains(index)) return;

    setState(() {
      _markingMedicationIndices.add(index);
    });

    try {
      // Pass the *original* index from the full list?
      // Since the provider's list might match the filtered list index only if no search is active.
      // Wait, the index passed here should be the index in the PROVIDER's list.
      // When we build the UI, we should probably pass the Medication object and find it, or pass the index.
      // The current implementation in main.dart utilized `entries` which contained the index.

      final provider = context.read<MedicationProvider>();
      // We need to find the actual index in the provider's list if we are filtering.
      final validIndex = provider.medications.indexOf(med);

      if (validIndex == -1) return;

      final updatedMedication = await provider.markMedicationTaken(
        validIndex,
        DateTime.now(),
      );

      if (!mounted || updatedMedication == null) return;

      final remaining = updatedMedication.remainingQuantity;
      final parts = <String>[Translations.medicationMarkedAsTaken];
      if (remaining != null) {
        parts.add(Translations.remainingDoses(remaining));
      }
      if (updatedMedication.isHistoric) {
        parts.add(Translations.courseCompleted);
      } else if (updatedMedication.hasLowStock && remaining != null) {
        parts.add(
          Translations.lowStockMessage(updatedMedication.name, remaining),
        );
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(parts.join(' • '))));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(Translations.unableToSaveMedication)),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _markingMedicationIndices.remove(index);
        });
      }
    }
  }

  Future<void> _onEditMedication(Medication medication) async {
    final result = await showModalBottomSheet<EditMedicationResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => EditMedicationSheet(medication: medication),
    );

    if (result == null || !mounted) return;

    final provider = context.read<MedicationProvider>();

    try {
      if (result.shouldDelete) {
        await provider.deleteMedication(medication.createdAt);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(Translations.medicationDeleted)),
          );
        }
      } else if (result.updatedMedication != null) {
        await provider.updateMedication(result.updatedMedication!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(Translations.medicationUpdated)),
          );
        }
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(Translations.unableToSaveMedication)),
        );
      }
    }
  }

  String _greetingText() {
    final hour = DateTime.now().hour;
    final prefix = hour < 12
        ? Translations.goodMorning
        : (hour < 18 ? Translations.goodAfternoon : Translations.goodEvening);
    if (_userName.isNotEmpty) return '$prefix, $_userName';
    return prefix;
  }

  String _nextMedicationMessage(List<Medication> meds) {
    if (meds.isEmpty) {
      return Translations.noUpcomingMedications;
    }

    final now = DateTime.now();
    Duration? soonestDiff;

    for (final med in meds) {
      if (!med.isCourseActive) continue;

      for (final time in med.times) {
        final nextOccurrence = _nextOccurrenceFor(
          time,
          now,
          intervalDays: med.intervalDays,
        );
        var diff = nextOccurrence.difference(now);
        if (diff.isNegative) diff = Duration.zero;

        if (soonestDiff == null || diff < soonestDiff) {
          soonestDiff = diff;
        }
      }
    }

    if (soonestDiff == null) {
      return Translations.noUpcomingMedications;
    }

    return Translations.nextMedicationIn(_formatDuration(soonestDiff));
  }

  DateTime _nextOccurrenceFor(
    TimeOfDay time,
    DateTime reference, {
    int intervalDays = 1,
  }) {
    final candidate = DateTime(
      reference.year,
      reference.month,
      reference.day,
      time.hour,
      time.minute,
    );

    if (candidate.isAfter(reference) || candidate.isAtSameMomentAs(reference)) {
      return candidate;
    }

    return candidate.add(Duration(days: intervalDays));
  }

  String _formatDuration(Duration duration) {
    if (duration.inMinutes < 1) {
      return Translations.lessThanOneMinute;
    }

    final days = duration.inDays;
    final hours = duration.inHours % 24;
    final minutes = duration.inMinutes % 60;

    final parts = <String>[];

    if (days > 0) parts.add(Translations.durationDays(days));
    if (hours > 0) parts.add(Translations.durationHours(hours));
    if (minutes > 0 && parts.length < 2) {
      parts.add(Translations.durationMinutes(minutes));
    }

    if (parts.isEmpty) return Translations.lessThanOneMinute;
    return parts.join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final medProvider = context.watch<MedicationProvider>();
    final allMedications = medProvider.medications;
    final notificationsEnabled = medProvider.notificationsEnabled;

    final lowSupplyMeds = _selectedIndex == 0
        ? _lowSupplyMedicationsForUi(allMedications)
        : const <Medication>[];

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Column(
          children: [
            // Top greeting row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: const Color(0xFF90CAF9),
                    child: Text(
                      _userName.isNotEmpty ? _userName[0].toUpperCase() : 'A',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _greetingText(),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton.filledTonal(
                    style: IconButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      backgroundColor:
                          theme.colorScheme.surfaceContainerHighest,
                    ),
                    tooltip: 'Settings',
                    onPressed: () {
                      Navigator.of(context)
                          .push(
                            MaterialPageRoute(
                              builder: (_) => const SettingsScreen(),
                            ),
                          )
                          .then(
                            (_) => _loadUserName(),
                          ); // Refresh name after settings
                    },
                    icon: const Icon(Icons.settings_outlined, size: 22),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    style: IconButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      backgroundColor: notificationsEnabled
                          ? theme.colorScheme.primaryContainer
                          : theme.colorScheme.surfaceVariant,
                    ),
                    tooltip: notificationsEnabled
                        ? 'Disable notifications'
                        : 'Enable notifications',
                    onPressed: () {
                      medProvider.setNotificationsEnabled(
                        !notificationsEnabled,
                      );
                    },
                    icon: Icon(
                      notificationsEnabled
                          ? Icons.notifications_active_outlined
                          : Icons.notifications_off_outlined,
                      color: notificationsEnabled
                          ? theme.colorScheme.onPrimaryContainer
                          : theme.colorScheme.onSurfaceVariant,
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),

            if (_selectedIndex == 0)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 46,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.onSurface.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TextField(
                          controller: _searchController,
                          onChanged: (value) {
                            setState(() {
                              _searchQuery = value.toLowerCase();
                            });
                          },
                          decoration: InputDecoration(
                            hintText: Translations.searchMedications,
                            prefixIcon: const Icon(Icons.search),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 12,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      height: 46,
                      width: 46,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onSurface.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.history),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const HistoryScreen(),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),

            if (_selectedIndex == 0 && lowSupplyMeds.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: LowSupplyBanner(medications: lowSupplyMeds),
              ),

            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const BouncingScrollPhysics(),
                onPageChanged: (index) {
                  setState(() {
                    _selectedIndex = index;
                  });
                },
                children: [
                  // Dashboard Content
                  SingleChildScrollView(
                    key: const PageStorageKey('dashboard'),
                    padding: EdgeInsets.fromLTRB(
                      16,
                      16,
                      16,
                      16 + 68 + 24 + MediaQuery.of(context).viewInsets.bottom,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _nextMedicationMessage(allMedications),
                          style: theme.textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          Translations.todaysSchedule,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 16),
                        _buildMedicationList(context, medProvider),
                        const SizedBox(height: 120),
                      ],
                    ),
                  ),
                  // Map Screen
                  const DrugstoreMapScreen(),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainer,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomAppBar(
          height: 76,
          padding: EdgeInsets.zero,
          surfaceTintColor: Colors.transparent,
          clipBehavior: Clip.antiAlias,
          child: Row(
            children: [
              Expanded(
                child: BottomNavTile(
                  icon: Icons.dashboard_customize_outlined,
                  label: Translations.dashboard,
                  selected: _selectedIndex == 0,
                  onTap: () {
                    if (_selectedIndex != 0) {
                      _pageController.animateToPage(
                        0,
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOutQuart,
                      );
                    }
                  },
                ),
              ),
              SizedBox(
                width: 72,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 28),
                    Text(
                      Translations.addDrug,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: BottomNavTile(
                  icon: Icons.map_outlined,
                  label: Translations.map,
                  selected: _selectedIndex == 1,
                  onTap: () {
                    if (_selectedIndex != 1) {
                      _pageController.animateToPage(
                        1,
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOutQuart,
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: SizedBox(
          width: 68,
          height: 68,
          child: FloatingActionButton(
            onPressed: () => _onAddMedicationPressed(),
            elevation: 6,
            backgroundColor: theme.colorScheme.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(Icons.add, size: 32),
          ),
        ),
      ),
    );
  }

  Widget _buildMedicationList(
    BuildContext context,
    MedicationProvider provider,
  ) {
    if (provider.isLoading) {
      return const SizedBox(
        height: 80,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (provider.error != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            Translations.unableToLoadMedications,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: provider.refreshMedications,
            child: const Text('Retry'),
          ),
        ],
      );
    }

    final activeEntries = <MapEntry<int, Medication>>[];
    final allMedications = provider.medications;

    // Create entries with ORIGINAL indices to ensure operations work on correct items
    for (var i = 0; i < allMedications.length; i++) {
      final med = allMedications[i];
      if (med.isCourseActive) {
        if (_searchQuery.isEmpty ||
            med.name.toLowerCase().contains(_searchQuery) ||
            med.dose.toLowerCase().contains(_searchQuery)) {
          activeEntries.add(MapEntry(i, med));
        }
      }
    }

    if (activeEntries.isEmpty) {
      return Text(
        Translations.noMedicationsAdded,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
      );
    }

    return _buildScheduleSections(context, activeEntries);
  }

  List<Medication> _lowSupplyMedicationsForUi(List<Medication> meds) {
    if (meds.isEmpty) return const <Medication>[];
    return meds
        .where((med) => med.hasLowStock && med.isCourseActive)
        .toList(growable: false);
  }

  Widget _buildScheduleSections(
    BuildContext context,
    List<MapEntry<int, Medication>> entries,
  ) {
    final sorted = entries.toList()
      ..sort((a, b) => _compareTimeOfDay(a.value.time, b.value.time));

    final Map<MedicationPeriod, List<MapEntry<int, Medication>>> grouped = {
      MedicationPeriod.morning: <MapEntry<int, Medication>>[],
      MedicationPeriod.afternoon: <MapEntry<int, Medication>>[],
      MedicationPeriod.evening: <MapEntry<int, Medication>>[],
    };

    for (final entry in sorted) {
      grouped[entry.value.period]!.add(entry);
    }

    final sections = grouped.entries
        .where((entry) => entry.value.isNotEmpty)
        .toList(growable: false);

    if (sections.isEmpty) {
      return Text(
        Translations.noMedicationsAdded,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
      );
    }

    final List<Widget> children = <Widget>[];
    for (var i = 0; i < sections.length; i++) {
      final section = sections[i];
      children
        ..add(
          Text(
            _labelForPeriod(section.key),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        )
        ..add(const SizedBox(height: 8));

      final meds = section.value;
      for (var j = 0; j < meds.length; j++) {
        final entry = meds[j];
        final medication = entry.value;

        // Create a separate card for each time
        for (
          var timeIndex = 0;
          timeIndex < medication.times.length;
          timeIndex++
        ) {
          final specificTime = medication.times[timeIndex];
          children.add(
            MedicationCard(
              medication: medication,
              specificTime: specificTime,
              onMarkTaken: () => _markMedicationTaken(entry.key, medication),
              onEdit: () => _onEditMedication(medication),
              isMarking: _markingMedicationIndices.contains(entry.key),
            ),
          );
          if (timeIndex < medication.times.length - 1) {
            children.add(const SizedBox(height: 12));
          }
        }
        if (j < meds.length - 1) {
          children.add(const SizedBox(height: 12));
        }
      }

      if (i < sections.length - 1) {
        children.add(const SizedBox(height: 24));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  int _compareTimeOfDay(TimeOfDay a, TimeOfDay b) {
    final aMinutes = a.hour * 60 + a.minute;
    final bMinutes = b.hour * 60 + b.minute;
    return aMinutes.compareTo(bMinutes);
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
}
