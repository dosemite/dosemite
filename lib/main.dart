import 'package:flutter/material.dart';
import 'screens/intro.dart';
import 'screens/drugstore_map.dart';
import 'screens/settings.dart';
import 'screens/history.dart';
import 'theme/theme_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ThemeController.instance.loadFromPrefs();
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
  ThemeData _themeFor(AppTheme t) {
    // If Material You is enabled, use a seed-based ColorScheme with the chosen brightness
    final materialYou = ThemeController.instance.materialYou;
    final brightness = (t == AppTheme.light) ? Brightness.light : Brightness.dark;

    if (materialYou) {
      final base = ThemeData.from(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple, brightness: brightness),
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
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey, brightness: Brightness.dark),
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
        return MaterialApp(
          title: 'Pharmacy App',
          theme: _themeFor(themeChoice),
          home: widget.showIntro
              ? IntroScreen(onGetStarted: (ctx) {
                  ThemeController.setSeenIntro();
                  // navigate to dashboard using the IntroScreen context (ctx)
                  Navigator.of(ctx).pushReplacement(MaterialPageRoute(builder: (_) => const DashboardScreen()));
                })
              : const DashboardScreen(),
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

class _DashboardScreenState extends State<DashboardScreen> {
  // 0 = Medicine Tracker, 1 = Drugstore Map
  int _selectedIndex = 0;
  bool _notificationsEnabled = true;
  String _userName = '';

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('user_name') ?? '';
    final notif = prefs.getBool('notifications_enabled') ?? _notificationsEnabled;
    setState(() {
      _userName = name;
      _notificationsEnabled = notif;
    });
  }

  String _greetingText() {
    final hour = DateTime.now().hour;
    final prefix = hour < 12 ? 'Good Morning' : (hour < 18 ? 'Good Afternoon' : 'Good Evening');
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
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
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
                  IconButton(
                    tooltip: 'Settings',
                    onPressed: () {
                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
                    },
                    icon: const Icon(Icons.settings_outlined),
                  ),
                  // Notification enable/disable icon (toggles state)
                  IconButton(
                    tooltip: _notificationsEnabled ? 'Disable notifications' : 'Enable notifications',
                    onPressed: () async {
                      // Toggle and persist without causing the FAB to shift when the SnackBar appears.
                      final prefs = await SharedPreferences.getInstance();
                      // update local state after prefs to ensure persistence
                      setState(() => _notificationsEnabled = !_notificationsEnabled);
                      await prefs.setBool('notifications_enabled', _notificationsEnabled);

                      // Show a floating SnackBar so it doesn't resize the Scaffold and move the FAB.
                      if (!mounted) return;
                      final fabSize = 86.0;
                      ScaffoldMessenger.of(context).hideCurrentSnackBar();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(_notificationsEnabled ? 'Notifications enabled' : 'Notifications disabled'),
                          behavior: SnackBarBehavior.floating,
                          margin: EdgeInsets.fromLTRB(16, 0, 16, fabSize + 24),
                        ),
                      );
                    },
                    icon: Icon(
                      _notificationsEnabled ? Icons.notifications_active_outlined : Icons.notifications_off_outlined,
                      color: _notificationsEnabled ? theme.colorScheme.primary : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),

            // Search row with history icon to its right
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 46,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Search medications...',
                          prefixIcon: const Icon(Icons.search),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    height: 46,
                    width: 46,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.6),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.history),
                      onPressed: () {
                        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HistoryScreen()));
                      },
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: IndexedStack(
                index: _selectedIndex,
                children: [
                  // Medicine Tracker screen (placeholder list designed like attachment)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: ListView(
                      children: [
                        const SizedBox(height: 8),
                        const Text('Morning', style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        _medCard('Lisinopril', '10mg', '9:00 AM', Colors.blue.shade100, Icons.medication),
                        const SizedBox(height: 8),
                        _medCard('Metformin', '500mg', '9:00 AM', Colors.blue.shade100, Icons.medication),
                        const SizedBox(height: 16),
                        const Text('Afternoon', style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        _medCard('Atorvastatin', '20mg', '1:00 PM', Colors.orange.shade100, Icons.local_hospital),
                                  const SizedBox(height: 120), // Give more space above bottom bar so last item isn't obscured
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
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 6,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              // Left item (Medicine Tracker)
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _selectedIndex = 0),
                  child: _BottomNavTile(
                    icon: Icons.dashboard_customize_outlined,
                    label: 'Dashboard',
                    selected: _selectedIndex == 0,
                  ),
                ),
              ),

              // Middle fixed-width area for FAB notch + label so the bar doesn't create an extra gap
              SizedBox(
                width: 72,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // push label lower inside the bottom bar so it doesn't sit between the FAB and the bar edge
                    const SizedBox(height: 26),
                    Text(
                      'Add Drug',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _selectedIndex == -1 ? Theme.of(context).colorScheme.primary : Colors.grey[800],
                      ),
                    ),
                  ],
                ),
              ),

              // Right item (Map)
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _selectedIndex = 1),
                  child: _BottomNavTile(
                    icon: Icons.map_outlined,
                    label: 'Map',
                    selected: _selectedIndex == 1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),

      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: SizedBox(
          width: 72,
          height: 72,
          child: FloatingActionButton(
            onPressed: () {
              // open add drug flow
            },
            elevation: 6,
            backgroundColor: Theme.of(context).colorScheme.primary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: const Icon(Icons.add, size: 32),
          ),
        ),
      ),
    );
  }

  // small card to match the attachment look
  Widget _medCard(String name, String dose, String time, Color bg, IconData leading) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
            child: Icon(leading, color: Colors.black54),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$name, $dose', style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text(time, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
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
            child: const Icon(Icons.check_box_outline_blank, size: 18, color: Colors.grey),
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

  const _BottomNavTile({required this.icon, required this.label, required this.selected});

  @override
  Widget build(BuildContext context) {
    final color = selected ? Theme.of(context).colorScheme.primary : Colors.grey[600];
    return SizedBox(
      height: double.infinity,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(color: color, fontSize: 12)),
        ],
      ),
    );
  }
}
