/// Build information for the app
/// This file contains version and build date information
/// that can be viewed in the debug menu.
class BuildInfo {
  BuildInfo._();

  /// Current app version
  static const String version = '0.2.0-beta';

  /// Build date in ISO 8601 format with time to the second
  /// Update this date when creating a new build
  static const String buildDate = '2026-01-16T19:35:00';

  /// Version history with build dates
  /// Add new entries when updating the version
  static const List<Map<String, String>> versionHistory = [
    {
      'version': '0.2.0-beta',
      'buildDate': '2026-01-16T19:35:00',
      'notes': 'Refactored code, added Provider, and updated translations.',
    },
    {
      'version': '0.1.1-alpha',
      'buildDate': '2025-12-13T19:00:49',
      'notes': 'Added taking a medicine multiple times a day',
    },
    {
      'version': '0.1-alpha',
      'buildDate': '2025-12-11',
      'notes': 'Initial alpha release with build info tracking',
    },
  ];

  /// Get formatted version string with build date
  static String get fullVersionString => '$version (Build: $buildDate)';

  /// Get the version string for display (e.g., "Version 0.1-alpha")
  static String get versionDisplay => 'Version $version';
}
