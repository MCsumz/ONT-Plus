import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/domain/entity/body_weight_unit_entity.dart';
import 'package:opennutritracker/core/domain/entity/calories_profile_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_gender_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_pal_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_weight_goal_entity.dart';
import 'package:opennutritracker/features/sync/domain/sync_profile.dart';

void main() {
  UserEntity user() => UserEntity(
        birthday: DateTime(1994, 3, 12),
        heightCM: 181.5,
        weightKG: 82.4,
        gender: UserGenderEntity.values.first,
        goal: UserWeightGoalEntity.values.last,
        pal: UserPALEntity.values[1],
        weeklyWeightGoalKg: -0.5,
        caloriesProfile: CaloriesProfileEntity.values.first,
        targetWeightKg: 78,
        caloriesTaperEnabled: true,
      );

  test('the body profile survives a round trip through JSON', () {
    final original = SyncProfile(
      user: user(),
      usesImperialHeightUnits: true,
      bodyWeightUnit: BodyWeightUnit.st,
      usesImperialFoodUnits: false,
    );
    final back = SyncProfile.fromJson(
      jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>,
    );
    final u = back.user;
    expect(u.birthday, DateTime(1994, 3, 12));
    expect(u.heightCM, 181.5);
    expect(u.weightKG, 82.4);
    expect(u.gender, original.user.gender);
    expect(u.goal, original.user.goal);
    expect(u.pal, original.user.pal);
    expect(u.weeklyWeightGoalKg, -0.5);
    expect(u.caloriesProfile, original.user.caloriesProfile);
    expect(u.targetWeightKg, 78);
    expect(u.caloriesTaperEnabled, isTrue);
    expect(back.usesImperialHeightUnits, isTrue);
    expect(back.bodyWeightUnit, BodyWeightUnit.st);
    expect(back.usesImperialFoodUnits, isFalse);
  });

  test('an older profile file without the optional fields still reads', () {
    final json = SyncProfile(
      user: user(),
      usesImperialHeightUnits: false,
      bodyWeightUnit: BodyWeightUnit.kg,
      usesImperialFoodUnits: false,
    ).toJson()
      ..remove('caloriesProfile')
      ..remove('bodyWeightUnit')
      ..remove('caloriesTaperEnabled');
    final back = SyncProfile.fromJson(json);
    expect(back.user.caloriesProfile, isNull);
    expect(back.bodyWeightUnit, BodyWeightUnit.kg);
    expect(back.user.caloriesTaperEnabled, isFalse);
  });

  test('withWeight changes the weight and nothing else', () {
    final moved = SyncProfile.withWeight(user(), 80.1);
    expect(moved.weightKG, 80.1);
    expect(moved.heightCM, 181.5);
    expect(moved.targetWeightKg, 78);
    expect(moved.caloriesTaperEnabled, isTrue);
  });

  test('the day boundary is read only when it is a real time of day', () {
    expect(
      const AppPreferencesBackup({
        'dayStartOffsetHours': 4,
        'dayStartOffsetMinutes': 30,
      }).dayStartOffset,
      (4, 30),
    );
    expect(
      const AppPreferencesBackup({
        'dayStartOffsetHours': 25,
        'dayStartOffsetMinutes': 0,
      }).dayStartOffset,
      isNull,
    );
    expect(const AppPreferencesBackup({}).dayStartOffset, isNull);
  });
}
