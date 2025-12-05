import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/medication_repository.dart';
import '../models/medication.dart';
import '../screens/qr_import_screen.dart';
import '../services/notification_service.dart';
import '../theme/language_controller.dart';
import '../theme/theme_controller.dart';
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
  final MedicationRepository _repository = MedicationRepository();

  // Debug menu access
  int _aboutClickCount = 0;
  bool _debugMenuVisible = false;

  @override
  void initState() {
    super.initState();
    _loadUserName();
    LanguageController.instance.addListener(_onLanguageChanged);
  }

  Future<void> _showBackupQr() async {
    try {
      final medications = await _repository.loadMedications();
      final payload = jsonEncode(
        medications.map((med) => med.toJson()).toList(growable: false),
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text(Translations.backupViaQr),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 240,
                  height: 240,
                  child: QrImageView(
                    data: payload,
                    version: QrVersions.auto,
                    errorCorrectionLevel: QrErrorCorrectLevel.Q,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  Translations.backupViaQrSubtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(Translations.cancel),
              ),
            ],
          );
        },
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(Translations.backupFailed)));
    }
  }

  Future<void> _restoreFromQr() async {
    final result = await Navigator.of(
      context,
    ).push<String>(MaterialPageRoute(builder: (_) => const QrImportScreen()));
    if (result == null || result.isEmpty) {
      return;
    }

    try {
      final decoded = jsonDecode(result);
      if (decoded is! List) {
        throw const FormatException('Payload is not a list');
      }
      final medications = decoded
          .map(
            (entry) =>
                Medication.fromJson(Map<String, dynamic>.from(entry as Map)),
          )
          .toList(growable: false);
      await _repository.saveMedications(medications);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(Translations.importSuccess)));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(Translations.importFailed)));
    }
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(Translations.usernameUpdated)));
    }
  }

  Future<void> _openGitHub() async {
    final url = Uri.parse('https://github.com/dosemite/dosemite');
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
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
            child: Text(
              Translations.account,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
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
            child: Text(
              Translations.language,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
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
                          onTap: () =>
                              Navigator.pop(context, AppLanguage.english),
                        ),
                        ListTile(
                          title: Text(Translations.turkish),
                          leading: _selectedLanguage == AppLanguage.turkish
                              ? const Icon(Icons.check)
                              : null,
                          onTap: () =>
                              Navigator.pop(context, AppLanguage.turkish),
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
            child: Text(
              Translations.appearance,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
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
                          onTap: () =>
                              Navigator.pop(context, AppTheme.darkGray),
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
            child: Text(
              Translations.about,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),

          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(Translations.aboutDoseMite),
            subtitle: Text(Translations.version),
            onTap: () {
              setState(() {
                _aboutClickCount++;
                if (_aboutClickCount >= 3 && !_debugMenuVisible) {
                  _debugMenuVisible = true;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Debug menu unlocked'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              });
            },
          ),

          ListTile(
            leading: const Icon(Icons.code_outlined),
            title: Text(Translations.sourceCode),
            subtitle: Text(Translations.viewOnGitHub),
            trailing: const Icon(Icons.open_in_new),
            onTap: _openGitHub,
          ),

          const Divider(),

          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              Translations.backupAndTransfer,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),

          ListTile(
            leading: const Icon(Icons.qr_code_2),
            title: Text(Translations.backupViaQr),
            subtitle: Text(Translations.backupViaQrSubtitle),
            onTap: _showBackupQr,
          ),

          ListTile(
            leading: const Icon(Icons.qr_code_scanner),
            title: Text(Translations.restoreFromQr),
            onTap: _restoreFromQr,
          ),

          // Debug section - only visible after 3 clicks on About DoseMite
          if (_debugMenuVisible) ...[
            const Divider(),

            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                'Debug',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),

            ListTile(
              leading: const Icon(Icons.notifications_active),
              title: const Text('Test Notification'),
              subtitle: const Text('Send an immediate test notification'),
              onTap: () async {
                final success = await NotificationService.instance
                    .showTestNotification();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success
                          ? 'Test notification sent! Check your notifications.'
                          : 'Failed to send test notification.',
                    ),
                  ),
                );
              },
            ),

            ListTile(
              leading: const Icon(Icons.schedule),
              title: const Text('Test Scheduled (10 sec)'),
              subtitle: const Text(
                'Schedule a notification for 10 seconds from now',
              ),
              onTap: () async {
                final result = await NotificationService.instance
                    .showScheduledTestNotification();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(result),
                    duration: const Duration(seconds: 5),
                  ),
                );
              },
            ),

            ListTile(
              leading: const Icon(Icons.access_time),
              title: const Text('Fix Timezone'),
              subtitle: const Text(
                'Re-detect timezone and reschedule notifications',
              ),
              onTap: () async {
                final result = await NotificationService.instance
                    .forceReinitializeTimezone();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(result),
                    duration: const Duration(seconds: 5),
                  ),
                );
              },
            ),

            ListTile(
              leading: const Icon(Icons.bug_report),
              title: const Text('Notification Diagnostics'),
              subtitle: const Text('View notification system status'),
              onTap: () async {
                final diagnostics = await NotificationService.instance
                    .getDiagnostics();
                if (!mounted) return;
                await showDialog<void>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Notification Diagnostics'),
                    content: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: diagnostics.entries.map((entry) {
                          final value = entry.value;
                          final valueStr = value is List
                              ? value.join('\n')
                              : value.toString();
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  entry.key,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  valueStr,
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],

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
