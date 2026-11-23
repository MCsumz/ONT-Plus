import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:opennutritracker/core/domain/entity/profile_entity.dart';
import 'package:opennutritracker/core/domain/usecase/get_profiles_usecase.dart';
import 'package:opennutritracker/core/utils/hive_db_provider.dart';
import 'package:opennutritracker/core/utils/locator.dart';

/// Builds with the active profile, again whenever a profile is renamed,
/// gets a photo, or another one becomes active.
class ActiveProfileBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, ProfileEntity? profile) builder;

  const ActiveProfileBuilder({super.key, required this.builder});

  /// The profile's own name, or null for the unnamed default profile.
  static String? nameOf(ProfileEntity? profile) {
    final name = profile?.name.trim() ?? '';
    return name.isEmpty ? null : name;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: locator<HiveDBProvider>().profileBox.listenable(),
      builder: (context, _, _) =>
          builder(context, locator<GetProfilesUsecase>().getActiveProfile()),
    );
  }
}
