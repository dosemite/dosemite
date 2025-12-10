import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/cloud_backup_service.dart';
import '../theme/theme_controller.dart';
import '../theme/language_controller.dart';
import '../utils/translations.dart';

class IntroScreen extends StatefulWidget {
  final void Function(BuildContext context)? onGetStarted;
  const IntroScreen({super.key, this.onGetStarted});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  final PageController _pageController = PageController();
  final TextEditingController _nameController = TextEditingController();
  final FocusNode _nameFocusNode = FocusNode();
  int _currentPage = 0;
  bool _followSystem = true;
  AppTheme _selected = ThemeController.instance.value;
  bool _materialYou = ThemeController.instance.materialYou;
  bool _notifications = true;
  bool _locationPermissionGranted = false;
  bool _notificationPermissionGranted = false;
  bool _requestingLocationPermission = false;
  bool _requestingNotificationPermission = false;
  AppLanguage _selectedLanguage = LanguageController.instance.value;

  // Cloud sync state
  final TextEditingController _backupKeyController = TextEditingController();
  bool _isRestoring = false;
  String? _restoreError;
  bool _hasRestoredFromCloud = false;

  @override
  void initState() {
    super.initState();
    LanguageController.instance.loadFromPrefs();
    LanguageController.instance.addListener(_onLanguageChanged);

    // Uygulama ilk açıldığında sistem temasını kontrol et
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final brightness = MediaQuery.of(context).platformBrightness;
      if (mounted) {
        setState(() {
          _followSystem = true;
          if (brightness == Brightness.dark) {
            _selected = AppTheme.darkGray;
          } else {
            _selected = AppTheme.light;
          }
        });
      }
    });

    _refreshPermissionStatuses();
  }

  @override
  void dispose() {
    LanguageController.instance.removeListener(_onLanguageChanged);
    _pageController.dispose();
    _nameController.dispose();
    _backupKeyController.dispose();
    _nameFocusNode.dispose();
    super.dispose();
  }

  Permission get _locationPermission =>
      Platform.isIOS ? Permission.locationWhenInUse : Permission.location;

  bool _isLocationAuthorized(PermissionStatus status) =>
      status.isGranted || status.isLimited;

  bool _isNotificationAuthorized(PermissionStatus status) =>
      status.isGranted || status == PermissionStatus.provisional;

  Future<void> _refreshPermissionStatuses() async {
    final locStatus = await _locationPermission.status;
    final notifStatus = await Permission.notification.status;

    if (!mounted) return;
    setState(() {
      _locationPermissionGranted = _isLocationAuthorized(locStatus);
      _notificationPermissionGranted = _isNotificationAuthorized(notifStatus);
    });
  }

  Future<void> _requestLocationPermission() async {
    if (_requestingLocationPermission) return;
    setState(() => _requestingLocationPermission = true);

    final status = await _locationPermission.request();
    final granted = _isLocationAuthorized(status);

    if (!mounted) return;

    setState(() {
      _locationPermissionGranted = granted;
      _requestingLocationPermission = false;
    });

    if (!granted && status.isPermanentlyDenied) {
      _showOpenSettingsSnackbar();
    }
  }

  Future<void> _requestNotificationPermission() async {
    if (_requestingNotificationPermission) return;
    setState(() => _requestingNotificationPermission = true);

    final status = await Permission.notification.request();
    final granted = _isNotificationAuthorized(status);

    if (!mounted) return;

    setState(() {
      _notificationPermissionGranted = granted;
      _requestingNotificationPermission = false;
    });

    if (!granted && status.isPermanentlyDenied) {
      _showOpenSettingsSnackbar();
    }
  }

  void _showOpenSettingsSnackbar() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(Translations.permissionDeniedOpenSettings),
        action: SnackBarAction(
          label: Translations.openSettings,
          onPressed: () {
            openAppSettings();
          },
        ),
      ),
    );
  }

  void _onLanguageChanged() {
    setState(() {
      _selectedLanguage = LanguageController.instance.value;
    });
  }

  Future<void> _saveAndContinue(BuildContext ctx) async {
    // Apply theme choice (if followSystem, pick based on platform brightness)
    final brightness = MediaQuery.of(ctx).platformBrightness;
    AppTheme applyTheme = _selected;
    if (_followSystem) {
      applyTheme = (brightness == Brightness.dark)
          ? AppTheme.darkGray
          : AppTheme.light;
      // Sistem temasını kaydet
      ThemeController.instance.setTheme(applyTheme);
    }

    ThemeController.instance.setTheme(applyTheme);
    ThemeController.instance.setMaterialYou(_materialYou);

    // Persist some simple prefs (name, notifications, and language)
    // Use "user" as default name if empty
    final userName = _nameController.text.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', userName.isEmpty ? 'user' : userName);
    await prefs.setBool('notifications_enabled', _notifications);

    // Save language preference
    LanguageController.instance.setLanguage(_selectedLanguage);

    // mark intro seen (async, don't await to avoid context-after-async)
    ThemeController.setSeenIntro();

    // If user didn't restore from cloud, create initial backup to generate their key
    if (!_hasRestoredFromCloud) {
      // Do this in background, don't block navigation
      CloudBackupService.instance.backupToCloud().then((key) {
        if (key != null) {
          debugPrint(
            'CloudBackupService: Initial backup created with key: $key',
          );
        }
      });
    }

    // navigate to main dashboard immediately using provided context
    if (widget.onGetStarted != null) {
      widget.onGetStarted!(ctx);
    }
  }

  Widget _buildWelcomePage() {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              height: 120,
              width: 120,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(28),
              ),
              child: Icon(
                Icons.local_pharmacy_outlined,
                size: 60,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              Translations.welcomeTitle,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              Translations.welcomeSubtitle,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),

            // Language selection
            Card(
              elevation: 0,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () async {
                  final choice = await showModalBottomSheet<AppLanguage>(
                    context: context,
                    builder: (context) {
                      return SafeArea(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () =>
                                  Navigator.pop(context, AppLanguage.english),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                child: Row(
                                  children: [
                                    if (_selectedLanguage ==
                                        AppLanguage.english)
                                      const Icon(Icons.check, size: 24),
                                    const SizedBox(width: 24),
                                    Text(
                                      Translations.english,
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const Divider(height: 1),
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () =>
                                  Navigator.pop(context, AppLanguage.turkish),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                child: Row(
                                  children: [
                                    if (_selectedLanguage ==
                                        AppLanguage.turkish)
                                      const Icon(Icons.check, size: 24),
                                    const SizedBox(width: 24),
                                    Text(
                                      Translations.turkish,
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                        ),
                      );
                    },
                  );

                  if (choice != null) {
                    setState(() {
                      _selectedLanguage = choice;
                    });
                    // Apply language immediately so it updates live
                    LanguageController.instance.setLanguage(choice);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 16,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.language_outlined),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              Translations.language,
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _selectedLanguage == AppLanguage.english
                                  ? Translations.english
                                  : Translations.turkish,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_drop_down, size: 24),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _restoreFromCloud() async {
    final key = _backupKeyController.text.trim().toUpperCase();
    if (key.isEmpty || key.length < 8) {
      setState(() {
        _restoreError = Translations.invalidKey;
      });
      return;
    }

    setState(() {
      _isRestoring = true;
      _restoreError = null;
    });

    try {
      final success = await CloudBackupService.instance.restoreFromCloud(key);

      if (!mounted) return;

      if (success) {
        // Load the restored username into the controller
        final prefs = await SharedPreferences.getInstance();
        final restoredName = prefs.getString('user_name') ?? '';
        _nameController.text = restoredName;

        setState(() {
          _isRestoring = false;
          _hasRestoredFromCloud = true;
        });

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(Translations.restoreSuccess),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );

        // Move to next page
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      } else {
        setState(() {
          _isRestoring = false;
          _restoreError = Translations.invalidKey;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isRestoring = false;
        _restoreError = Translations.cloudBackupFailed;
      });
    }
  }

  Widget _buildCloudSyncPage() {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              height: 100,
              width: 100,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                Icons.cloud_sync_outlined,
                size: 50,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              Translations.cloudBackup,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              Translations.cloudSyncDescription,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),

            // Restore from backup card
            Card(
              elevation: 0,
              color: theme.colorScheme.primaryContainer.withOpacity(0.3),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.cloud_download_outlined,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            Translations.restoreFromCloud,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.primary,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      Translations.enterBackupKey,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _backupKeyController,
                      textCapitalization: TextCapitalization.characters,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 20,
                        letterSpacing: 3,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        hintText: 'XXXXXXXX',
                        hintStyle: TextStyle(
                          color: theme.colorScheme.onSurface.withOpacity(0.3),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.key),
                        errorText: _restoreError,
                      ),
                      maxLength: 8,
                      onChanged: (_) {
                        if (_restoreError != null) {
                          setState(() => _restoreError = null);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _isRestoring ? null : _restoreFromCloud,
                        icon: _isRestoring
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.cloud_download),
                        label: Text(
                          _isRestoring
                              ? Translations.restoring
                              : Translations.restore,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Divider with "or"
            Row(
              children: [
                Expanded(child: Divider(color: theme.colorScheme.outline)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    Translations.or,
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                ),
                Expanded(child: Divider(color: theme.colorScheme.outline)),
              ],
            ),

            const SizedBox(height: 24),

            // New account info
            Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      Icons.person_add_outlined,
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            Translations.newUser,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            Translations.newUserDescription,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withOpacity(
                                0.6,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios, size: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNamePage() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              height: 80,
              width: 80,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.person_outline,
                size: 40,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              Translations.whatShouldWeCallYou,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              Translations.wellUseThisToPersonalize,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            TextField(
              controller: _nameController,
              focusNode: _nameFocusNode,
              autofocus: false,
              decoration: InputDecoration(
                hintText: Translations.yourName,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                filled: true,
                fillColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemePage() {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              height: 80,
              width: 80,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.palette_outlined,
                size: 40,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              Translations.chooseYourStyle,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),

            // Follow system theme
            Card(
              elevation: 0,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  setState(() {
                    _followSystem = !_followSystem;
                    if (_followSystem) {
                      final brightness = MediaQuery.of(
                        context,
                      ).platformBrightness;
                      final apply = (brightness == Brightness.dark)
                          ? AppTheme.darkGray
                          : AppTheme.light;
                      ThemeController.instance.setTheme(apply);
                    } else {
                      ThemeController.instance.setTheme(_selected);
                    }
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 16,
                  ),
                  child: Row(
                    children: [
                      Checkbox(
                        value: _followSystem,
                        onChanged: (v) {
                          setState(() {
                            _followSystem = v ?? true;
                            if (_followSystem) {
                              final brightness = MediaQuery.of(
                                context,
                              ).platformBrightness;
                              final apply = (brightness == Brightness.dark)
                                  ? AppTheme.darkGray
                                  : AppTheme.light;
                              ThemeController.instance.setTheme(apply);
                            } else {
                              ThemeController.instance.setTheme(_selected);
                            }
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      Text(Translations.followSystemTheme),
                    ],
                  ),
                ),
              ),
            ),

            if (!_followSystem) ...[
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  _buildThemeOption(
                    Translations.white,
                    AppTheme.light,
                    Icons.light_mode_outlined,
                  ),
                  _buildThemeOption(
                    Translations.darkGray,
                    AppTheme.darkGray,
                    Icons.dark_mode_outlined,
                  ),
                  _buildThemeOption(
                    Translations.amoled,
                    AppTheme.amoled,
                    Icons.contrast_outlined,
                  ),
                ],
              ),
            ],

            const SizedBox(height: 32),

            // Material You toggle
            Card(
              elevation: 0,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  setState(() {
                    _materialYou = !_materialYou;
                    ThemeController.instance.setMaterialYou(_materialYou);
                    if (_followSystem) {
                      final brightness = MediaQuery.of(
                        context,
                      ).platformBrightness;
                      final apply = (brightness == Brightness.dark)
                          ? AppTheme.darkGray
                          : AppTheme.light;
                      ThemeController.instance.setTheme(apply);
                    } else {
                      ThemeController.instance.setTheme(_selected);
                    }
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 16,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              Translations.materialYou,
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              Translations.dynamicColorScheme,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _materialYou,
                        onChanged: (v) {
                          setState(() {
                            _materialYou = v;
                            ThemeController.instance.setMaterialYou(
                              _materialYou,
                            );
                            if (_followSystem) {
                              final brightness = MediaQuery.of(
                                context,
                              ).platformBrightness;
                              final apply = (brightness == Brightness.dark)
                                  ? AppTheme.darkGray
                                  : AppTheme.light;
                              ThemeController.instance.setTheme(apply);
                            } else {
                              ThemeController.instance.setTheme(_selected);
                            }
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeOption(String label, AppTheme theme, IconData icon) {
    final isSelected = _selected == theme;
    final color = Theme.of(context).colorScheme;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          setState(() {
            _selected = theme;
            ThemeController.instance.setTheme(_selected);
          });
        },
        child: Container(
          width: 100,
          height: 120,
          decoration: BoxDecoration(
            color: isSelected
                ? color.primaryContainer
                : color.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? color.primary : Colors.transparent,
              width: 2,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 32,
                color: isSelected ? color.onPrimaryContainer : color.onSurface,
              ),
              const SizedBox(height: 12),
              Text(
                label,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected
                      ? color.onPrimaryContainer
                      : color.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionsPage() {
    final theme = Theme.of(context);
    final notificationsRequired = _notifications;
    final allPermissionsGranted =
        _locationPermissionGranted &&
        (!notificationsRequired || _notificationPermissionGranted);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            height: 80,
            width: 80,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.lock_outline,
              size: 40,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            Translations.enablePermissions,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            Translations.weNeedTheseToProvide,
            style: TextStyle(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),

          Card(
            elevation: 0,
            child: SwitchListTile(
              title: Text(Translations.enableNotifications),
              subtitle: Text(Translations.getRemindersAboutMedications),
              value: _notifications,
              onChanged: (v) => setState(() => _notifications = v),
            ),
          ),

          const SizedBox(height: 20),

          Card(
            elevation: 0,
            child: ListTile(
              leading: const Icon(Icons.location_on_outlined),
              title: Text(Translations.location),
              subtitle: Text(Translations.findNearbyPharmacies),
              trailing: _requestingLocationPermission
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : TextButton(
                      onPressed: _locationPermissionGranted
                          ? null
                          : _requestLocationPermission,
                      child: Text(
                        _locationPermissionGranted
                            ? Translations.granted
                            : Translations.allow,
                      ),
                    ),
            ),
          ),

          const SizedBox(height: 8),

          Card(
            elevation: 0,
            child: ListTile(
              leading: const Icon(Icons.notifications_outlined),
              title: Text(Translations.notifications),
              subtitle: Text(Translations.sendMedicationReminders),
              trailing: _requestingNotificationPermission
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : TextButton(
                      onPressed:
                          (!notificationsRequired ||
                              _notificationPermissionGranted)
                          ? null
                          : _requestNotificationPermission,
                      child: Text(
                        _notificationPermissionGranted
                            ? Translations.granted
                            : Translations.allow,
                      ),
                    ),
            ),
          ),

          if (!allPermissionsGranted) ...[
            const SizedBox(height: 20),
            Text(
              Translations.pleaseGrantAllPermissions,
              style: TextStyle(color: theme.colorScheme.error, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Page indicator
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return Container(
                    margin: const EdgeInsets.only(right: 8),
                    height: 4,
                    width: _currentPage == index ? 24 : 4,
                    decoration: BoxDecoration(
                      color: _currentPage == index
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  );
                }),
              ),
            ),

            // Page content
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  // Dismiss keyboard when page changes
                  FocusScope.of(context).unfocus();
                  SystemChannels.textInput.invokeMethod('TextInput.hide');
                  setState(() => _currentPage = index);
                },
                children: [
                  _buildWelcomePage(),
                  _buildCloudSyncPage(),
                  _buildNamePage(),
                  _buildThemePage(),
                  _buildPermissionsPage(),
                ],
              ),
            ),

            // Navigation buttons
            Padding(
              padding: const EdgeInsets.all(32),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_currentPage > 0)
                    OutlinedButton(
                      onPressed: () {
                        // Dismiss keyboard before changing pages
                        FocusScope.of(context).unfocus();
                        SystemChannels.textInput.invokeMethod('TextInput.hide');

                        _pageController.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                      child: Text(Translations.back),
                    )
                  else
                    const SizedBox.shrink(),

                  ElevatedButton(
                    onPressed:
                        (_currentPage == 4 &&
                            (!_locationPermissionGranted ||
                                (_notifications &&
                                    !_notificationPermissionGranted)))
                        ? null
                        : () {
                            // Dismiss keyboard before changing pages
                            FocusScope.of(context).unfocus();
                            SystemChannels.textInput.invokeMethod(
                              'TextInput.hide',
                            );

                            if (_currentPage < 4) {
                              _pageController.nextPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            } else {
                              _saveAndContinue(context);
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(120, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      _currentPage < 4
                          ? Translations.next
                          : Translations.getStarted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
