import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/theme_controller.dart';

class IntroScreen extends StatefulWidget {
  final void Function(BuildContext context)? onGetStarted;
  const IntroScreen({super.key, this.onGetStarted});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  final TextEditingController _nameController = TextEditingController();
  bool _followSystem = true;
  AppTheme _selected = ThemeController.instance.value;
  bool _materialYou = ThemeController.instance.materialYou;
  bool _notifications = true;
  bool _locationPermissionGranted = false;
  bool _notificationPermissionGranted = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveAndContinue(BuildContext ctx) async {
    // Apply theme choice (if followSystem, pick based on platform brightness)
    final brightness = MediaQuery.of(ctx).platformBrightness;
    AppTheme applyTheme = _selected;
    if (_followSystem) {
      applyTheme = (brightness == Brightness.dark) ? AppTheme.darkGray : AppTheme.light;
    }

  ThemeController.instance.setTheme(applyTheme);
  ThemeController.instance.setMaterialYou(_materialYou);

    // Persist some simple prefs (name and notifications)
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('user_name', _nameController.text.trim());
      prefs.setBool('notifications_enabled', _notifications);
    });

    // mark intro seen (async, don't await to avoid context-after-async)
    ThemeController.setSeenIntro();

    // navigate to main dashboard immediately using provided context
    if (widget.onGetStarted != null) {
      widget.onGetStarted!(ctx);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  height: 84,
                  width: 84,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(Icons.local_pharmacy_outlined, size: 44, color: theme.colorScheme.primary),
                ),
              ),
              const SizedBox(height: 18),
              Center(
                child: Text('Welcome to DoseMite', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 6),
              Center(
                child: Text('Set up your app in a few steps', style: theme.textTheme.bodyMedium),
              ),

              const SizedBox(height: 20),

              // Name
              const Text('What should we call you?', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextField(
                controller: _nameController,
                decoration: InputDecoration(hintText: 'Your name', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
              ),

              const SizedBox(height: 18),

              // Theme: follow system or choose
              Row(
                children: [
                  Checkbox(
                    value: _followSystem,
                    onChanged: (v) {
                      setState(() {
                        _followSystem = v ?? true;
                        // apply immediately
                        if (_followSystem) {
                          final brightness = MediaQuery.of(context).platformBrightness;
                          final apply = (brightness == Brightness.dark) ? AppTheme.darkGray : AppTheme.light;
                          ThemeController.instance.setTheme(apply);
                        } else {
                          ThemeController.instance.setTheme(_selected);
                        }
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  const Expanded(child: Text('Follow system theme')),
                ],
              ),

              if (!_followSystem) ...[
                const SizedBox(height: 8),
                const Text('Choose style', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('White'),
                      selected: _selected == AppTheme.light,
                      onSelected: (_) {
                        setState(() {
                          _selected = AppTheme.light;
                          ThemeController.instance.setTheme(_selected);
                        });
                      },
                    ),
                    ChoiceChip(
                      label: const Text('Gray / Black'),
                      selected: _selected == AppTheme.darkGray,
                      onSelected: (_) {
                        setState(() {
                          _selected = AppTheme.darkGray;
                          ThemeController.instance.setTheme(_selected);
                        });
                      },
                    ),
                    ChoiceChip(
                      label: const Text('Pitch / AMOLED Black'),
                      selected: _selected == AppTheme.amoled,
                      onSelected: (_) {
                        setState(() {
                          _selected = AppTheme.amoled;
                          ThemeController.instance.setTheme(_selected);
                        });
                      },
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 18),

              // Material You toggle
              SwitchListTile(
                title: const Text('Material You'),
                subtitle: const Text('Use dynamic seed-based Material 3 color scheme'),
                value: _materialYou,
                onChanged: (v) {
                  setState(() {
                    _materialYou = v;
                    ThemeController.instance.setMaterialYou(_materialYou);
                    // reapply current base theme so changes reflect immediately
                    if (_followSystem) {
                      final brightness = MediaQuery.of(context).platformBrightness;
                      final apply = (brightness == Brightness.dark) ? AppTheme.darkGray : AppTheme.light;
                      ThemeController.instance.setTheme(apply);
                    } else {
                      ThemeController.instance.setTheme(_selected);
                    }
                  });
                },
              ),

              const SizedBox(height: 10),

              // Notifications opt-in
              SwitchListTile(
                title: const Text('Enable notifications'),
                subtitle: const Text('Get reminders about your medications'),
                value: _notifications,
                onChanged: (v) => setState(() => _notifications = v),
              ),

              const SizedBox(height: 10),

              // Permissions section
              const Text('Permissions', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.location_on_outlined),
                title: const Text('Location'),
                subtitle: const Text('Allow finding nearby pharmacies'),
                trailing: TextButton(
                  child: Text(_locationPermissionGranted ? 'Granted' : 'Allow'),
                  onPressed: () {
                    // Placeholder: in a real app request actual permission
                    setState(() => _locationPermissionGranted = true);
                  },
                ),
              ),
              ListTile(
                leading: const Icon(Icons.notifications_outlined),
                title: const Text('Notifications'),
                subtitle: const Text('Allow sending medication reminders'),
                trailing: TextButton(
                  child: Text(_notificationPermissionGranted ? 'Granted' : 'Allow'),
                  onPressed: () {
                    setState(() => _notificationPermissionGranted = true);
                  },
                ),
              ),

              const SizedBox(height: 18),

              // Get started button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _saveAndContinue(context),
                  style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(52), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: const Text('Finish setup'),
                ),
              ),

              const SizedBox(height: 12),
              Center(
                child: TextButton(onPressed: () => _saveAndContinue(context), child: const Text('Skip for now')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
