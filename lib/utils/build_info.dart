/// Build information for the app
/// This file contains version and build date information
/// that can be viewed in the debug menu.
class BuildInfo {
  BuildInfo._();

  /// Current app version
  static const String version = '0.1-alpha';

  /// Build date in ISO 8601 format
  /// Update this date when creating a new build
  static const String buildDate = '2025-12-11';

  /// Version history with build dates
  /// Add new entries when updating the version
  static const List<Map<String, String>> versionHistory = [
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
