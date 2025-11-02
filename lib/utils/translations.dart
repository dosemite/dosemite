import '../theme/language_controller.dart';

class Translations {
  // App Title
  static String get appTitle => _getText(
    'Pharmacy App',
    'Eczane Uygulaması',
  );

  // Welcome Screen
  static String get welcomeTitle => _getText(
    'Welcome to DoseMite',
    'DoseMite\'e Hoş Geldiniz',
  );

  static String get welcomeSubtitle => _getText(
    'Your personal medication companion',
    'Kişisel ilaç asistanınız',
  );

  // Language
  static String get language => _getText(
    'Language',
    'Dil',
  );

  static String get english => _getText(
    'English',
    'İngilizce',
  );

  static String get turkish => _getText(
    'Türkçe',
    'Türkçe',
  );

  // Name Page
  static String get whatShouldWeCallYou => _getText(
    'What should we call you?',
    'Size nasıl hitap edelim?',
  );

  static String get wellUseThisToPersonalize => _getText(
    'We\'ll use this to personalize your experience',
    'Deneyiminizi kişiselleştirmek için kullanacağız',
  );

  static String get yourName => _getText(
    'Your name',
    'Adınız',
  );

  static String get enterYourName => _getText(
    'Enter your name',
    'Adınızı girin',
  );

  // Theme Page
  static String get chooseYourStyle => _getText(
    'Choose your style',
    'Stilinizi seçin',
  );

  static String get followSystemTheme => _getText(
    'Follow system theme',
    'Sistem temasını takip et',
  );

  static String get materialYou => _getText(
    'Material You',
    'Material You',
  );

  static String get dynamicColorScheme => _getText(
    'Dynamic color scheme',
    'Dinamik renk şeması',
  );

  static String get useDynamicSeedBasedMaterial3 => _getText(
    'Use dynamic seed-based Material 3 color scheme',
    'Dinamik tohum tabanlı Material 3 renk şemasını kullan',
  );

  // Theme Options
  static String get whiteLight => _getText(
    'White (Light)',
    'Beyaz (Açık)',
  );

  static String get grayBlack => _getText(
    'Gray / Black',
    'Gri / Siyah',
  );

  static String get pitchAmoledBlack => _getText(
    'Pitch / AMOLED Black',
    'Parlak / AMOLED Siyah',
  );

  static String get selectedMode => _getText(
    'Selected mode',
    'Seçili mod',
  );

  static String get darkGray => _getText(
    'Dark Gray',
    'Koyu Gri',
  );

  static String get amoled => _getText(
    'AMOLED',
    'AMOLED',
  );

  static String get white => _getText(
    'White',
    'Beyaz',
  );

  // Permissions Page
  static String get enablePermissions => _getText(
    'Enable permissions',
    'İzinleri etkinleştir',
  );

  static String get weNeedTheseToProvide => _getText(
    'We need these to provide the best experience',
    'En iyi deneyimi sunmak için bunlara ihtiyacımız var',
  );

  static String get enableNotifications => _getText(
    'Enable notifications',
    'Bildirimleri etkinleştir',
  );

  static String get getRemindersAboutMedications => _getText(
    'Get reminders about your medications',
    'İlaçlarınız hakkında hatırlatıcılar alın',
  );

  static String get location => _getText(
    'Location',
    'Konum',
  );

  static String get findNearbyPharmacies => _getText(
    'Find nearby pharmacies',
    'Yakındaki eczaneleri bul',
  );

  static String get notifications => _getText(
    'Notifications',
    'Bildirimler',
  );

  static String get sendMedicationReminders => _getText(
    'Send medication reminders',
    'İlaç hatırlatıcıları gönder',
  );

  static String get granted => _getText(
    'Granted',
    'Verildi',
  );

  static String get allow => _getText(
    'Allow',
    'İzin Ver',
  );

  static String get pleaseGrantAllPermissions => _getText(
    'Please grant all permissions to continue',
    'Devam etmek için lütfen tüm izinleri verin',
  );

  // Navigation
  static String get back => _getText(
    'Back',
    'Geri',
  );

  static String get next => _getText(
    'Next',
    'İleri',
  );

  static String get getStarted => _getText(
    'Get Started',
    'Başla',
  );

  // Dashboard
  static String get goodMorning => _getText(
    'Good Morning',
    'Günaydın',
  );

  static String get goodAfternoon => _getText(
    'Good Afternoon',
    'İyi Günler',
  );

  static String get goodEvening => _getText(
    'Good Evening',
    'İyi Akşamlar',
  );

  static String get searchMedications => _getText(
    'Search medications...',
    'İlaç ara...',
  );

  static String get todaysSchedule => _getText(
    'Today\'s Schedule',
    'Bugünkü Program',
  );

  static String get morning => _getText(
    'Morning',
    'Sabah',
  );

  static String get afternoon => _getText(
    'Afternoon',
    'Öğleden Sonra',
  );

  static String get dashboard => _getText(
    'Dashboard',
    'Kontrol Paneli',
  );

  static String get map => _getText(
    'Map',
    'Harita',
  );

  static String get addDrug => _getText(
    'Add Drug',
    'İlaç Ekle',
  );

  // Settings
  static String get settings => _getText(
    'Settings',
    'Ayarlar',
  );

  static String get account => _getText(
    'Account',
    'Hesap',
  );

  static String get username => _getText(
    'Username',
    'Kullanıcı Adı',
  );

  static String get changeUsername => _getText(
    'Change Username',
    'Kullanıcı Adını Değiştir',
  );

  static String get cancel => _getText(
    'Cancel',
    'İptal',
  );

  static String get save => _getText(
    'Save',
    'Kaydet',
  );

  static String get usernameUpdated => _getText(
    'Username updated',
    'Kullanıcı adı güncellendi',
  );

  static String get appearance => _getText(
    'Appearance',
    'Görünüm',
  );

  static String get about => _getText(
    'About',
    'Hakkında',
  );

  static String get aboutDoseMite => _getText(
    'About DoseMite',
    'DoseMite Hakkında',
  );

  static String get version => _getText(
    'Version 1.0.0',
    'Sürüm 1.0.0',
  );

  static String get sourceCode => _getText(
    'Source Code',
    'Kaynak Kodu',
  );

  static String get viewOnGitHub => _getText(
    'View on GitHub',
    'GitHub\'da Görüntüle',
  );

  static String get couldNotOpenGitHubPage => _getText(
    'Could not open GitHub page',
    'GitHub sayfası açılamadı',
  );

  // History
  static String get history => _getText(
    'History',
    'Geçmiş',
  );

  static String get taken => _getText(
    'Taken',
    'Alındı',
  );

  // Drugstore Map
  static String get nearbyPharmacies => _getText(
    'Nearby Pharmacies',
    'Yakındaki Eczaneler',
  );

  static String get openUntil => _getText(
    'Open until',
    'Kapanış:',
  );

  static String get km => _getText(
    'km',
    'km',
  );

  static String _getText(String english, String turkish) {
    final isTurkish = LanguageController.instance.value == AppLanguage.turkish;
    return isTurkish ? turkish : english;
  }
}
