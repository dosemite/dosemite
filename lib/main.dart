import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/intro.dart';
import 'screens/drugstore_map.dart';
import 'screens/settings.dart';
import 'screens/history.dart';
import 'theme/theme_controller.dart';
import 'theme/language_controller.dart';
import 'utils/translations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Tema ve dil ayarlarını yükle
  await Future.wait([
    ThemeController.instance.loadFromPrefs(),
    LanguageController.instance.loadFromPrefs(),
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

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
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
                      setState(
                        () => _notificationsEnabled = !_notificationsEnabled,
                      );
                      await prefs.setBool(
                        'notifications_enabled',
                        _notificationsEnabled,
                      );
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
                        _medCard(
                          'Metformin',
                          '500mg',
                          '9:00 AM',
                          Colors.blue.shade100,
                          Icons.medication,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          Translations.afternoon,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        _medCard(
                          'Atorvastatin',
                          '20mg',
                          '1:00 PM',
                          Colors.orange.shade100,
                          Icons.local_hospital,
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
            onPressed: () {
              // open add drug flow
            },
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

  // small card to match the attachment look
  Widget _medCard(
    String name,
    String dose,
    String time,
    Color bg,
    IconData leading,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
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
              color: bg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(leading, color: Colors.black54),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$name, $dose',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Text(
                  time,
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            height: 28,
            width: 28,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(
              Icons.check_box_outline_blank,
              size: 18,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
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
