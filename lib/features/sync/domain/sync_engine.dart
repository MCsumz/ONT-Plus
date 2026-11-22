import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:opennutritracker/features/settings/domain/full_backup_extras.dart';
import 'package:opennutritracker/features/fasting/data/data_source/fasting_data_source.dart';
import 'package:opennutritracker/core/data/dbo/water_intake_dbo.dart';
import 'package:opennutritracker/core/data/dbo/meal_dbo.dart';
import 'package:opennutritracker/core/data/dbo/fasting_session_dbo.dart';
import 'package:opennutritracker/core/data/data_source/water_intake_data_source.dart';
import 'package:opennutritracker/core/data/data_source/custom_meal_data_source.dart';
import 'package:opennutritracker/core/data/data_source/config_data_source.dart';
import 'package:opennutritracker/core/data/data_source/custom_activity_template_dbo.dart';
import 'package:opennutritracker/core/data/data_source/favourite_meal_data_source.dart';
import 'package:opennutritracker/core/data/data_source/user_activity_dbo.dart';
import 'package:opennutritracker/core/data/dbo/favourite_meal_dbo.dart';
import 'package:opennutritracker/core/data/dbo/intake_dbo.dart';
import 'package:opennutritracker/core/data/dbo/recipe_dbo.dart';
import 'package:opennutritracker/core/data/dbo/tracked_day_dbo.dart';
import 'package:opennutritracker/core/data/dbo/weight_log_dbo.dart';
import 'package:opennutritracker/core/data/repository/config_repository.dart';
import 'package:opennutritracker/core/data/repository/custom_activity_template_repository.dart';
import 'package:opennutritracker/core/data/repository/favourite_meal_repository.dart';
import 'package:opennutritracker/core/data/repository/intake_repository.dart';
import 'package:opennutritracker/core/data/repository/recipe_repository.dart';
import 'package:opennutritracker/core/data/repository/tracked_day_repository.dart';
import 'package:opennutritracker/core/data/repository/user_activity_repository.dart';
import 'package:opennutritracker/core/data/repository/user_repository.dart';
import 'package:opennutritracker/core/data/repository/weight_log_repository.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_activity_entity.dart';
import 'package:opennutritracker/core/domain/usecase/add_config_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_profiles_usecase.dart';
import 'package:opennutritracker/core/utils/extensions.dart';
import 'package:opennutritracker/core/utils/hive_db_provider.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/core/utils/tracked_day_lock.dart';
import 'package:opennutritracker/core/utils/tracked_day_reconciler.dart';
import 'package:opennutritracker/core/utils/url_const.dart';
import 'package:opennutritracker/core/utils/user_image_storage.dart';
import 'package:opennutritracker/features/settings/domain/goal_settings_backup.dart';
import 'package:opennutritracker/features/settings/domain/tracked_day_boundary_record.dart';
import 'package:opennutritracker/features/settings/domain/usecase/export_data_usecase.dart';
import 'package:opennutritracker/features/settings/presentation/bloc/export_import_bloc.dart';
import 'package:opennutritracker/features/sync/data/sync_store.dart';
import 'package:opennutritracker/features/sync/domain/sync_merge.dart';
import 'package:opennutritracker/features/sync/domain/sync_profile.dart';

/// What a sync changed on this phone.
class SyncSummary {
  final int added;
  final int updated;
  final int removed;
  final int conflicts;
  final bool firstSync;
  final bool profileReceived;

  const SyncSummary({
    required this.added,
    required this.updated,
    required this.removed,
    required this.conflicts,
    required this.firstSync,
    required this.profileReceived,
  });
}

/// Why a sync could not be applied, in words the screen can show.
enum SyncFailure {
  /// This phone is new (no profile yet) and the other phone sent none.
  noProfileAnywhere,

  /// The bundle is not one this build understands.
  unreadableBundle,

  /// The profile was switched while the sync ran.
  profileSwitched,
}

class SyncException implements Exception {
  final SyncFailure reason;
  const SyncException(this.reason);

  @override
  String toString() => 'SyncException($reason)';
}

/// Settings a brand-new phone needs when it takes the other phone's
/// profile instead of running the first-time setup.
class SyncOnboarding {
  final bool acceptedDataCollection;
  const SyncOnboarding({required this.acceptedDataCollection});
}

/// One kind of entry the sync merges: how it is read, identified, written
/// and removed. The JSON is what the regular export writes, so a bundle is
/// an export archive.
class _Collection<T> {
  final String key;
  final String fileName;
  final String Function(T) idOf;
  final Map<String, dynamic> Function(T) toJson;
  final T Function(Map<String, dynamic>) fromJson;
  final Future<List<T>> Function() readLocal;
  final Future<void> Function(List<T>) upsert;
  final Future<void> Function(T) delete;

  const _Collection({
    required this.key,
    required this.fileName,
    required this.idOf,
    required this.toJson,
    required this.fromJson,
    required this.readLocal,
    required this.upsert,
    required this.delete,
  });

  Future<Map<String, T>> localById() async => {
    for (final item in await readLocal())
      if (idOf(item).trim().isNotEmpty) idOf(item): item,
  };

  /// The remote entries, or null when the bundle has no file for this kind
  /// — then it is left alone rather than read as "everything deleted".
  SyncRecords? remoteRecords(Archive archive) {
    final file = archive.findFile(fileName);
    if (file == null) return null;
    final list = jsonDecode(utf8.decode(file.content as List<int>)) as List;
    final records = <String, Map<String, dynamic>>{};
    for (final raw in list) {
      final json = (raw as Map).cast<String, dynamic>();
      final id = idOf(fromJson(json));
      if (id.trim().isEmpty) continue;
      records[id] = json;
    }
    return records;
  }
}

/// Builds this phone's sync bundle and merges the other phone's into it.
class SyncEngine {
  static const _metaFileName = 'sync_meta.json';
  static const formatVersion = 1;

  final SyncStore store;

  SyncEngine({SyncStore? store}) : store = store ?? SyncStore();

  String get _profileId =>
      locator<GetProfilesUsecase>().getActiveProfile()?.id ?? 'default';

  List<_Collection<Object>> get _collections {
    final intakes = locator<IntakeRepository>();
    final activities = locator<UserActivityRepository>();
    final weights = locator<WeightLogRepository>();
    final recipes = locator<RecipeRepository>();
    final favourites = locator<FavouriteMealRepository>();
    final templates = locator<CustomActivityTemplateRepository>();
    final water = locator<WaterIntakeDataSource>();
    final fasting = locator<FastingDataSource>();
    final customMeals = locator<CustomMealDataSource>();
    return [
      _Collection<IntakeDBO>(
        key: 'intakes',
        fileName: ExportImportBloc.userIntakeJsonFileName,
        idOf: (d) => d.id,
        toJson: (d) => d.toJson(),
        fromJson: IntakeDBO.fromJson,
        readLocal: intakes.getAllIntakesDBO,
        upsert: intakes.upsertAllIntakeDBOs,
        delete: (d) => intakes.deleteIntake(IntakeEntity.fromIntakeDBO(d)),
      ),
      _Collection<UserActivityDBO>(
        key: 'activities',
        fileName: ExportImportBloc.userActivityJsonFileName,
        idOf: (d) => d.id,
        toJson: (d) => d.toJson(),
        fromJson: UserActivityDBO.fromJson,
        readLocal: activities.getAllUserActivityDBO,
        upsert: activities.upsertAllUserActivityDBOs,
        delete: (d) => activities.deleteUserActivity(
          UserActivityEntity.fromUserActivityDBO(d),
        ),
      ),
      _Collection<WeightLogDBO>(
        key: 'weightLog',
        fileName: ExportImportBloc.weightLogJsonFileName,
        idOf: (d) => d.date.toParsedDay(),
        toJson: (d) => d.toJson(),
        fromJson: WeightLogDBO.fromJson,
        readLocal: weights.getAllEntriesDBO,
        upsert: weights.addAllEntries,
        delete: (d) => weights.deleteEntry(d.date),
      ),
      _Collection<RecipeDBO>(
        key: 'recipes',
        fileName: ExportImportBloc.recipeJsonFileName,
        idOf: (d) => d.id,
        toJson: (d) => d.toJson(),
        fromJson: RecipeDBO.fromJson,
        readLocal: () async => recipes.getAllRecipesDBO(),
        upsert: recipes.addAllRecipeDBOs,
        delete: (d) => recipes.deleteRecipe(d.id),
      ),
      _Collection<FavouriteMealDBO>(
        key: 'favourites',
        fileName: ExportImportBloc.favouriteJsonFileName,
        idOf: (d) => d.mealKey,
        toJson: (d) => d.toJson(),
        fromJson: FavouriteMealDBO.fromJson,
        readLocal: favourites.getAllFavouritesDBO,
        upsert: favourites.addAllFavouriteDBOs,
        delete: (d) =>
            locator<FavouriteMealDataSource>().deleteFavourite(d.mealKey),
      ),
      _Collection<CustomActivityTemplateDBO>(
        key: 'activityTemplates',
        fileName: ExportImportBloc.customActivityTemplateJsonFileName,
        idOf: (d) => d.name,
        toJson: (d) => d.toJson(),
        fromJson: CustomActivityTemplateDBO.fromJson,
        readLocal: templates.allTemplateDBOs,
        upsert: templates.upsertAllTemplateDBOs,
        delete: (d) => templates.deleteTemplate(d.name),
      ),
      _Collection<WaterIntakeDBO>(
        key: 'water',
        fileName: FullBackupExtras.waterFileName,
        idOf: (d) => d.id,
        toJson: (d) => d.toJson(),
        fromJson: WaterIntakeDBO.fromJson,
        readLocal: water.allEntries,
        upsert: water.addAllEntries,
        delete: (d) => water.deleteEntry(d.id),
      ),
      _Collection<FastingSessionDBO>(
        key: 'fasting',
        fileName: FullBackupExtras.fastingFileName,
        idOf: (d) => d.id,
        toJson: (d) => d.toJson(),
        fromJson: FastingSessionDBO.fromJson,
        readLocal: fasting.allSessions,
        upsert: (sessions) async {
          for (final session in sessions) {
            await fasting.updateSession(session);
          }
        },
        delete: (d) => FullBackupExtras.deleteFastingSession(d.id),
      ),
      _Collection<MealDBO>(
        key: 'customMeals',
        fileName: FullBackupExtras.customMealsFileName,
        idOf: (d) => d.code ?? d.name ?? '',
        toJson: (d) => d.toJson(),
        fromJson: MealDBO.fromJson,
        readLocal: () async => customMeals.getAllCustomMeals(),
        upsert: (meals) async {
          for (final meal in meals) {
            await customMeals.saveCustomMeal(meal);
          }
        },
        delete: (d) => customMeals.deleteCustomMeal(d.code ?? d.name ?? ''),
      ),
    ].cast<_Collection<Object>>();
  }

  /// This phone's data as a zip: the regular JSON export, its body profile
  /// and the sync bookkeeping the other phone needs.
  Future<Uint8List> buildBundle({required String nextBaseId}) async {
    final archive = await locator<ExportDataUsecase>().assembleArchive(
      format: ExportFormat.json,
      userActivityJsonFileName: ExportImportBloc.userActivityJsonFileName,
      userIntakeJsonFileName: ExportImportBloc.userIntakeJsonFileName,
      trackedDayJsonFileName: ExportImportBloc.trackedDayJsonFileName,
      recipeJsonFileName: ExportImportBloc.recipeJsonFileName,
      weightLogJsonFileName: ExportImportBloc.weightLogJsonFileName,
      customActivityTemplateJsonFileName:
          ExportImportBloc.customActivityTemplateJsonFileName,
      goalSettingsJsonFileName: ExportImportBloc.goalSettingsJsonFileName,
      favouriteJsonFileName: ExportImportBloc.favouriteJsonFileName,
    );

    void addJson(String name, Object json) {
      final bytes = utf8.encode(jsonEncode(json));
      archive.addFile(ArchiveFile(name, bytes.length, bytes));
    }

    // The profile, preferences, water, fasting and custom foods come with
    // the export itself (FullBackupExtras).
    addJson(_metaFileName, {
      'v': formatVersion,
      'device': await store.deviceId(),
      'bases': await store.baseIdsFor(_profileId),
      'nextBase': nextBaseId,
    });
    return Uint8List.fromList(ZipEncoder().encode(archive));
  }

  /// Merges [remoteBundle] into this phone and records the new base. Both
  /// phones call this with each other's bundle; the host's `nextBase` id
  /// becomes the shared base id.
  Future<SyncSummary> apply(
    Uint8List remoteBundle, {
    required bool localIsHost,
    required String localNextBaseId,
    SyncOnboarding? onboarding,
  }) async {
    final startedOn = ProfileStamp.now();
    final Archive archive;
    final Map<String, dynamic> meta;
    try {
      archive = ZipDecoder().decodeBytes(remoteBundle);
      final metaFile = archive.findFile(_metaFileName);
      meta =
          jsonDecode(utf8.decode(metaFile!.content as List<int>))
              as Map<String, dynamic>;
      if ((meta['v'] as int) > formatVersion) {
        throw const SyncException(SyncFailure.unreadableBundle);
      }
    } on SyncException {
      rethrow;
    } catch (_) {
      throw const SyncException(SyncFailure.unreadableBundle);
    }

    final profileId = _profileId;
    final localDevice = await store.deviceId();
    final remoteDevice = meta['device'] as String;
    final remoteBases = (meta['bases'] as Map? ?? {}).cast<String, String>();
    final sharedBaseId = localIsHost
        ? localNextBaseId
        : meta['nextBase'] as String;

    // The stored base counts only if both phones hold the same one;
    // otherwise (a reinstall, a sync that failed half-way) this sync is a
    // union and deletes nothing.
    final stored = await store.readBase(profileId, remoteDevice);
    final baseAgreed =
        stored != null && remoteBases[localDevice] == stored.baseId;

    final remoteProfileFile = archive.findFile(SyncProfile.fileName);
    final remoteProfile = remoteProfileFile == null
        ? null
        : SyncProfile.fromJson(
            jsonDecode(utf8.decode(remoteProfileFile.content as List<int>))
                as Map<String, dynamic>,
          );
    final users = locator<UserRepository>();
    final hasLocalUser = await users.hasUserData();
    if (!hasLocalUser && remoteProfile == null) {
      throw const SyncException(SyncFailure.noProfileAnywhere);
    }

    // Decide every change before writing any.
    final collections = _collections;
    final plans =
        <
          ({
            _Collection<Object> collection,
            Map<String, Object> local,
            SyncMergeResult result,
          })
        >[];
    var remoteIsEmpty = true;
    final remoteByCollection = <String, SyncRecords?>{};
    for (final collection in collections) {
      final records = collection.remoteRecords(archive);
      remoteByCollection[collection.key] = records;
      if (records != null && records.isNotEmpty) remoteIsEmpty = false;
    }
    // A phone that sends nothing at all has been wiped or is new; never
    // let that delete everything here.
    final useBase = baseAgreed && !remoteIsEmpty;
    for (final collection in collections) {
      final remote = remoteByCollection[collection.key];
      if (remote == null) continue;
      final local = await collection.localById();
      final result = mergeSyncRecords(
        local: {
          for (final MapEntry(:key, :value) in local.entries)
            key: collection.toJson(value),
        },
        remote: remote,
        base: useBase ? stored.collections[collection.key] : null,
        localIsHost: localIsHost,
      );
      plans.add((collection: collection, local: local, result: result));
    }

    final remoteRows = _decodeList(
      archive,
      ExportImportBloc.trackedDayJsonFileName,
      TrackedDayDBO.fromJson,
    );
    final remoteActivities = _decodeList(
      archive,
      ExportImportBloc.userActivityJsonFileName,
      UserActivityDBO.fromJson,
    );
    final boundaryFile = archive.findFile(
      TrackedDayBoundaryRecord.jsonFileName,
    );
    final remoteKeyedBy = boundaryFile == null
        ? null
        : TrackedDayBoundaryRecord.fromJson(
            utf8.decode(boundaryFile.content as List<int>),
          );

    final latestWeightBefore = await _latestWeightDate();

    final applied = await withTrackedDayLockOnProfile(() async {
      final localRowKeys = {
        for (final row
            in await locator<TrackedDayRepository>().getAllTrackedDaysDBO())
          row.day.toParsedDay(),
      };
      // Days only the other phone has rows for come with their goals.
      final newRows = [
        for (final row in remoteRows)
          if (!localRowKeys.contains(row.day.toParsedDay())) row,
      ];

      Future<void> write() async {
        for (final plan in plans) {
          final collection = plan.collection;
          if (plan.result.upserts.isNotEmpty) {
            await collection.upsert([
              for (final json in plan.result.upserts.values)
                collection.fromJson(json),
            ]);
          }
          for (final id in plan.result.deletes) {
            final local = plan.local[id];
            if (local != null) await collection.delete(local);
          }
        }
        if (newRows.isNotEmpty) {
          await locator<TrackedDayRepository>().addAllTrackedDays(newRows);
        }
      }

      await restoreTrackedDays(
        locator<HiveDBProvider>(),
        locator<ConfigDataSource>(),
        write: write,
        importedDayKeys: {for (final row in newRows) row.day.toParsedDay()},
        importedActivities: remoteActivities,
        keyedByOffsetMinutes: remoteKeyedBy,
      );
      await _writeImages(archive);
      return true;
    }, startedOn: startedOn);
    if (applied == null) {
      throw const SyncException(SyncFailure.profileSwitched);
    }

    var profileReceived = false;
    if (!hasLocalUser && remoteProfile != null) {
      await _takeProfile(remoteProfile, archive, onboarding);
      profileReceived = true;
    } else {
      await _followNewerWeight(latestWeightBefore);
    }

    await store.writeBase(
      profileId,
      remoteDevice,
      SyncBaseRecord(sharedBaseId, {
        for (final plan in plans) plan.collection.key: plan.result.mergedBase,
        // Kinds the other phone did not send keep their previous base.
        if (stored != null)
          for (final MapEntry(:key, :value) in stored.collections.entries)
            if (!plans.any((p) => p.collection.key == key)) key: value,
      }),
    );

    int sum(int Function(SyncMergeResult) f) =>
        plans.fold(0, (total, plan) => total + f(plan.result));
    return SyncSummary(
      added: sum((r) => r.added),
      updated: sum((r) => r.updated),
      removed: sum((r) => r.removed),
      conflicts: sum((r) => r.conflicts),
      firstSync: !useBase,
      profileReceived: profileReceived,
    );
  }

  List<T> _decodeList<T>(
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

  /// Photos the other phone has and this one does not.
  Future<void> _writeImages(Archive archive) async {
    final recipeDir = await UserImageStorage.ensureDirectory(
      UserImageKind.recipe,
    );
    final mealDir = await UserImageStorage.ensureDirectory(UserImageKind.meal);
    for (final entry in archive.files) {
      if (!entry.isFile) continue;
      final sanitized = UserImageStorage.sanitizeRelative(entry.name);
      if (sanitized == null) continue;
      final parts = sanitized.split('/');
      final dir = parts[0] == UserImageKind.recipe.subdir ? recipeDir : mealDir;
      final file = File('${dir.path}/${parts[1]}');
      if (await file.exists()) continue;
      await file.writeAsBytes(entry.content as List<int>, flush: true);
    }
  }

  /// A new phone takes the other phone's profile, unit choices and goal
  /// settings in place of the first-time setup.
  Future<void> _takeProfile(
    SyncProfile profile,
    Archive archive,
    SyncOnboarding? onboarding,
  ) async {
    const extras = FullBackupExtras();
    await extras.restoreProfile(archive);
    await extras.restorePreferences(archive);
    final config = locator<AddConfigUsecase>();
    final goalFile = archive.findFile(
      ExportImportBloc.goalSettingsJsonFileName,
    );
    final goals = goalFile == null
        ? null
        : GoalSettingsBackup.fromJson(
            jsonDecode(utf8.decode(goalFile.content as List<int>)),
          );
    if (goals != null) {
      await locator<ConfigRepository>().setConfigGoalSettings(
        kcalAdjustment: goals.kcalAdjustment,
        carbGoalPct: goals.carbGoalPct,
        proteinGoalPct: goals.proteinGoalPct,
        fatGoalPct: goals.fatGoalPct,
        mealKcalSharesPct: goals.mealKcalSharesPct,
        dailyWaterGoalMl: goals.dailyWaterGoalMl,
      );
    }
    if (onboarding != null) {
      // What finishing the first-time setup records; the welcome page
      // required the policy before offering the sync.
      await config.setConfigHasAcceptedPolicy(true);
      await config.setConfigPolicyNoticeRevisionSeen(URLConst.policyRevision);
      await config.setConfigHasAcceptedAnonymousData(
        onboarding.acceptedDataCollection,
      );
      await config.setConfigIsDemoData(false);
    }
  }

  Future<DateTime?> _latestWeightDate() async {
    final entries = await locator<WeightLogRepository>().getAllEntriesDBO();
    if (entries.isEmpty) return null;
    return entries.map((e) => e.date).reduce((a, b) => a.isAfter(b) ? a : b);
  }

  /// The profile weight follows a newer weigh-in from the other phone, so
  /// both phones compute the goal from the same current weight.
  Future<void> _followNewerWeight(DateTime? latestBefore) async {
    final entries = await locator<WeightLogRepository>().getAllEntriesDBO();
    if (entries.isEmpty) return;
    final latest = entries.reduce((a, b) => a.date.isAfter(b.date) ? a : b);
    if (latestBefore != null && !latest.date.isAfter(latestBefore)) return;
    final users = locator<UserRepository>();
    final user = await users.getUserData();
    if ((user.weightKG - latest.weightKg).abs() < 0.001) return;
    await users.updateUserData(SyncProfile.withWeight(user, latest.weightKg));
  }
}
