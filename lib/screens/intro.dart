import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  AppLanguage _selectedLanguage = LanguageController.instance.value;

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
  }

  @override
  void dispose() {
    LanguageController.instance.removeListener(_onLanguageChanged);
    _pageController.dispose();
    _nameController.dispose();
    _nameFocusNode.dispose();
    super.dispose();
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
      applyTheme = (brightness == Brightness.dark) ? AppTheme.darkGray : AppTheme.light;
      // Sistem temasını kaydet
      ThemeController.instance.setTheme(applyTheme);
    }

    ThemeController.instance.setTheme(applyTheme);
    ThemeController.instance.setMaterialYou(_materialYou);

    // Persist some simple prefs (name, notifications, and language)
    // Use "user" as default name if empty
    final userName = _nameController.text.trim();
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('user_name', userName.isEmpty ? 'user' : userName);
      prefs.setBool('notifications_enabled', _notifications);
    });
    
    // Save language preference
    LanguageController.instance.setLanguage(_selectedLanguage);

    // mark intro seen (async, don't await to avoid context-after-async)
    ThemeController.setSeenIntro();

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
              child: Icon(Icons.local_pharmacy_outlined, size: 60, color: theme.colorScheme.primary),
            ),
            const SizedBox(height: 32),
            Text(
              Translations.welcomeTitle,
              style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
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
                              onTap: () => Navigator.pop(context, AppLanguage.english),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                child: Row(
                                  children: [
                                    if (_selectedLanguage == AppLanguage.english)
                                      const Icon(Icons.check, size: 24),
                                    const SizedBox(width: 24),
                                    Text(Translations.english, style: const TextStyle(fontSize: 16)),
                                  ],
                                ),
                              ),
                            ),
                            const Divider(height: 1),
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => Navigator.pop(context, AppLanguage.turkish),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                child: Row(
                                  children: [
                                    if (_selectedLanguage == AppLanguage.turkish)
                                      const Icon(Icons.check, size: 24),
                                    const SizedBox(width: 24),
                                    Text(Translations.turkish, style: const TextStyle(fontSize: 16)),
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
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  child: Row(
                    children: [
                      const Icon(Icons.language_outlined),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(Translations.language, style: Theme.of(context).textTheme.bodyLarge),
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
              child: Icon(Icons.person_outline, size: 40, color: Theme.of(context).colorScheme.primary),
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
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
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
              child: Icon(Icons.palette_outlined, size: 40, color: theme.colorScheme.primary),
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
                      final brightness = MediaQuery.of(context).platformBrightness;
                      final apply = (brightness == Brightness.dark) ? AppTheme.darkGray : AppTheme.light;
                      ThemeController.instance.setTheme(apply);
                    } else {
                      ThemeController.instance.setTheme(_selected);
                    }
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  child: Row(
                    children: [
                      Checkbox(
                        value: _followSystem,
                        onChanged: (v) {
                          setState(() {
                            _followSystem = v ?? true;
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
                _buildThemeOption(Translations.white, AppTheme.light, Icons.light_mode_outlined),
                _buildThemeOption(Translations.darkGray, AppTheme.darkGray, Icons.dark_mode_outlined),
                _buildThemeOption(Translations.amoled, AppTheme.amoled, Icons.contrast_outlined),
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
                      final brightness = MediaQuery.of(context).platformBrightness;
                      final apply = (brightness == Brightness.dark) ? AppTheme.darkGray : AppTheme.light;
                      ThemeController.instance.setTheme(apply);
                    } else {
                      ThemeController.instance.setTheme(_selected);
                    }
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(Translations.materialYou, style: Theme.of(context).textTheme.bodyLarge),
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
                            ThemeController.instance.setMaterialYou(_materialYou);
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
            color: isSelected ? color.primaryContainer : color.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? color.primary : Colors.transparent,
              width: 2,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 32, color: isSelected ? color.onPrimaryContainer : color.onSurface),
              const SizedBox(height: 12),
              Text(
                label,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? color.onPrimaryContainer : color.onSurface,
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
    final allPermissionsGranted = _locationPermissionGranted && _notificationPermissionGranted;
    
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
            child: Icon(Icons.lock_outline, size: 40, color: theme.colorScheme.primary),
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
              trailing: TextButton(
                child: Text(_locationPermissionGranted ? Translations.granted : Translations.allow),
                onPressed: () {
                  setState(() => _locationPermissionGranted = true);
                },
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
              trailing: TextButton(
                child: Text(_notificationPermissionGranted ? Translations.granted : Translations.allow),
                onPressed: () {
                  setState(() => _notificationPermissionGranted = true);
                },
              ),
            ),
          ),
          
          if (!allPermissionsGranted) ...[
            const SizedBox(height: 20),
            Text(
              Translations.pleaseGrantAllPermissions,
              style: TextStyle(
                color: theme.colorScheme.error,
                fontSize: 12,
              ),
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
                children: List.generate(4, (index) {
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
                    onPressed: (_currentPage == 3 && (!_locationPermissionGranted || !_notificationPermissionGranted))
                        ? null
                        : () {
                            // Dismiss keyboard before changing pages
                            FocusScope.of(context).unfocus();
                            SystemChannels.textInput.invokeMethod('TextInput.hide');
                            
                            if (_currentPage < 3) {
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
                    child: Text(_currentPage < 3 ? Translations.next : Translations.getStarted),
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
