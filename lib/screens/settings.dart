import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/theme_controller.dart';
import '../theme/language_controller.dart';
import '../utils/translations.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  AppTheme _selected = ThemeController.instance.value;
  bool _materialYou = ThemeController.instance.materialYou;
  AppLanguage _selectedLanguage = LanguageController.instance.value;
  final TextEditingController _nameController = TextEditingController();
  String _userName = '';

  @override
  void initState() {
    super.initState();
    _loadUserName();
    LanguageController.instance.addListener(_onLanguageChanged);
  }

  @override
  void dispose() {
    LanguageController.instance.removeListener(_onLanguageChanged);
    _nameController.dispose();
    super.dispose();
  }

  void _onLanguageChanged() {
    setState(() {
      _selectedLanguage = LanguageController.instance.value;
    });
  }

  Future<void> _loadUserName() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('user_name') ?? 'user';
    setState(() {
      _userName = name;
      _nameController.text = name;
    });
  }

  Future<void> _saveUserName() async {
    final prefs = await SharedPreferences.getInstance();
    final name = _nameController.text.trim();
    final finalName = name.isEmpty ? 'user' : name;
    await prefs.setString('user_name', finalName);
    setState(() {
      _userName = finalName;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(Translations.usernameUpdated)),
      );
    }
  }

  Future<void> _openGitHub() async {
    final url = Uri.parse('https://github.com/dosemite/dosemite');
    try {
      if (!await launchUrl(
        url,
        mode: LaunchMode.externalApplication,
      )) {
        throw Exception('Could not launch $url');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(Translations.couldNotOpenGitHubPage),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(Translations.settings)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Account section
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text(Translations.account, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),

          ListTile(
            leading: const Icon(Icons.person_outline),
            title: Text(Translations.username),
            subtitle: Text(_userName),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final result = await showDialog<String>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(Translations.changeUsername),
                  content: TextField(
                    controller: _nameController,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: Translations.enterYourName,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(Translations.cancel),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context, _nameController.text);
                      },
                      child: Text(Translations.save),
                    ),
                  ],
                ),
              );
              if (result != null) {
                _nameController.text = result;
                await _saveUserName();
              }
            },
          ),

          const Divider(),

          // Language section
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text(Translations.language, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),

          ListTile(
            leading: const Icon(Icons.language_outlined),
            title: Text(Translations.language),
            subtitle: Text(LanguageController.instance.languageName),
            trailing: const Icon(Icons.arrow_drop_down),
            onTap: () async {
              final choice = await showModalBottomSheet<AppLanguage>(
                context: context,
                builder: (context) {
                  return SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          title: Text(Translations.english),
                          leading: _selectedLanguage == AppLanguage.english
                              ? const Icon(Icons.check)
                              : null,
                          onTap: () => Navigator.pop(context, AppLanguage.english),
                        ),
                        ListTile(
                          title: Text(Translations.turkish),
                          leading: _selectedLanguage == AppLanguage.turkish
                              ? const Icon(Icons.check)
                              : null,
                          onTap: () => Navigator.pop(context, AppLanguage.turkish),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  );
                },
              );

              if (choice != null) {
                LanguageController.instance.setLanguage(choice);
              }
            },
          ),

          const Divider(),

          // Appearance section
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text(Translations.appearance, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),

          // Selected mode tile: opens modal to choose between White, Gray/Black, Pitch Black
          ListTile(
            title: Text(Translations.selectedMode),
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
                          title: Text(Translations.whiteLight),
                          onTap: () => Navigator.pop(context, AppTheme.light),
                        ),
                        ListTile(
                          title: Text(Translations.grayBlack),
                          onTap: () => Navigator.pop(context, AppTheme.darkGray),
                        ),
                        ListTile(
                          title: Text(Translations.pitchAmoledBlack),
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
            title: Text(Translations.materialYou),
            subtitle: Text(Translations.useDynamicSeedBasedMaterial3),
            value: _materialYou,
            onChanged: (v) {
              setState(() {
                _materialYou = v;
                ThemeController.instance.setMaterialYou(v);
              });
            },
          ),

          const Divider(),

          // About section
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text(Translations.about, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),

          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(Translations.aboutDoseMite),
            subtitle: Text(Translations.version),
            onTap: () {},
          ),

          ListTile(
            leading: const Icon(Icons.code_outlined),
            title: Text(Translations.sourceCode),
            subtitle: Text(Translations.viewOnGitHub),
            trailing: const Icon(Icons.open_in_new),
            onTap: _openGitHub,
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  String _labelFor(AppTheme t) {
    switch (t) {
      case AppTheme.light:
        return Translations.whiteLight;
      case AppTheme.darkGray:
        return Translations.grayBlack;
      case AppTheme.amoled:
        return Translations.pitchAmoledBlack;
    }
  }
}
