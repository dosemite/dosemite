import 'package:flutter/material.dart';
import '../theme/theme_controller.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  AppTheme _selected = ThemeController.instance.value;
  bool _materialYou = ThemeController.instance.materialYou;

  @override
  Widget build(BuildContext context) {
  return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Text('Appearance', style: TextStyle(fontWeight: FontWeight.w600)),
          ),

          // Selected mode tile: opens modal to choose between White, Gray/Black, Pitch Black
          ListTile(
            title: const Text('Selected mode'),
            subtitle: Text(_labelFor(_selected)),
            trailing: const Icon(Icons.arrow_drop_down),
            onTap: () async {
              final choice = await showModalBottomSheet<AppTheme>(
                context: context,
                builder: (context) {
                  return SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          title: const Text('White (Light)'),
                          onTap: () => Navigator.pop(context, AppTheme.light),
                        ),
                        ListTile(
                          title: const Text('Gray / Black'),
                          onTap: () => Navigator.pop(context, AppTheme.darkGray),
                        ),
                        ListTile(
                          title: const Text('Pitch / AMOLED Black'),
                          onTap: () => Navigator.pop(context, AppTheme.amoled),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  );
                },
              );

              if (choice != null) {
                setState(() {
                  _selected = choice;
                  ThemeController.instance.setTheme(choice);
                });
              }
            },
          ),

          const Divider(),

          // Material You independent toggle
          SwitchListTile(
            title: const Text('Material You'),
            subtitle: const Text('Use dynamic seed-based Material 3 color scheme'),
            value: _materialYou,
            onChanged: (v) {
              setState(() {
                _materialYou = v;
                ThemeController.instance.setMaterialYou(v);
              });
            },
          ),

          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About DoseMite'),
            subtitle: const Text('Version 1.0.0'),
            onTap: () {},
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  String _labelFor(AppTheme t) {
    switch (t) {
      case AppTheme.light:
        return 'White (Light)';
      case AppTheme.darkGray:
        return 'Gray / Black';
      case AppTheme.amoled:
        return 'Pitch / AMOLED Black';
    }
  }
}
