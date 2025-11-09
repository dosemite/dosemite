import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'data/medication_repository.dart';
import 'screens/intro.dart';
import 'screens/drugstore_map.dart';
import 'screens/settings.dart';
import 'screens/history.dart';
import 'theme/theme_controller.dart';
import 'theme/language_controller.dart';
import 'utils/translations.dart';
import 'models/medication.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Tema ve dil ayarlarını yükle
  await Future.wait([
    ThemeController.instance.loadFromPrefs(),
    LanguageController.instance.loadFromPrefs(),
    NotificationService.instance.initialize(),
  ]);
  
  // Sistem temasını kontrol et ve ayarla
  final brightness = WidgetsBinding.instance.window.platformBrightness;
  if (ThemeController.instance.value == AppTheme.light && brightness == Brightness.dark) {
    ThemeController.instance.setTheme(AppTheme.darkGray);
  }
  
  final seen = await ThemeController.hasSeenIntro();
  runApp(PharmacyApp(showIntro: !seen));
}

class PharmacyApp extends StatefulWidget {
  const PharmacyApp({super.key, required this.showIntro});

  final bool showIntro;

  @override
  State<PharmacyApp> createState() => _PharmacyAppState();
}

class _PharmacyAppState extends State<PharmacyApp> {
  // Helper method to create a theme with dynamic color support
  ThemeData _themeFor(AppTheme t, {ColorScheme? dynamicColorScheme}) {
    final brightness = (t == AppTheme.light)
        ? Brightness.light
        : Brightness.dark;
    final materialYou = ThemeController.instance.materialYou;

    // Use dynamic color if available and Material You is enabled
    if (materialYou && dynamicColorScheme != null) {
      final base = ThemeData(
        colorScheme: dynamicColorScheme,
        useMaterial3: true,
      );

      if (t == AppTheme.amoled) {
        return base.copyWith(
          scaffoldBackgroundColor: Colors.black,
          canvasColor: Colors.black,
          cardColor: Colors.grey[900],
        );
      }

      if (t == AppTheme.darkGray) {
        return base.copyWith(scaffoldBackgroundColor: Colors.grey[900]);
      }

      return base;
    }

    // Fallback to static colors when dynamic colors are not available or Material You is disabled
    if (materialYou) {
      final base = ThemeData.from(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: brightness,
        ),
        useMaterial3: true,
      );

      if (t == AppTheme.amoled) {
        return base.copyWith(
          scaffoldBackgroundColor: Colors.black,
          canvasColor: Colors.black,
          cardColor: Colors.grey[900],
        );
      }

      if (t == AppTheme.darkGray) {
        return base.copyWith(scaffoldBackgroundColor: Colors.grey[900]);
      }

      return base;
    }

    // Non-Material-You themes
    switch (t) {
      case AppTheme.light:
        return ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
          brightness: Brightness.light,
        );
      case AppTheme.darkGray:
        return ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blueGrey,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
          scaffoldBackgroundColor: Colors.grey[900],
        );
      case AppTheme.amoled:
        return ThemeData(
          colorScheme: ColorScheme.dark(
            surface: Colors.black,
            primary: Colors.tealAccent,
          ),
          useMaterial3: true,
          scaffoldBackgroundColor: Colors.black,
          canvasColor: Colors.black,
          cardColor: Colors.grey[900],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppTheme>(
      valueListenable: ThemeController.instance,
      builder: (context, themeChoice, _) {
        return ValueListenableBuilder<AppLanguage>(
          valueListenable: LanguageController.instance,
          builder: (context, languageChoice, _) {
            return DynamicColorBuilder(
              builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
                // Choose the appropriate color scheme based on the theme
                final isDark = themeChoice != AppTheme.light;
                final dynamicColorScheme = isDark ? darkDynamic : lightDynamic;

                return MaterialApp(
                  title: Translations.appTitle,
                  locale: LanguageController.instance.locale,
                  supportedLocales: const [
                    Locale('en', 'US'),
                    Locale('tr', 'TR'),
                  ],
                  localizationsDelegates: const [
                    GlobalMaterialLocalizations.delegate,
                    GlobalWidgetsLocalizations.delegate,
                    GlobalCupertinoLocalizations.delegate,
                  ],
                  theme: _themeFor(
                    themeChoice,
                    dynamicColorScheme: dynamicColorScheme,
                  ),
                  darkTheme: _themeFor(
                    themeChoice,
                    dynamicColorScheme: darkDynamic,
                  ),
                  themeMode: themeChoice == AppTheme.light
                      ? ThemeMode.light
                      : (themeChoice == AppTheme.darkGray
                            ? ThemeMode.dark
                            : ThemeMode.dark),
                  home: widget.showIntro
                      ? IntroScreen(
                          onGetStarted: (ctx) {
                            ThemeController.setSeenIntro();
                            Navigator.of(ctx).pushReplacement(
                              MaterialPageRoute(
                                builder: (_) => const DashboardScreen(),
                              ),
                            );
                          },
                        )
                      : const DashboardScreen(),
                );
              },
            );
          },
        );
      },
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with SingleTickerProviderStateMixin {
  // 0 = Medicine Tracker, 1 = Drugstore Map
  int _selectedIndex = 0;
  bool _notificationsEnabled = true;
  String _userName = '';
  late PageController _pageController;
  final MedicationRepository _medicationRepository = MedicationRepository();
  late Future<List<Medication>> _medicationsFuture;
  final Set<int> _markingMedicationIndices = <int>{};
  List<Medication>? _latestMedications;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _initializeMedications();
    _loadPrefs();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('user_name') ?? '';
    final notif =
        prefs.getBool('notifications_enabled') ?? _notificationsEnabled;
    setState(() {
      _userName = name;
      _notificationsEnabled = notif;
    });
    await _syncNotifications();
  }

  void _initializeMedications() {
    final future = _medicationRepository.loadMedications();
    _medicationsFuture = future;
    future
        .then((medications) {
          _latestMedications = medications;
          return _syncNotifications(medications: medications);
        })
        .catchError((_) {});
  }

  void _refreshMedications() {
    final future = _medicationRepository.loadMedications();
    setState(() {
      _medicationsFuture = future;
    });
    future
        .then((medications) {
          _latestMedications = medications;
          return _syncNotifications(medications: medications);
        })
        .catchError((_) {});
  }

  Future<void> _syncNotifications({List<Medication>? medications}) async {
    final meds = medications ?? _latestMedications;
    if (meds == null) {
      try {
        final latest = await _medicationRepository.loadMedications();
        _latestMedications = latest;
        await NotificationService.instance.syncMedications(
          latest,
          notificationsEnabled: _notificationsEnabled,
        );
      } catch (_) {}
      return;
    }

    try {
      await NotificationService.instance.syncMedications(
        meds,
        notificationsEnabled: _notificationsEnabled,
      );
    } catch (_) {}
  }

  Future<void> _onAddMedicationPressed() async {
    final medication = await _showAddMedicationSheet();
    if (medication == null) {
      return;
    }

    try {
      await _medicationRepository.addMedication(medication);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(Translations.unableToSaveMedication)),
      );
      return;
    }

    if (!mounted) {
      return;
    }

    _refreshMedications();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(Translations.medicationAdded)),
    );
  }

  Future<void> _markMedicationTaken(int index) async {
    if (_markingMedicationIndices.contains(index)) {
      return;
    }

    setState(() {
      _markingMedicationIndices.add(index);
    });

    try {
      final medications = await _medicationRepository.loadMedications();
      if (index < 0 || index >= medications.length) {
        return;
      }

      final updatedMedication = medications[index].copyWith(
        isHistoric: true,
        isEnabled: false,
      );

      medications[index] = updatedMedication;
      await _medicationRepository.saveMedications(medications);

      if (!mounted) {
        return;
      }

      _refreshMedications();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(Translations.medicationMarkedAsTaken)),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(Translations.unableToSaveMedication)),
      );
    } finally {
      if (mounted) {
        setState(() {
          _markingMedicationIndices.remove(index);
        });
      }
    }
  }

  Future<Medication?> _showAddMedicationSheet() async {
    return showModalBottomSheet<Medication>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _AddMedicationSheet(),
    );
  }

  String _greetingText() {
    final hour = DateTime.now().hour;
    final prefix = hour < 12
        ? Translations.goodMorning
        : (hour < 18 ? Translations.goodAfternoon : Translations.goodEvening);
    if (_userName.isNotEmpty) return '$prefix, $_userName';
    return prefix;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      // We use a custom top area instead of AppBar to match the expressive layout
      body: SafeArea(
        child: Column(
          children: [
            // Top greeting row + settings/notifications
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
                  // Settings button with Material 3 style
                  IconButton.filledTonal(
                    style: IconButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    ),
                    tooltip: 'Settings',
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const SettingsScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.settings_outlined, size: 22),
                  ),
                  const SizedBox(width: 8),
                  // Notification button with Material 3 style
                  IconButton.filledTonal(
                    style: IconButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      backgroundColor: _notificationsEnabled
                          ? theme.colorScheme.primaryContainer
                          : theme.colorScheme.surfaceVariant,
                    ),
                    tooltip: _notificationsEnabled
                        ? 'Disable notifications'
                        : 'Enable notifications',
                    onPressed: () async {
                      final prefs = await SharedPreferences.getInstance();
                      final nextValue = !_notificationsEnabled;
                      setState(() {
                        _notificationsEnabled = nextValue;
                      });
                      await prefs.setBool(
                        'notifications_enabled',
                        nextValue,
                      );
                      await _syncNotifications();
                    },
                    icon: Icon(
                      _notificationsEnabled
                          ? Icons.notifications_active_outlined
                          : Icons.notifications_off_outlined,
                      color: _notificationsEnabled
                          ? theme.colorScheme.onPrimaryContainer
                          : theme.colorScheme.onSurfaceVariant,
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),

            // Search row with history icon to its right - Only show in dashboard (_selectedIndex == 0)
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
                  // Dashboard content
                  SingleChildScrollView(
                    key: const PageStorageKey('dashboard'),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _greetingText(),
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          Translations.todaysSchedule,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 16),
                        FutureBuilder<List<Medication>>(
                          future: _medicationsFuture,
                          builder: (context, snapshot) {
                            final theme = Theme.of(context);

                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const SizedBox(
                                height: 80,
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            }

                            if (snapshot.hasError) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    Translations.unableToLoadMedications,
                                    style: TextStyle(
                                      color: theme.colorScheme.error,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextButton(
                                    onPressed: _refreshMedications,
                                    child: const Text('Retry'),
                                  ),
                                ],
                              );
                            }

                            final allMedications = snapshot.data ?? <Medication>[];
                            final activeEntries = <MapEntry<int, Medication>>[];
                            for (var i = 0; i < allMedications.length; i++) {
                              final med = allMedications[i];
                              if (med.isEnabled && !med.isHistoric) {
                                activeEntries.add(MapEntry(i, med));
                              }
                            }

                            if (activeEntries.isEmpty) {
                              return Text(
                                Translations.noMedicationsAdded,
                                style: TextStyle(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              );
                            }

                            return _buildScheduleSections(
                              context,
                              activeEntries,
                            );
                          },
                        ),
                        const SizedBox(height: 120), // Space for bottom bar
                      ],
                    ),
                  ),
                  // Map screen
                  const DrugstoreMapScreen(),
                ],
              ),
            ),
          ],
        ),
      ),

      // Bottom navigation with notched FAB in center
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainer,
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
          height: 76, // Slightly increased height to better accommodate icons
          padding: EdgeInsets.zero,
          surfaceTintColor: Colors.transparent,
          clipBehavior: Clip.antiAlias,
          child: Row(
            children: [
              // Left item (Dashboard)
              Expanded(
                child: _BottomNavTile(
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

              // Middle area with Add Drug text
              SizedBox(
                width: 72,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      height: 28,
                    ), // Push text down to align with FAB
                    Text(
                      Translations.addDrug,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              // Right item (Map)
              Expanded(
                child: _BottomNavTile(
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
        padding: const EdgeInsets.only(
          bottom: 12,
        ), // More bottom padding for FAB
        child: SizedBox(
          width: 68, // Slightly larger FAB
          height: 68, // Slightly larger FAB
          child: FloatingActionButton(
            onPressed: _onAddMedicationPressed,
            elevation: 6,
            backgroundColor: Theme.of(context).colorScheme.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(Icons.add, size: 32),
          ),
        ),
      ),
    );
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
      final theme = Theme.of(context);
      return Text(
        Translations.noMedicationsAdded,
        style: TextStyle(
          color: theme.colorScheme.onSurfaceVariant,
        ),
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
        children.add(
          _medCard(
            context,
            entry.value,
            onMarkTaken: () => _markMedicationTaken(entry.key),
            isMarking: _markingMedicationIndices.contains(entry.key),
          ),
        );
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

  Color _badgeColorForPeriod(MedicationPeriod period, ThemeData theme) {
    final scheme = theme.colorScheme;
    switch (period) {
      case MedicationPeriod.morning:
        return scheme.primaryContainer.withOpacity(0.6);
      case MedicationPeriod.afternoon:
        return scheme.secondaryContainer.withOpacity(0.6);
      case MedicationPeriod.evening:
        return scheme.tertiaryContainer.withOpacity(0.6);
    }
  }

  IconData _iconForPeriod(MedicationPeriod period) {
    switch (period) {
      case MedicationPeriod.morning:
        return Icons.wb_sunny_outlined;
      case MedicationPeriod.afternoon:
        return Icons.medication_outlined;
      case MedicationPeriod.evening:
        return Icons.nightlight_outlined;
    }
  }

  int _compareTimeOfDay(TimeOfDay a, TimeOfDay b) {
    final aMinutes = a.hour * 60 + a.minute;
    final bMinutes = b.hour * 60 + b.minute;
    return aMinutes.compareTo(bMinutes);
  }

  // small card to match the attachment look
  Widget _medCard(
    BuildContext context,
    Medication medication, {
    VoidCallback? onMarkTaken,
    bool isMarking = false,
  }) {
    final theme = Theme.of(context);
    final badgeColor = _badgeColorForPeriod(medication.period, theme);
    final badgeIcon = _iconForPeriod(medication.period);
    final formattedTime = medication.time.format(context);

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
          Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              color: badgeColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              badgeIcon,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${medication.name}, ${medication.dose}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Text(
                  formattedTime,
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
          const SizedBox(width: 8),
          Container(
            height: 36,
            width: 36,
            decoration: BoxDecoration(
              border: Border.all(color: theme.colorScheme.outlineVariant),
              borderRadius: BorderRadius.circular(8),
            ),
            child: isMarking
                ? Padding(
                    padding: const EdgeInsets.all(8),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        theme.colorScheme.primary,
                      ),
                    ),
                  )
                : IconButton(
                    tooltip: Translations.markMedicationTaken,
                    padding: EdgeInsets.zero,
                    icon: Icon(
                      Icons.check_box_outline_blank,
                      size: 20,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    onPressed: onMarkTaken,
                  ),
          ),
        ],
      ),
    );
  }
}

class _AddMedicationSheet extends StatefulWidget {
  const _AddMedicationSheet();

  @override
  State<_AddMedicationSheet> createState() => _AddMedicationSheetState();
}

class _AddMedicationSheetState extends State<_AddMedicationSheet> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _doseController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  TimeOfDay? _selectedTime;
  String? _errorText;

  @override
  void dispose() {
    _nameController.dispose();
    _doseController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
        _errorText = null;
      });
    }
  }

  void _submit() {
    final name = _nameController.text.trim();
    final dose = _doseController.text.trim();
    final notes = _notesController.text.trim();

    if (name.isEmpty || dose.isEmpty || _selectedTime == null) {
      setState(() {
        _errorText = Translations.medicationFormIncomplete;
      });
      return;
    }

    FocusScope.of(context).unfocus();
    final time = _selectedTime!;
    final period = _periodForTime(time);

    Navigator.of(context).pop(
      Medication(
        name: name,
        dose: dose,
        time: time,
        period: period,
        notes: notes.isEmpty ? null : notes,
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
    final timeLabel = _selectedTime != null
        ? MaterialLocalizations.of(context).formatTimeOfDay(
            _selectedTime!,
            alwaysUse24HourFormat: mediaQuery.alwaysUse24HourFormat,
          )
        : Translations.selectTime;

    return Padding(
      padding: EdgeInsets.only(bottom: mediaQuery.viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              Translations.addDrug,
              style: theme.textTheme.titleMedium,
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
            Text(
              Translations.usageTime,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 6),
            OutlinedButton.icon(
              onPressed: _pickTime,
              icon: const Icon(Icons.access_time),
              label: Text(timeLabel),
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

class _BottomNavTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  const _BottomNavTile({
    required this.icon,
    required this.label,
    required this.selected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = selected
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height:
            kBottomNavigationBarHeight -
            -16, // Reduced height to allow higher placement
        constraints: const BoxConstraints(minWidth: 64),
        padding: const EdgeInsets.only(top: 4), // Slightly more top padding
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment
              .center, // Center vertically in the reduced height
          children: [
            // Icon with selection background
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Background circle for selected state
                  if (selected)
                    Container(
                      width: 28, // Slightly smaller circle
                      height: 28,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer.withOpacity(
                          0.5,
                        ), // More transparent
                        borderRadius: BorderRadius.circular(3), // Less circular
                      ),
                    ),
                  Icon(icon, color: color, size: 22),
                ],
              ),
            ),
            const SizedBox(height: 2),
            // Selection dot
            if (selected)
              Container(
                width: 4,
                height: 4,
                margin: const EdgeInsets.only(
                  bottom: 2,
                ), // Reduced bottom margin
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
            // Text with proper constraints and padding
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
