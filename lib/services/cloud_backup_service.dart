import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:mongo_dart/mongo_dart.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/medication_repository.dart';
import '../models/medication.dart';
import '../theme/language_controller.dart';
import '../theme/theme_controller.dart';

/// Service for backing up and restoring app data to MongoDB Atlas.
class CloudBackupService {
  CloudBackupService._();

  static final CloudBackupService instance = CloudBackupService._();

  // MongoDB Atlas connection configuration
  // Using standard format instead of SRV (mongodb+srv://) because SRV DNS
  // resolution may not work on some Android devices
  static const String _connectionString =
      'mongodb://boranbruh:YouShouldNotSeeThis38@ac-jiuf6fs-shard-00-00.bybs87l.mongodb.net:27017,ac-jiuf6fs-shard-00-01.bybs87l.mongodb.net:27017,ac-jiuf6fs-shard-00-02.bybs87l.mongodb.net:27017/dose?ssl=true&replicaSet=atlas-k02vhd-shard-0&authSource=admin&retryWrites=true&w=majority';

  static const String _collectionName = 'dose';
  static const String _kBackupKeyPref = 'cloud_backup_key';

  /// Last error message for debugging
  String? lastError;

  final MedicationRepository _repository = MedicationRepository();

  /// Generates a random 8-character alphanumeric key.
  String generateKey() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random.secure();
    return List.generate(8, (_) => chars[random.nextInt(chars.length)]).join();
  }

  /// Gets the stored backup key, if any.
  Future<String?> getStoredKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kBackupKeyPref);
  }

  /// Stores the backup key locally.
  Future<void> storeKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kBackupKeyPref, key);
  }

  /// Clears the stored backup key.
  Future<void> clearStoredKey() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kBackupKeyPref);
  }

  void _log(String message) {
    final timestamp = DateTime.now().toIso8601String();
    print('[$timestamp] CloudBackupService: $message');
  }

  /// Tests basic internet connectivity by trying to reach google.com
  Future<bool> _checkInternetConnectivity() async {
    _log('Testing internet connectivity...');
    try {
      final result = await InternetAddress.lookup(
        'google.com',
      ).timeout(const Duration(seconds: 10));
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        _log('Internet connectivity OK - resolved google.com');
        return true;
      }
      _log('Internet connectivity FAILED - no address resolved');
      return false;
    } on SocketException catch (e) {
      _log('Internet connectivity FAILED - SocketException: $e');
      lastError = 'No internet connection: $e';
      return false;
    } on TimeoutException catch (e) {
      _log('Internet connectivity FAILED - Timeout: $e');
      lastError = 'Connection timed out: $e';
      return false;
    } catch (e) {
      _log('Internet connectivity FAILED - Unknown error: $e');
      lastError = 'Connectivity check failed: $e';
      return false;
    }
  }

  /// Connects to MongoDB and returns the database instance.
  Future<Db?> _connect() async {
    _log('=== Starting MongoDB connection ===');

    // First check basic internet
    if (!await _checkInternetConnectivity()) {
      _log('Aborting: No internet connectivity');
      return null;
    }

    _log('Internet OK - attempting MongoDB connection...');

    try {
      _log('Creating MongoDB connection with standard connection string...');
      _log(
        'Connection string (masked): mongodb://boranbruh:****@elox-shard-00-XX.bybs87l.mongodb.net:27017/dose',
      );

      final stopwatch = Stopwatch()..start();
      final db = await Db.create(_connectionString);
      _log('Db.create() completed in ${stopwatch.elapsedMilliseconds}ms');

      _log('Opening database connection...');
      await db.open();
      _log('db.open() completed in ${stopwatch.elapsedMilliseconds}ms');

      _log('Checking if database is connected: ${db.isConnected}');
      _log('Database name: ${db.databaseName}');

      if (db.isConnected) {
        _log('=== Successfully connected to MongoDB ===');
        lastError = null;
        return db;
      } else {
        _log('=== Connection failed: db.isConnected is false ===');
        lastError = 'Database connection returned false';
        return null;
      }
    } on MongoDartError catch (e) {
      _log('MongoDB Error: $e');
      _log('Error type: ${e.runtimeType}');
      lastError = 'MongoDB error: $e';
      return null;
    } on SocketException catch (e) {
      _log('Socket Error: $e');
      lastError = 'Network socket error: $e';
      return null;
    } on TimeoutException catch (e) {
      _log('Timeout Error: $e');
      lastError = 'Connection timed out: $e';
      return null;
    } catch (e, stackTrace) {
      _log('Unknown Error: $e');
      _log('Error type: ${e.runtimeType}');
      _log('Stack trace: $stackTrace');
      lastError = 'Unknown error: $e';
      return null;
    }
  }

  /// Checks if a backup key exists in the cloud database.
  Future<bool> checkKeyExists(String key) async {
    final db = await _connect();
    if (db == null) return false;

    try {
      final collection = db.collection(_collectionName);
      final doc = await collection.findOne(where.eq('key', key.toUpperCase()));
      return doc != null;
    } catch (e) {
      return false;
    } finally {
      await db.close();
    }
  }

  /// Backs up medications and preferences to the cloud.
  /// Returns the backup key on success, or null on failure.
  Future<String?> backupToCloud({String? existingKey}) async {
    _log('=== Starting backup to cloud ===');
    final db = await _connect();
    if (db == null) {
      _log('BACKUP FAILED: Could not connect to database');
      _log('Last error: $lastError');
      return null;
    }

    try {
      final key = (existingKey ?? generateKey()).toUpperCase();
      _log('Using backup key: $key');

      // Load medications
      _log('Loading medications from local storage...');
      final medications = await _repository.loadMedications();
      _log('Loaded ${medications.length} medications');

      _log('Converting medications to JSON...');
      final medicationsJson = medications
          .map((m) => m.toJson())
          .toList(growable: false);
      _log('Medications JSON created successfully');

      // Export preferences
      _log('Loading preferences...');
      final prefs = await SharedPreferences.getInstance();
      final userName = prefs.getString('user_name') ?? 'user';
      _log('Username: $userName');

      final preferences = <String, dynamic>{
        'theme': ThemeController.instance.value.index,
        'materialYou': ThemeController.instance.materialYou,
        'language': LanguageController.instance.value.index,
        'userName': userName,
      };
      _log('Preferences: $preferences');

      final document = <String, dynamic>{
        'key': key,
        'medications': medicationsJson,
        'preferences': preferences,
        'updatedAt': DateTime.now().toUtc(),
      };
      _log('Document prepared for upload');

      final collection = db.collection(_collectionName);
      _log('Got collection: $_collectionName');

      // Check if key exists to decide between insert and update
      _log('Checking if key already exists in database...');
      final existingDoc = await collection.findOne(where.eq('key', key));

      if (existingDoc != null) {
        _log('Key exists - updating existing document...');
        await collection.updateOne(
          where.eq('key', key),
          modify
              .set('medications', medicationsJson)
              .set('preferences', preferences)
              .set('updatedAt', DateTime.now().toUtc()),
        );
        _log('Document updated successfully');
      } else {
        _log('Key does not exist - inserting new document...');
        await collection.insertOne(document);
        _log('Document inserted successfully');
      }

      await storeKey(key);
      _log('Key stored locally');
      _log('=== BACKUP COMPLETED SUCCESSFULLY ===');
      lastError = null;
      return key;
    } on MongoDartError catch (e) {
      _log('BACKUP FAILED: MongoDB error: $e');
      lastError = 'MongoDB error: $e';
      return null;
    } on SocketException catch (e) {
      _log('BACKUP FAILED: Socket error: $e');
      lastError = 'Network error: $e';
      return null;
    } catch (e, stackTrace) {
      _log('BACKUP FAILED: Unknown error: $e');
      _log('Error type: ${e.runtimeType}');
      _log('Stack trace: $stackTrace');
      lastError = 'Unknown error: $e';
      return null;
    } finally {
      _log('Closing database connection...');
      await db.close();
      _log('Database connection closed');
    }
  }

  /// Restores medications and preferences from the cloud using the given key.
  /// Returns true on success, false on failure.
  Future<bool> restoreFromCloud(String key) async {
    final db = await _connect();
    if (db == null) return false;

    try {
      final normalizedKey = key.toUpperCase().trim();

      final collection = db.collection(_collectionName);
      final document = await collection.findOne(where.eq('key', normalizedKey));

      if (document == null) {
        return false;
      }

      // Restore medications
      final medicationsRaw = document['medications'];
      if (medicationsRaw is List) {
        final medications = <Medication>[];
        for (final entry in medicationsRaw) {
          try {
            if (entry is Map) {
              medications.add(
                Medication.fromJson(Map<String, dynamic>.from(entry)),
              );
            }
          } catch (_) {
            // Skip invalid entries
          }
        }
        await _repository.saveMedications(medications);
      }

      // Restore preferences
      final preferences = document['preferences'];
      if (preferences is Map) {
        final prefs = await SharedPreferences.getInstance();

        // Restore theme
        final themeIndex = preferences['theme'];
        if (themeIndex is int &&
            themeIndex >= 0 &&
            themeIndex < AppTheme.values.length) {
          ThemeController.instance.setTheme(AppTheme.values[themeIndex]);
        }

        // Restore Material You
        final materialYou = preferences['materialYou'];
        if (materialYou is bool) {
          ThemeController.instance.setMaterialYou(materialYou);
        }

        // Restore language
        final languageIndex = preferences['language'];
        if (languageIndex is int &&
            languageIndex >= 0 &&
            languageIndex < AppLanguage.values.length) {
          LanguageController.instance.setLanguage(
            AppLanguage.values[languageIndex],
          );
        }

        // Restore username
        final userName = preferences['userName'];
        if (userName is String && userName.isNotEmpty) {
          await prefs.setString('user_name', userName);
        }
      }

      // Store the key locally
      await storeKey(normalizedKey);

      return true;
    } catch (e) {
      return false;
    } finally {
      await db.close();
    }
  }
}
