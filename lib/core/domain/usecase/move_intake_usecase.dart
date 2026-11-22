import 'package:opennutritracker/core/data/dbo/intake_type_dbo.dart';
import 'package:opennutritracker/core/data/repository/intake_repository.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/domain/entity/intake_type_entity.dart';
import 'package:opennutritracker/core/utils/tracked_day_lock.dart';

/// Moves a logged entry to another meal section of the same day.
///
/// Only the entry's meal type changes. Its day, amount and nutrients stay
/// as they are, so the day's tracked totals are already right and are left
/// alone — unlike re-adding the entry and deleting the original, which
/// debits whichever day the delete resolves to.
class MoveIntakeUsecase {
  final IntakeRepository _intakeRepository;

  MoveIntakeUsecase(this._intakeRepository);

  Future<IntakeEntity?> moveIntake(
    IntakeEntity intake,
    IntakeTypeEntity targetType,
  ) async {
    if (intake.type == targetType) return intake;
    return withTrackedDayLockOnProfile<IntakeEntity?>(
      () => _intakeRepository.updateIntake(intake.id, {
        'type': IntakeTypeDBO.fromIntakeTypeEntity(targetType),
      }),
    );
  }
}
