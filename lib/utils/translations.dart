import '../theme/language_controller.dart';
import 'build_info.dart';

class Translations {
  // App Title
  static String get appTitle => _getText('Dosemite', 'Dosemite');

  // Welcome Screen
  static String get welcomeTitle =>
      _getText('Welcome to DoseMite', 'DoseMite\'a Hoş Geldiniz');

  static String get welcomeSubtitle => _getText('', '');

  // Language
  static String get language => _getText('Language', 'Dil');

  static String get english => _getText('English', 'İngilizce');

  static String get turkish => _getText('Türkçe', 'Türkçe');

  // Name Page
  static String get whatShouldWeCallYou =>
      _getText('What\'s your name?', 'Adınız ne?');

  static String get wellUseThisToPersonalize => _getText(
    'We\'ll use this to personalize your experience',
    'Deneyiminizi kişiselleştirmek için kullanacağız',
  );

  static String get yourName => _getText('Your name', 'Adınız');

  static String get enterYourName =>
      _getText('Enter your name', 'Adınızı girin');

  // Theme Page
  static String get chooseYourStyle =>
      _getText('Choose your style', 'Stilinizi seçin');

  static String get followSystemTheme =>
      _getText('Follow system theme', 'Sistem temasını takip et');

  static String get materialYou => _getText('Material You', 'Material You');

  static String get dynamicColorScheme =>
      _getText('Dynamic color scheme', 'Dinamik renk şeması');

  static String get useDynamicSeedBasedMaterial3 => _getText(
    'Use dynamic seed-based Material 3 color scheme',
    'Dinamik tohum tabanlı Material 3 renk şemasını kullan',
  );

  // Theme Options
  static String get whiteLight => _getText('White (Light)', 'Beyaz (Açık)');

  static String get grayBlack => _getText('Gray / Black', 'Gri / Siyah');

  static String get pitchAmoledBlack =>
      _getText('Pitch / AMOLED Black', 'Parlak / AMOLED Siyah');

  static String get selectedMode => _getText('Selected mode', 'Seçili mod');

  static String get darkGray => _getText('Dark Gray', 'Koyu Gri');

  static String get amoled => _getText('AMOLED', 'AMOLED');

  static String get white => _getText('White', 'Beyaz');

  // Permissions Page
  static String get enablePermissions =>
      _getText('Enable permissions', 'İzinleri ver');

  static String get weNeedTheseToProvide => _getText(
    'We need these to provide the best experience',
    'En iyi deneyimi sunmak için bunlara ihtiyacımız var',
  );

  static String get enableNotifications =>
      _getText('Enable notifications', 'Bildirimleri etkinleştir');

  static String get getRemindersAboutMedications => _getText(
    'Get reminders about your medications',
    'İlaçlarınız hakkında bildirim alın',
  );

  static String get location => _getText('Location', 'Konum');

  static String get findNearbyPharmacies =>
      _getText('Find nearby pharmacies', 'Yakındaki eczaneleri bul');

  static String get notifications => _getText('Notifications', 'Bildirimler');

  static String get sendMedicationReminders =>
      _getText('Send medication reminders', 'İlaç bildirimleri gönder');

  static String reminderTitle(String medicationName) => _getText(
    'Time to take $medicationName!!',
    '$medicationName alma zamanı!!!',
  );

  static String reminderBody(String dose) =>
      _getText('Dose: $dose', 'Doz: $dose');

  static String get granted => _getText('OK', 'OK');

  static String get allow => _getText('Allow', 'İzin Ver');

  static String get pleaseGrantAllPermissions => _getText(
    'All permissions are needed for the app to work',
    'Devam etmek için lütfen tüm izinleri verin',
  );

  static String get permissionDeniedOpenSettings => _getText(
    'Permission denied. Please enable it in settings.',
    'İzin reddedildi. Lütfen ayarlardan etkinleştirin.',
  );

  static String get openSettings => _getText('Open Settings', 'Ayarları Aç');

  // Navigation
  static String get back => _getText('Back', 'Geri');

  static String get next => _getText('Next', 'İleri');

  static String get getStarted => _getText('Get Started', 'Başla');

  // Dashboard
  static String get goodMorning => _getText('Good morning', 'Günaydın');

  static String get goodAfternoon => _getText('Good afternoon', 'İyi Günler');

  static String get goodEvening => _getText('Good evening', 'İyi Akşamlar');

  static String nextMedicationIn(String time) =>
      _getText('Next medication in $time', 'Sonraki ilaç $time içinde');

  static String get noUpcomingMedications =>
      _getText('No upcoming medications', 'Yaklaşan ilaç yok');

  static String get lessThanOneMinute =>
      _getText('less than a minute', 'bir dakikadan az');

  static String durationDays(int days) =>
      _getText(days == 1 ? '1 day' : '$days days', '$days gün');

  static String durationHours(int hours) =>
      _getText(hours == 1 ? '1 hour' : '$hours hours', '$hours saat');

  static String durationMinutes(int minutes) => _getText(
    minutes == 1 ? '1 minute' : '$minutes minutes',
    '$minutes dakika',
  );

  static String get searchMedications => _getText('Search', 'Ara');

  static String get todaysSchedule =>
      _getText('Today\'s Schedule', 'Bugünkü Program');

  static String get morning => _getText('Morning', 'Sabah');

  static String get afternoon => _getText('Afternoon', 'Öğlen');

  static String get evening => _getText('Evening', 'Akşam');

  static String get dashboard => _getText('Dashboard', 'Kontrol Paneli');

  static String get map => _getText('Map', 'Harita');

  static String get addDrug => _getText('Add', 'İlaç Ekle');

  static String get medicationName => _getText('Medication name', 'İlaç adı');

  static String get medicationDose => _getText('Dose', 'Doz');

  static String get usageTime => _getText('When to use?', 'Kullanım zamanı');

  static String get selectTime => _getText('Select time', 'Zaman seç');

  static String get courseEndDate =>
      _getText('Course end date', 'Tedavinin biteceği tarih');

  static String get selectCourseEndDate =>
      _getText('Select end date', 'Bitiş tarihi seç');

  static String get stockOnHand =>
      _getText('Pills on hand', 'Elinizdeki hap sayısı');

  static String get enterPositiveAmount =>
      _getText('Enter a positive number', 'Pozitif bir sayı girin');

  static String get courseEndRequired => _getText(
    'Please select when the course should end.',
    'Lütfen tedavinin ne zaman biteceğini seçin.',
  );

  static String get quantityRequired => _getText(
    'Please enter in how many pills you have left.',
    'Kaç hap kaldığını belirtmelisiniz.',
  );

  static String get medicationNotesOptional =>
      _getText('Notes (optional)', 'Notlar (isterseniz)');

  static String get medicationFormIncomplete => _getText(
    'Please fill in the required fields.',
    'Gerekli alanları doldurmanız lazım!',
  );

  static String get medicationAdded => _getText('Added!', 'Eklendi!');

  static String get editMedication =>
      _getText('Edit Medication', 'İlacı Düzenle');

  static String get medicationUpdated =>
      _getText('Medication updated!', 'İlaç güncellendi!');

  static String get deleteMedication =>
      _getText('Delete Medication', 'İlacı Sil');

  static String get deleteMedicationConfirm => _getText(
    'Are you sure you want to delete this medication?',
    'Bu ilacı silmek istediğinizden emin misiniz?',
  );

  static String get medicationDeleted =>
      _getText('Medication deleted', 'İlaç silindi');

  static String get delete => _getText('Delete', 'Sil');

  static String get update => _getText('Update', 'Güncelle');

  static String get unableToSaveMedication =>
      _getText('Unable to save medication.', 'İlaç kaydedilemedi.');

  static String get unableToLoadMedications =>
      _getText('Unable to load medications.', 'İlaçlar yüklenemedi.');

  static String get noMedicationsAdded =>
      _getText('No medications added.', 'Hiç ilaç eklenmedi.');

  static String get markMedicationTaken =>
      _getText('Mark as taken', 'Alındı olarak işaretle');

  static String get medicationMarkedAsTaken =>
      _getText('Medication marked as taken', 'İlaç alındı olarak işaretlendi');

  static String remainingDoses(int remaining) => _getText(
    remaining == 1 ? '1 dose remaining' : '$remaining doses remaining',
    remaining == 1 ? '1 doz kaldı' : '$remaining doz kaldı',
  );

  static String get courseCompleted =>
      _getText('Course completed', 'Tedavi tamamlandı');

  static String courseEndsOn(String date) =>
      _getText('Ends on $date', '$date tarihinde biter');

  static String lowStockMessage(String name, int remaining) => _getText(
    '$name is running low. Only $remaining left.',
    '$name için stok azalıyor. Sadece $remaining kaldı.',
  );

  static String get pleaseRestockSoon =>
      _getText('Please restock soon.', 'Lütfen yakında stoklayın.');

  static String get lowStockWarning =>
      _getText('Low stock alert', 'Düşük stok uyarısı');

  static String get noHistoryYet =>
      _getText('No medication history yet.', 'Henüz ilaç geçmişi yok.');

  static String get tapMedicationForHistory => _getText(
    'Tap a medication to see its intake history.',
    'Alım geçmişini görmek için bir ilaca dokunun.',
  );

  static String get noDosesLogged =>
      _getText('No doses logged yet.', 'Henüz doz kaydı yok.');

  // Backup & Transfer
  static String get backupAndTransfer =>
      _getText('Backup & Transfer', 'Yedekleme ve Aktarım');

  static String get backupViaQr =>
      _getText('Show backup QR code', 'Yedekleme QR kodu göster');

  static String get backupViaQrSubtitle => _getText(
    'Scan this code on another device to copy your data.',
    'Verilerinizi kopyalamak için başka bir cihazda tarayın.',
  );

  static String get restoreFromQr =>
      _getText('Restore from QR code', 'QR kodundan geri yükle');

  static String get restoreFromQrSubtitle => _getText(
    'Scan a code exported from Dosemite to import data.',
    'Dosemite üzerinden alınmış kodu tarayarak verileri içe aktarın.',
  );

  static String get backupFailed => _getText(
    'Unable to create backup QR code.',
    'Yedekleme QR kodu oluşturulamadı.',
  );

  static String get importFailed => _getText(
    'Could not import data from the QR code.',
    'QR kodundan veri içe aktarılamadı.',
  );

  static String get importSuccess =>
      _getText('Medication list restored!', 'İlaç listesi geri yüklendi!');

  static String get scanningQrInstructions => _getText(
    'Align the QR code within the frame to scan.',
    'Taramak için QR kodunu çerçeve içine hizalayın.',
  );

  // Cloud Backup
  static String get cloudBackup => _getText('Cloud Backup', 'Bulut Yedekleme');

  static String get cloudBackupSubtitle => _getText(
    'Sync your data across devices with a unique doseKey',
    'Benzersiz bir doseKey ile verilerinizi cihazlar arası senkronize edin',
  );

  static String get backupToCloud =>
      _getText('Backup to Cloud', 'Buluta Yedekle');

  static String get restoreFromCloud =>
      _getText('Restore from Cloud', 'Buluttan Geri Yükle');

  static String get yourBackupKey => _getText('Your doseKey', 'DoseKeyiniz');

  static String get enterBackupKey =>
      _getText('Enter your doseKey', 'DoseKeyinizi girin');

  static String get generateNewKey =>
      _getText('Generate New doseKey', 'Yeni doseKey Oluştur');

  static String get useExistingKey =>
      _getText('Use Existing doseKey', 'Mevcut doseKeyi Kullan');

  static String get backupSuccess => _getText(
    'Backup completed successfully!',
    'Yedekleme başarıyla tamamlandı!',
  );

  static String get restoreSuccess => _getText(
    'Data restored successfully!',
    'Veriler başarıyla geri yüklendi!',
  );

  static String get invalidKey => _getText(
    'Invalid doseKey. Please check and try again.',
    'Geçersiz doseKey. Kontrol edip tekrar deneyin.',
  );

  static String get cloudBackupFailed => _getText(
    'Cloud backup failed. Please try again.',
    'Bulut yedekleme başarısız. Lütfen tekrar deneyin.',
  );

  static String get cloudRestoreFailed => _getText(
    'Cloud restore failed. Please check your key.',
    'Buluttan geri yükleme başarısız. Anahtarınızı kontrol edin.',
  );

  static String get copyKey => _getText('Copy doseKey', 'DoseKeyi Kopyala');

  static String get keyCopied =>
      _getText('Key copied to clipboard', 'DoseKey panoya kopyalandı');

  static String get backupKeyInfo => _getText(
    'Save this doseKey! You can use it to restore your data on any device.',
    'Bu doseKeyi kaydedin! Herhangi bir cihazda verilerinizi geri yüklemek için kullanabilirsiniz.',
  );

  static String get backingUp => _getText('Backing up...', 'Yedekleniyor...');

  static String get restoring => _getText('Restoring...', 'Geri yükleniyor...');

  static String get restore => _getText('Restore', 'Geri Yükle');

  static String get backup => _getText('Backup', 'Yedekle');

  static String get cloudSyncDescription => _getText(
    'Already have an account? Enter your doseKey to restore your data. Or continue to create a new account.',
    'Zaten bir hesabınız var mı? Verilerinizi geri yüklemek için doseKeyinizi girin. Ya da yeni hesap oluşturmak için devam edin.',
  );

  static String get or => _getText('or', 'veya');

  static String get newUser => _getText('New User', 'Yeni Kullanıcı');

  static String get newUserDescription => _getText(
    "Continue to set up a new account. You'll get a doseKey after completing the setup.",
    'Yeni bir hesap oluşturmak için devam edin. Kurulumu tamamladıktan sonra bir doseKey alacaksınız.',
  );

  static String get skip => _getText('Skip', 'Atla');

  // Settings
  static String get settings => _getText('Settings', 'Ayarlar');

  static String get account => _getText('Account', 'Hesap');

  static String get username => _getText('Username', 'Kullanıcı Adı');

  static String get changeUsername =>
      _getText('Change Username', 'Kullanıcı Adını Değiştir');

  static String get cancel => _getText('Cancel', 'İptal');

  static String get save => _getText('Save', 'Kaydet');

  static String get usernameUpdated =>
      _getText('Username updated', 'Kullanıcı adı güncellendi');

  static String get appearance => _getText('Appearance', 'Görünüm');

  static String get about => _getText('About', 'Hakkında');

  static String get aboutDoseMite =>
      _getText('About doseMite', 'doseMite Hakkında');

  static String get version =>
      _getText('Version ${BuildInfo.version}', 'Sürüm ${BuildInfo.version}');

  static String get sourceCode => _getText('Source', 'Kaynak');

  static String get viewOnGitHub =>
      _getText('doseMite is open-source!', 'doseMite açık kaynaklı!');

  static String get couldNotOpenGitHubPage =>
      _getText('Could not open GitHub page', 'GitHub sayfası açılamadı');

  // History
  static String get history => _getText('History', 'Geçmiş');

  static String get taken => _getText('Taken', 'Alındı');

  // Drugstore Map
  static String get nearbyPharmacies =>
      _getText('Nearby Pharmacies', 'Yakındaki Eczaneler');

  static String get openUntil => _getText('Open until', 'Kapanış:');

  static String get km => _getText('km', 'km');

  static String _getText(String english, String turkish) {
    final isTurkish = LanguageController.instance.value == AppLanguage.turkish;
    return isTurkish ? turkish : english;
  }
}
