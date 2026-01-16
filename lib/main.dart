import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import 'providers/medication_provider.dart';
import 'screens/intro.dart';
import 'screens/dashboard.dart';
import 'theme/theme_controller.dart';
import 'theme/language_controller.dart';
import 'utils/translations.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load theme and language settings
  await Future.wait([
    ThemeController.instance.loadFromPrefs(),
    LanguageController.instance.loadFromPrefs(),
    NotificationService.instance.initialize(),
  ]);

  // Check and set system theme
  final brightness = WidgetsBinding.instance.window.platformBrightness;
  if (ThemeController.instance.value == AppTheme.light &&
      brightness == Brightness.dark) {
    ThemeController.instance.setTheme(AppTheme.darkGray);
  }

  final seen = await ThemeController.hasSeenIntro();
  runApp(
    MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => MedicationProvider())],
      child: PharmacyApp(showIntro: !seen),
    ),
  );
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
    final customColor = ThemeController.instance.customSeedColor;
    final customFont = ThemeController.instance.customFontFamily;
    final fontSize = ThemeController.instance.customFontSize;

    // Helper to apply custom text theme
    TextTheme _applyCustomTextTheme(TextTheme base) {
      if (customFont == null && fontSize == 1.0) return base;

      TextTheme themed = base;
      if (customFont != null) {
        themed = GoogleFonts.getTextTheme(customFont, base);
      }
      if (fontSize != 1.0) {
        // Manually scale font sizes
        themed = themed.copyWith(
          displayLarge: themed.displayLarge?.copyWith(
            fontSize: (themed.displayLarge?.fontSize ?? 57) * fontSize,
          ),
          displayMedium: themed.displayMedium?.copyWith(
            fontSize: (themed.displayMedium?.fontSize ?? 45) * fontSize,
          ),
          displaySmall: themed.displaySmall?.copyWith(
            fontSize: (themed.displaySmall?.fontSize ?? 36) * fontSize,
          ),
          headlineLarge: themed.headlineLarge?.copyWith(
            fontSize: (themed.headlineLarge?.fontSize ?? 32) * fontSize,
          ),
          headlineMedium: themed.headlineMedium?.copyWith(
            fontSize: (themed.headlineMedium?.fontSize ?? 28) * fontSize,
          ),
          headlineSmall: themed.headlineSmall?.copyWith(
            fontSize: (themed.headlineSmall?.fontSize ?? 24) * fontSize,
          ),
          titleLarge: themed.titleLarge?.copyWith(
            fontSize: (themed.titleLarge?.fontSize ?? 22) * fontSize,
          ),
          titleMedium: themed.titleMedium?.copyWith(
            fontSize: (themed.titleMedium?.fontSize ?? 16) * fontSize,
          ),
          titleSmall: themed.titleSmall?.copyWith(
            fontSize: (themed.titleSmall?.fontSize ?? 14) * fontSize,
          ),
          bodyLarge: themed.bodyLarge?.copyWith(
            fontSize: (themed.bodyLarge?.fontSize ?? 16) * fontSize,
          ),
          bodyMedium: themed.bodyMedium?.copyWith(
            fontSize: (themed.bodyMedium?.fontSize ?? 14) * fontSize,
          ),
          bodySmall: themed.bodySmall?.copyWith(
            fontSize: (themed.bodySmall?.fontSize ?? 12) * fontSize,
          ),
          labelLarge: themed.labelLarge?.copyWith(
            fontSize: (themed.labelLarge?.fontSize ?? 14) * fontSize,
          ),
          labelMedium: themed.labelMedium?.copyWith(
            fontSize: (themed.labelMedium?.fontSize ?? 12) * fontSize,
          ),
          labelSmall: themed.labelSmall?.copyWith(
            fontSize: (themed.labelSmall?.fontSize ?? 11) * fontSize,
          ),
        );
      }
      return themed;
    }

    // Determine effective seed color
    final effectiveSeedColor =
        customColor ??
        (materialYou
            ? Colors.deepPurple
            : (t == AppTheme.light ? Colors.blue : Colors.blueGrey));

    // Use dynamic color if available and Material You is enabled
    if (materialYou && dynamicColorScheme != null && customColor == null) {
      final fixedColorScheme = brightness == Brightness.dark
          ? dynamicColorScheme.copyWith(
              onSurface: Colors.white,
              onSurfaceVariant: Colors.white.withOpacity(0.8),
              onBackground: Colors.white,
              onPrimary: Colors.white,
              onSecondary: Colors.white,
              onTertiary: Colors.white,
              onPrimaryContainer: Colors.white,
              onSecondaryContainer: Colors.white,
              onTertiaryContainer: Colors.white,
              onErrorContainer: Colors.white,
            )
          : dynamicColorScheme;

      final base = ThemeData(
        colorScheme: fixedColorScheme,
        useMaterial3: true,
        textTheme: _applyCustomTextTheme(
          brightness == Brightness.dark
              ? ThemeData.dark().textTheme.apply(
                  displayColor: Colors.white,
                  bodyColor: Colors.white,
                )
              : ThemeData.light().textTheme,
        ),
        snackBarTheme: const SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          insetPadding: EdgeInsets.only(
            bottom: 100, // Above FAB + bottom nav
            left: 16,
            right: 16,
          ),
        ),
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

    // Use custom or fallback colors
    final baseTheme = ThemeData.from(
      colorScheme: ColorScheme.fromSeed(
        seedColor: effectiveSeedColor,
        brightness: brightness,
      ),
      useMaterial3: true,
    );

    final customizedTheme = baseTheme.copyWith(
      textTheme: _applyCustomTextTheme(baseTheme.textTheme),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        insetPadding: EdgeInsets.only(
          bottom: 100, // Above FAB + bottom nav
          left: 16,
          right: 16,
        ),
      ),
    );

    if (t == AppTheme.amoled) {
      return customizedTheme.copyWith(
        scaffoldBackgroundColor: Colors.black,
        canvasColor: Colors.black,
        cardColor: Colors.grey[900],
      );
    }

    if (t == AppTheme.darkGray) {
      return customizedTheme.copyWith(
        scaffoldBackgroundColor: Colors.grey[900],
      );
    }

    return customizedTheme;
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
                      : ThemeMode.dark,
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
