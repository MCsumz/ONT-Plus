import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:opennutritracker/core/data/data_source/config_data_source.dart';
import 'package:opennutritracker/core/data/data_source/custom_meal_data_source.dart';
import 'package:opennutritracker/core/data/data_source/water_intake_data_source.dart';
import 'package:opennutritracker/core/data/dbo/fasting_session_dbo.dart';
import 'package:opennutritracker/core/data/dbo/meal_dbo.dart';
import 'package:opennutritracker/core/data/dbo/water_intake_dbo.dart';
import 'package:opennutritracker/core/data/repository/user_repository.dart';
import 'package:opennutritracker/core/data/repository/weight_log_repository.dart';
import 'package:opennutritracker/core/domain/usecase/add_config_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_config_usecase.dart';
import 'package:opennutritracker/core/utils/hive_db_provider.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/core/utils/tracked_day_reconciler.dart';
import 'package:opennutritracker/features/fasting/data/data_source/fasting_data_source.dart';
import 'package:opennutritracker/features/sync/domain/sync_profile.dart';

/// What the original JSON backup leaves out, so that ONT+'s export is a
/// complete copy: the body profile and unit choices from the first-time
/// setup, the water log, fasting sessions and the custom foods library.
///
/// Each is its own optional file, so a backup from the original app (which
/// has none of them) still imports, and the original app ignores them.
class FullBackupExtras {
  static const profileFileName = SyncProfile.fileName;
  static const waterFileName = 'water_intake.json';
  static const fastingFileName = 'fasting_sessions.json';
  static const customMealsFileName = 'custom_meals.json';
  static const preferencesFileName = AppPreferencesBackup.fileName;

  const FullBackupExtras();

  Future<void> addTo(Archive archive) async {
    void addJson(String name, Object json) {
      final bytes = utf8.encode(jsonEncode(json));
      archive.addFile(ArchiveFile(name, bytes.length, bytes));
    }

    final config = await locator<GetConfigUsecase>().getConfig();
    addJson(preferencesFileName, AppPreferencesBackup.capture(config).values);
    final users = locator<UserRepository>();
    if (await users.hasUserData()) {
      addJson(
        profileFileName,
        SyncProfile(
          user: await users.getUserData(),
          usesImperialHeightUnits: config.usesImperialHeightUnits,
          bodyWeightUnit: config.bodyWeightUnit,
          usesImperialFoodUnits: config.usesImperialFoodUnits,
        ).toJson(),
      );
    }
    addJson(waterFileName, [
      for (final e in await locator<WaterIntakeDataSource>().allEntries())
        e.toJson(),
    ]);
    addJson(fastingFileName, [
      for (final s in await locator<FastingDataSource>().allSessions())
        s.toJson(),
    ]);
    addJson(customMealsFileName, [
      for (final m in locator<CustomMealDataSource>().getAllCustomMeals())
        m.toJson(),
    ]);
  }

  /// Merges the extras in [archive] into this phone: entries are added or
  /// replaced by id, nothing is removed. A backup's profile and preferences
  /// replace this phone's, except that the weight follows the newest
  /// weigh-in on file, which may be this phone's own.
  Future<void> restoreFrom(Archive archive) async {
    await restoreEntries(archive);
    await restoreProfile(archive);
    await restorePreferences(archive);
  }

  /// The water log, fasting sessions and custom foods, merged by id.
  Future<void> restoreEntries(Archive archive) async {
    final water = _list(archive, waterFileName, WaterIntakeDBO.fromJson);
    if (water.isNotEmpty) {
      await locator<WaterIntakeDataSource>().addAllEntries(water);
    }
    final fasting = _list(archive, fastingFileName, FastingSessionDBO.fromJson);
    final fastingSource = locator<FastingDataSource>();
    for (final session in fasting) {
      await fastingSource.updateSession(session);
    }
    final meals = _list(archive, customMealsFileName, MealDBO.fromJson);
    final customMeals = locator<CustomMealDataSource>();
    for (final meal in meals) {
      await customMeals.saveCustomMeal(meal);
    }
  }

  /// The body profile and its units; the weight follows the newest
  /// weigh-in on file. Returns whether the archive held a profile.
  Future<bool> restoreProfile(Archive archive) async {
    final profileFile = archive.findFile(profileFileName);
    if (profileFile == null) return false;
    final profile = SyncProfile.fromJson(
      jsonDecode(utf8.decode(profileFile.content as List<int>))
          as Map<String, dynamic>,
    );
    final weights = await locator<WeightLogRepository>().getAllEntriesDBO();
    final latest = weights.isEmpty
        ? null
        : weights.reduce((a, b) => a.date.isAfter(b.date) ? a : b);
    await locator<UserRepository>().updateUserData(
      latest == null
          ? profile.user
          : SyncProfile.withWeight(profile.user, latest.weightKg),
    );
    final config = locator<AddConfigUsecase>();
    await config.setConfigUsesImperialHeightUnits(
      profile.usesImperialHeightUnits,
    );
    await config.setConfigBodyWeightUnit(profile.bodyWeightUnit);
    await config.setConfigUsesImperialFoodUnits(profile.usesImperialFoodUnits);
    return true;
  }

  /// Theme, units, food databases, display toggles and the day boundary.
  Future<void> restorePreferences(Archive archive) async {
    final file = archive.findFile(preferencesFileName);
    if (file == null) return;
    final json = jsonDecode(utf8.decode(file.content as List<int>));
    if (json is! Map<String, dynamic>) return;
    final preferences = AppPreferencesBackup(json);
    await preferences.applyTo(locator<AddConfigUsecase>());
    final offset = preferences.dayStartOffset;
    if (offset == null) return;
    final current = await locator<GetConfigUsecase>().getConfig();
    if (current.dayStartOffsetHours == offset.$1 &&
        current.dayStartOffsetMinutes == offset.$2) {
      return;
    }
    // Regroups the diary's rows under the new boundary, as Settings does.
    await moveDayBoundary(
      locator<HiveDBProvider>(),
      locator<ConfigDataSource>(),
      offset.$1,
      offset.$2,
    );
  }

  /// Removes a fasting session by id; the data source has no delete.
  static Future<void> deleteFastingSession(String id) =>
      locator<HiveDBProvider>().fastingBox.delete(id);

  static List<T> _list<T>(
    Archive archive,
    String name,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final file = archive.findFile(name);
    if (file == null) return [];
    return [
      for (final raw
          in jsonDecode(utf8.decode(file.content as List<int>)) as List)
        fromJson((raw as Map).cast<String, dynamic>()),
    ];
  }
}
