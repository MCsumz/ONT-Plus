import 'package:opennutritracker/core/domain/entity/app_theme_entity.dart';
import 'package:opennutritracker/core/domain/entity/body_weight_unit_entity.dart';
import 'package:opennutritracker/core/domain/entity/calories_profile_entity.dart';
import 'package:opennutritracker/core/domain/entity/config_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_gender_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_pal_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_weight_goal_entity.dart';
import 'package:opennutritracker/core/domain/usecase/add_config_usecase.dart';

/// The body profile from the first-time setup and its unit choices, which
/// the regular backup leaves out. Sent with a sync so a new phone can skip
/// the setup questions.
class SyncProfile {
  static const fileName = 'user_profile.json';

  final UserEntity user;
  final bool usesImperialHeightUnits;
  final BodyWeightUnit bodyWeightUnit;
  final bool usesImperialFoodUnits;

  const SyncProfile({
    required this.user,
    required this.usesImperialHeightUnits,
    required this.bodyWeightUnit,
    required this.usesImperialFoodUnits,
  });

  Map<String, dynamic> toJson() => {
    'birthday': user.birthday.toIso8601String(),
    'heightCM': user.heightCM,
    'weightKG': user.weightKG,
    'gender': user.gender.name,
    'goal': user.goal.name,
    'pal': user.pal.name,
    'weeklyWeightGoalKg': user.weeklyWeightGoalKg,
    'caloriesProfile': user.caloriesProfile?.name,
    'targetWeightKg': user.targetWeightKg,
    'caloriesTaperEnabled': user.caloriesTaperEnabled,
    'usesImperialHeightUnits': usesImperialHeightUnits,
    'bodyWeightUnit': bodyWeightUnit.name,
    'usesImperialFoodUnits': usesImperialFoodUnits,
  };

  factory SyncProfile.fromJson(Map<String, dynamic> json) {
    double? optDouble(Object? v) => (v as num?)?.toDouble();
    final caloriesProfile = json['caloriesProfile'] as String?;
    return SyncProfile(
      user: UserEntity(
        birthday: DateTime.parse(json['birthday'] as String),
        heightCM: (json['heightCM'] as num).toDouble(),
        weightKG: (json['weightKG'] as num).toDouble(),
        gender: UserGenderEntity.values.byName(json['gender'] as String),
        goal: UserWeightGoalEntity.values.byName(json['goal'] as String),
        pal: UserPALEntity.values.byName(json['pal'] as String),
        weeklyWeightGoalKg: optDouble(json['weeklyWeightGoalKg']),
        caloriesProfile: caloriesProfile == null
            ? null
            : CaloriesProfileEntity.values.byName(caloriesProfile),
        targetWeightKg: optDouble(json['targetWeightKg']),
        caloriesTaperEnabled: json['caloriesTaperEnabled'] as bool? ?? false,
      ),
      usesImperialHeightUnits:
          json['usesImperialHeightUnits'] as bool? ?? false,
      bodyWeightUnit: BodyWeightUnit.values.byName(
        json['bodyWeightUnit'] as String? ?? BodyWeightUnit.kg.name,
      ),
      usesImperialFoodUnits: json['usesImperialFoodUnits'] as bool? ?? false,
    );
  }

  /// [user] with its weight replaced, the other fields as they are.
  static UserEntity withWeight(UserEntity user, double weightKG) => UserEntity(
    birthday: user.birthday,
    heightCM: user.heightCM,
    weightKG: weightKG,
    gender: user.gender,
    goal: user.goal,
    pal: user.pal,
    weeklyWeightGoalKg: user.weeklyWeightGoalKg,
    caloriesProfile: user.caloriesProfile,
    targetWeightKg: user.targetWeightKg,
    caloriesTaperEnabled: user.caloriesTaperEnabled,
  );
}

/// The app preferences chosen in the first-time setup and in Settings that
/// describe how the user wants the app, not this device: theme and colour,
/// units, food databases, what the diary shows, when a day starts.
///
/// Left out on purpose: AI keys (secrets stay on their phone), the daily
/// reminder and health import (scheduled and permitted per device), the
/// privacy consents and the language.
class AppPreferencesBackup {
  static const fileName = 'app_preferences.json';

  final Map<String, dynamic> values;

  const AppPreferencesBackup(this.values);

  static AppPreferencesBackup capture(ConfigEntity config) =>
      AppPreferencesBackup({
        'appTheme': config.appTheme.name,
        'usesImperialUnits': config.usesImperialUnits,
        'usesKilojoules': config.usesKilojoules,
        'showActivityTracking': config.showActivityTracking,
        'showMealMacros': config.showMealMacros,
        'showMicronutrients': config.showMicronutrients,
        'defaultToRawFoodUnits': config.defaultToRawFoodUnits,
        'nutrientPanelVisibility': config.nutrientPanelVisibility,
        'useMaterialYou': config.useMaterialYou,
        'accentColor': config.accentColor,
        'foodSourceToggles': config.foodSourceToggles,
        'dayStartOffsetHours': config.dayStartOffsetHours,
        'dayStartOffsetMinutes': config.dayStartOffsetMinutes,
      });

  /// Writes every preference present in [values]; an absent or unreadable
  /// one leaves this phone's setting as it is. The day boundary is not
  /// written here: it moves the diary's rows and goes through
  /// [dayStartOffset] and `moveDayBoundary`.
  Future<void> applyTo(AddConfigUsecase config) async {
    T? read<T>(String key) {
      final value = values[key];
      return value is T ? value : null;
    }

    final theme = read<String>('appTheme');
    if (theme != null) {
      final match = AppThemeEntity.values.where((t) => t.name == theme);
      if (match.isNotEmpty) await config.setConfigAppTheme(match.first);
    }
    final imperial = read<bool>('usesImperialUnits');
    if (imperial != null) await config.setConfigUsesImperialUnits(imperial);
    final kj = read<bool>('usesKilojoules');
    if (kj != null) await config.setConfigUsesKilojoules(kj);
    final activity = read<bool>('showActivityTracking');
    if (activity != null) await config.setConfigShowActivityTracking(activity);
    final macros = read<bool>('showMealMacros');
    if (macros != null) await config.setConfigShowMealMacros(macros);
    final micros = read<bool>('showMicronutrients');
    if (micros != null) await config.setConfigShowMicronutrients(micros);
    final raw = read<bool>('defaultToRawFoodUnits');
    if (raw != null) await config.setConfigDefaultToRawFoodUnits(raw);
    final panel = read<Map>('nutrientPanelVisibility');
    if (panel != null) {
      await config.setConfigNutrientPanelVisibility(
        panel.map((k, v) => MapEntry(k.toString(), v == true)),
      );
    }
    final materialYou = read<bool>('useMaterialYou');
    if (materialYou != null) await config.setConfigUseMaterialYou(materialYou);
    if (values.containsKey('accentColor')) {
      await config.setConfigAccentColor(read<int>('accentColor'));
    }
    final sources = read<Map>('foodSourceToggles');
    if (sources != null && sources.isNotEmpty) {
      await config.setConfigFoodSourceToggles(
        sources.map((k, v) => MapEntry(k.toString(), v == true)),
      );
    }
  }

  /// The day boundary as (hours, minutes), or null when not recorded.
  (int, int)? get dayStartOffset {
    final hours = values['dayStartOffsetHours'];
    final minutes = values['dayStartOffsetMinutes'];
    if (hours is! int || minutes is! int) return null;
    if (hours < 0 || hours > 23 || minutes < 0 || minutes > 59) return null;
    return (hours, minutes);
  }
}
