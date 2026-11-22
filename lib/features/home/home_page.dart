import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logging/logging.dart';
import 'package:opennutritracker/core/domain/entity/calories_profile_entity.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_gender_entity.dart';
import 'package:opennutritracker/core/presentation/widgets/empty_hint.dart';
import 'package:opennutritracker/core/presentation/widgets/low_kcal_warning_card.dart';
import 'package:opennutritracker/core/styles/dimens.dart';
import 'package:opennutritracker/core/utils/calc/calorie_goal_calc.dart';
import 'package:opennutritracker/core/domain/entity/intake_type_entity.dart';
import 'package:opennutritracker/core/domain/entity/tracked_day_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_activity_entity.dart';
import 'package:opennutritracker/core/presentation/widgets/activity_vertial_list.dart';
import 'package:opennutritracker/core/presentation/widgets/edit_activity_dialog.dart';
import 'package:opennutritracker/core/presentation/widgets/delete_dialog.dart';
import 'package:opennutritracker/core/presentation/widgets/disclaimer_dialog.dart';
import 'package:opennutritracker/core/domain/usecase/import_workouts_usecase.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/features/add_meal/presentation/add_meal_type.dart';
import 'package:opennutritracker/features/diary/presentation/bloc/calendar_day_bloc.dart';
import 'package:opennutritracker/features/diary/presentation/bloc/diary_bloc.dart';
import 'package:opennutritracker/features/home/presentation/bloc/home_bloc.dart';
import 'package:opennutritracker/features/home/presentation/widgets/dashboard_widget.dart';
import 'package:opennutritracker/features/home/presentation/widgets/intake_vertical_list.dart';
import 'package:opennutritracker/features/home/presentation/widgets/fasting_home_chip.dart';
import 'package:opennutritracker/features/home/presentation/widgets/home_date_bar.dart';
import 'package:opennutritracker/features/home/presentation/widgets/home_day_swiper.dart';
import 'package:opennutritracker/features/home/presentation/widgets/quick_water_widget.dart';
import 'package:opennutritracker/core/domain/entity/body_weight_unit_entity.dart';
import 'package:opennutritracker/features/home/presentation/widgets/quick_weight_widget.dart';
import 'package:opennutritracker/features/meal_detail/meal_detail_screen.dart';
import 'package:opennutritracker/generated/l10n.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  final log = Logger('HomePage');

  late HomeBloc _homeBloc;
  bool _isActivityDragging = false;

  @override
  void initState() {
    WidgetsBinding.instance.addObserver(this);
    _homeBloc = locator<HomeBloc>();
    // Workouts that landed in the health store while the app was closed. Run
    // from here rather than from bootstrap so a launch import reaches the
    // same diary refresh a resume import does.
    unawaited(_importHealthWorkouts());
    super.initState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HomeBloc, HomeState>(
      bloc: _homeBloc,
      builder: (context, state) {
        if (state is HomeInitial) {
          _homeBloc.add(const LoadItemsEvent());
          return _getLoadingContent();
        } else if (state is HomeLoadingState) {
          return _getLoadingContent();
        } else if (state is HomeLoadedState) {
          return _getLoadedContent(
            context,
            state.showDisclaimerDialog,
            state.totalKcalDaily,
            state.userGender,
            state.userCaloriesProfile,
            state.totalKcalLeft,
            state.totalKcalSupplied,
            state.totalKcalBurned,
            state.totalCarbsIntake,
            state.totalFatsIntake,
            state.totalProteinsIntake,
            state.totalCarbsGoal,
            state.totalFatsGoal,
            state.totalProteinsGoal,
            state.breakfastIntakeList,
            state.lunchIntakeList,
            state.dinnerIntakeList,
            state.snackIntakeList,
            state.userActivityList,
            state.usesImperialUnits,
            state.bodyWeightUnit,
            state.showActivityTracking,
            state.showMealMacros,
            state.userWeightKg,
            state.breakfastKcalTarget,
            state.lunchKcalTarget,
            state.dinnerKcalTarget,
            state.snackKcalTarget,
            state.breakfastSharePct,
            state.lunchSharePct,
            state.dinnerSharePct,
            state.snackSharePct,
            state.waterMlToday,
            state.waterGoalMl,
            state.viewedDay,
            state.isToday,
          );
        } else {
          return _getLoadingContent();
        }
      },
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      log.info('App resumed');
      _refreshPageOnDayChange();
      unawaited(_importHealthWorkouts());
    }
    super.didChangeAppLifecycleState(state);
  }

  Widget _getLoadingContent() {
    return const Center(child: CircularProgressIndicator());
  }

  Widget _getLoadedContent(
    BuildContext context,
    bool showDisclaimerDialog,
    double totalKcalDaily,
    UserGenderEntity userGender,
    CaloriesProfileEntity? userCaloriesProfile,
    double totalKcalLeft,
    double totalKcalSupplied,
    double totalKcalBurned,
    double totalCarbsIntake,
    double totalFatsIntake,
    double totalProteinsIntake,
    double totalCarbsGoal,
    double totalFatsGoal,
    double totalProteinsGoal,
    List<IntakeEntity> breakfastIntakeList,
    List<IntakeEntity> lunchIntakeList,
    List<IntakeEntity> dinnerIntakeList,
    List<IntakeEntity> snackIntakeList,
    List<UserActivityEntity> userActivities,
    bool usesImperialUnits,
    BodyWeightUnit bodyWeightUnit,
    bool showActivityTracking,
    bool showMealMacros,
    double userWeightKg,
    double breakfastKcalTarget,
    double lunchKcalTarget,
    double dinnerKcalTarget,
    double snackKcalTarget,
    int breakfastSharePct,
    int lunchSharePct,
    int dinnerSharePct,
    int snackSharePct,
    int waterMlToday,
    int waterGoalMl,
    DateTime? viewedDay,
    bool isToday,
  ) {
    if (showDisclaimerDialog) {
      _showDisclaimerDialog(context);
    }
    final today = _today;
    final shownDay = viewedDay ?? today;
    // What adding to a section files under: now for today, the day's
    // label for another day (the Diary does the same).
    final entryDay = isToday ? DateTime.now() : shownDay;
    final isFuture = shownDay.isAfter(today);
    return Column(
      children: [
        HomeDateBar(
          day: shownDay,
          today: today,
          canGoBack: shownDay.isAfter(_firstDay),
          canGoForward: shownDay.isBefore(_lastDay),
          onPrevious: () => _moveDay(-1),
          onNext: () => _moveDay(1),
          onToday: () => _homeBloc.add(const ChangeHomeDayEvent(null)),
          onPick: _showDay,
          firstDay: _firstDay,
          lastDay: _lastDay,
        ),
        Expanded(
          child: HomeDaySwiper(
            day: shownDay,
            onChangeDay: _moveDay,
            child: _buildDayContent(
              context,
              isToday: isToday,
              isFuture: isFuture,
              entryDay: entryDay,
              totalKcalDaily: totalKcalDaily,
              userGender: userGender,
              userCaloriesProfile: userCaloriesProfile,
              totalKcalLeft: totalKcalLeft,
              totalKcalSupplied: totalKcalSupplied,
              totalKcalBurned: totalKcalBurned,
              totalCarbsIntake: totalCarbsIntake,
              totalFatsIntake: totalFatsIntake,
              totalProteinsIntake: totalProteinsIntake,
              totalCarbsGoal: totalCarbsGoal,
              totalFatsGoal: totalFatsGoal,
              totalProteinsGoal: totalProteinsGoal,
              breakfastIntakeList: breakfastIntakeList,
              lunchIntakeList: lunchIntakeList,
              dinnerIntakeList: dinnerIntakeList,
              snackIntakeList: snackIntakeList,
              userActivities: userActivities,
              usesImperialUnits: usesImperialUnits,
              bodyWeightUnit: bodyWeightUnit,
              showActivityTracking: showActivityTracking,
              showMealMacros: showMealMacros,
              userWeightKg: userWeightKg,
              breakfastKcalTarget: breakfastKcalTarget,
              lunchKcalTarget: lunchKcalTarget,
              dinnerKcalTarget: dinnerKcalTarget,
              snackKcalTarget: snackKcalTarget,
              breakfastSharePct: breakfastSharePct,
              lunchSharePct: lunchSharePct,
              dinnerSharePct: dinnerSharePct,
              snackSharePct: snackSharePct,
              waterMlToday: waterMlToday,
              waterGoalMl: waterGoalMl,
            ),
          ),
        ),
      ],
    );
  }

  /// The logical today Home last loaded.
  DateTime get _today => DateUtils.dateOnly(_homeBloc.currentDay);

  /// How far back and ahead Home can browse: the Diary's five years back,
  /// and a year ahead for planning.
  DateTime get _firstDay => DateTime(_today.year - 5, _today.month, _today.day);
  DateTime get _lastDay => DateTime(_today.year + 1, _today.month, _today.day);

  bool _moveDay(int delta) {
    final from = _homeBloc.viewedDay ?? _today;
    final target = DateUtils.addDaysToDate(from, delta);
    if (target.isBefore(_firstDay) || target.isAfter(_lastDay)) return false;
    _showDay(target);
    return true;
  }

  void _showDay(DateTime day) {
    final date = DateUtils.dateOnly(day);
    _homeBloc.add(
      ChangeHomeDayEvent(DateUtils.isSameDay(date, _today) ? null : date),
    );
  }

  Widget _buildDayContent(
    BuildContext context, {
    required bool isToday,
    required bool isFuture,
    required DateTime entryDay,
    required double totalKcalDaily,
    required UserGenderEntity userGender,
    required CaloriesProfileEntity? userCaloriesProfile,
    required double totalKcalLeft,
    required double totalKcalSupplied,
    required double totalKcalBurned,
    required double totalCarbsIntake,
    required double totalFatsIntake,
    required double totalProteinsIntake,
    required double totalCarbsGoal,
    required double totalFatsGoal,
    required double totalProteinsGoal,
    required List<IntakeEntity> breakfastIntakeList,
    required List<IntakeEntity> lunchIntakeList,
    required List<IntakeEntity> dinnerIntakeList,
    required List<IntakeEntity> snackIntakeList,
    required List<UserActivityEntity> userActivities,
    required bool usesImperialUnits,
    required BodyWeightUnit bodyWeightUnit,
    required bool showActivityTracking,
    required bool showMealMacros,
    required double userWeightKg,
    required double breakfastKcalTarget,
    required double lunchKcalTarget,
    required double dinnerKcalTarget,
    required double snackKcalTarget,
    required int breakfastSharePct,
    required int lunchSharePct,
    required int dinnerSharePct,
    required int snackSharePct,
    required int waterMlToday,
    required int waterGoalMl,
  }) {
    return Stack(
      children: [
        ListView(
          children: [
            // Weight, water and fasting record "now", so they show on today
            // only; other days show what was logged on them.
            if (isToday)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Dimens.spacing16,
                  Dimens.spacing16,
                  Dimens.spacing16,
                  Dimens.spacing4,
                ),
                // Wrap rather than Row so the two chips drop onto a second line
                // at large text scale instead of overflowing off the edge.
                child: Wrap(
                  spacing: Dimens.spacing12,
                  runSpacing: Dimens.spacing8,
                  children: [
                    QuickWeightWidget(
                      weightKg: userWeightKg,
                      bodyWeightUnit: bodyWeightUnit,
                    ),
                    QuickWaterWidget(
                      waterMlToday: waterMlToday,
                      waterGoalMl: waterGoalMl,
                      usesImperialUnits: usesImperialUnits,
                    ),
                  ],
                ),
              ),
            if (isToday) const FastingHomeChip(),
            if (isFuture)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Dimens.spacing16,
                  Dimens.spacing12,
                  Dimens.spacing16,
                  0,
                ),
                child: Text(
                  S.of(context).homePlanningHint,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            const SizedBox(height: Dimens.spacing8),
            DashboardWidget(
              totalKcalDaily: totalKcalDaily,
              totalKcalLeft: totalKcalLeft,
              totalKcalSupplied: totalKcalSupplied,
              totalKcalBurned: totalKcalBurned,
              totalCarbsIntake: totalCarbsIntake,
              totalFatsIntake: totalFatsIntake,
              totalProteinsIntake: totalProteinsIntake,
              totalCarbsGoal: totalCarbsGoal,
              totalFatsGoal: totalFatsGoal,
              totalProteinsGoal: totalProteinsGoal,
            ),
            // Day-one / empty-day guidance: when nothing is logged yet, point
            // the way to the centre + rather than leaving a silent dashboard.
            if (breakfastIntakeList.isEmpty &&
                lunchIntakeList.isEmpty &&
                dinnerIntakeList.isEmpty &&
                snackIntakeList.isEmpty &&
                userActivities.isEmpty)
              EmptyHint(
                icon: Icons.add_circle_outline_rounded,
                title: S.of(context).homeFirstMealHint,
              ),
            if (CalorieGoalCalc.isBelowRecommendedDailyKcalFloor(
              goalKcal: totalKcalDaily,
              gender: userGender,
              caloriesProfile: userCaloriesProfile,
            ))
              LowKcalWarningCard(
                thresholdKcal: CalorieGoalCalc.recommendedDailyKcalFloor(
                  gender: userGender,
                  caloriesProfile: userCaloriesProfile,
                ),
              ),
            if (showActivityTracking)
              ActivityVerticalList(
                day: entryDay,
                title: S.of(context).activityLabel,
                userActivityList: userActivities,
                onItemLongPressedCallback: onActivityItemLongPressed,
                onItemTappedCallback: onActivityItemTapped,
                onItemDragCallback: onActivityItemDrag,
              ),
            // #150 follow-up: a 0% share (e.g. OMAD sets snack to 0) hides an
            // empty section so the home view doesn't carry a header the user
            // explicitly opted out of. A section that holds intakes always
            // shows, so they stay editable and deletable (#1305).
            if (IntakeVerticalList.isShown(
              sharePct: breakfastSharePct,
              intakes: breakfastIntakeList,
            ))
              IntakeVerticalList(
                day: entryDay,
                title: S.of(context).breakfastLabel,
                listIcon: IntakeTypeEntity.breakfast.getIconData(),
                addMealType: AddMealType.breakfastType,
                intakeList: breakfastIntakeList,
                onDeleteIntakeCallback: onDeleteIntake,
                onItemTappedCallback: onIntakeItemTapped,
                usesImperialUnits: usesImperialUnits,
                showMealMacros: showMealMacros,
                mealKcalTarget: breakfastKcalTarget,
              ),
            if (IntakeVerticalList.isShown(
              sharePct: lunchSharePct,
              intakes: lunchIntakeList,
            ))
              IntakeVerticalList(
                day: entryDay,
                title: S.of(context).lunchLabel,
                listIcon: IntakeTypeEntity.lunch.getIconData(),
                addMealType: AddMealType.lunchType,
                intakeList: lunchIntakeList,
                onDeleteIntakeCallback: onDeleteIntake,
                onItemTappedCallback: onIntakeItemTapped,
                usesImperialUnits: usesImperialUnits,
                showMealMacros: showMealMacros,
                mealKcalTarget: lunchKcalTarget,
              ),
            if (IntakeVerticalList.isShown(
              sharePct: dinnerSharePct,
              intakes: dinnerIntakeList,
            ))
              IntakeVerticalList(
                day: entryDay,
                title: S.of(context).dinnerLabel,
                addMealType: AddMealType.dinnerType,
                listIcon: IntakeTypeEntity.dinner.getIconData(),
                intakeList: dinnerIntakeList,
                onDeleteIntakeCallback: onDeleteIntake,
                onItemTappedCallback: onIntakeItemTapped,
                usesImperialUnits: usesImperialUnits,
                showMealMacros: showMealMacros,
                mealKcalTarget: dinnerKcalTarget,
              ),
            if (IntakeVerticalList.isShown(
              sharePct: snackSharePct,
              intakes: snackIntakeList,
            ))
              IntakeVerticalList(
                day: entryDay,
                title: S.of(context).snackLabel,
                listIcon: IntakeTypeEntity.snack.getIconData(),
                addMealType: AddMealType.snackType,
                intakeList: snackIntakeList,
                onDeleteIntakeCallback: onDeleteIntake,
                onItemTappedCallback: onIntakeItemTapped,
                usesImperialUnits: usesImperialUnits,
                showMealMacros: showMealMacros,
                mealKcalTarget: snackKcalTarget,
              ),
            const SizedBox(height: 48.0),
          ],
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Visibility(
            visible: _isActivityDragging,
            child: SizedBox(
              height: 70,
              // Food entries are deleted by swiping left; only activities
              // still drop here to be deleted.
              child: DragTarget<UserActivityEntity>(
                onAcceptWithDetails: (data) {
                  _confirmDeleteActivity(context, data.data);
                },
                onLeave: (data) {
                  setState(() {
                    _isActivityDragging = false;
                  });
                },
                builder: (context, candidateData, rejectedData) {
                  return Container(
                    margin: const EdgeInsets.fromLTRB(
                      Dimens.spacing16,
                      0,
                      Dimens.spacing16,
                      Dimens.spacing12,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.error,
                      borderRadius: Dimens.borderRadiusL,
                    ),
                    child: Center(
                      child: Icon(
                        Icons.delete_rounded,
                        size: 32,
                        color: Theme.of(context).colorScheme.onError,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  void onActivityItemLongPressed(
    BuildContext context,
    UserActivityEntity activityEntity,
  ) async {
    final deleteIntake = await showDialog<bool>(
      context: context,
      builder: (context) => const DeleteDialog(),
    );

    if (deleteIntake != null) {
      await _homeBloc.deleteUserActivityItem(activityEntity);
      _homeBloc.add(const LoadItemsEvent());
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(S.of(context).itemDeletedSnackbar)),
        );
      }
    }
  }

  void onIntakeItemLongPressed(
    BuildContext context,
    IntakeEntity intakeEntity,
  ) async {
    final deleteIntake = await showDialog<bool>(
      context: context,
      builder: (context) => const DeleteDialog(),
    );

    if (deleteIntake != null) {
      // The write can wait for the tracked-day lock (#1317), and Home
      // reloads only once it is stored, so it does not show the old totals.
      await _homeBloc.deleteIntakeItem(intakeEntity);
      _homeBloc.add(const LoadItemsEvent());
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(S.of(context).itemDeletedSnackbar)),
        );
      }
    }
  }

  void onActivityItemDrag(bool isDragging) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        _isActivityDragging = isDragging;
      });
    });
  }

  void onActivityItemTapped(
    BuildContext context,
    UserActivityEntity activityEntity,
  ) async {
    final newDuration = await showDialog<double>(
      context: context,
      builder: (context) => EditActivityDialog(activityEntity: activityEntity),
    );
    if (newDuration != null) {
      await _homeBloc.updateUserActivityItem(activityEntity, newDuration);
      _homeBloc.add(const LoadItemsEvent());
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(S.of(context).itemUpdatedSnackbar)),
        );
      }
    }
  }

  void onIntakeItemTapped(
    BuildContext context,
    IntakeEntity intakeEntity,
    bool usesImperialUnits,
  ) async {
    // The full food screen, pre-filled with the entry: amount, unit and
    // meal can all change, with the nutrients updating as they do.
    final edit = await openLoggedIntakeEditor(
      context,
      intakeEntity,
      _homeBloc.viewedDay ?? DateTime.now(),
      usesImperialUnits,
    );
    if (edit != null) {
      await _homeBloc.updateIntakeItem(intakeEntity.id, edit.toUpdateFields());
      _homeBloc.add(const LoadItemsEvent());
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(S.of(context).itemUpdatedSnackbar)),
        );
      }
    }
  }

  Future<void> onDeleteIntake(
    IntakeEntity intake,
    TrackedDayEntity? trackedDayEntity,
  ) async {
    await _homeBloc.deleteIntakeItem(intake);
    _homeBloc.add(const LoadItemsEvent());
  }

  void _confirmDeleteActivity(
    BuildContext context,
    UserActivityEntity activity,
  ) async {
    final delete = await showDialog<bool>(
      context: context,
      builder: (context) => const DeleteDialog(),
    );
    if (delete == true) {
      await _homeBloc.deleteUserActivityItem(activity);
      _homeBloc.add(const LoadItemsEvent());
    }
    setState(() {
      _isActivityDragging = false;
    });
  }

  /// Show disclaimer dialog after build method
  void _showDisclaimerDialog(BuildContext context) async {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final dialogConfirmed = await showDialog<bool>(
        context: context,
        builder: (context) {
          return const DisclaimerDialog();
        },
      );
      if (dialogConfirmed != null) {
        _homeBloc.saveConfigData(dialogConfirmed);
        _homeBloc.add(const LoadItemsEvent());
      }
    });
  }

  /// Refresh page when day changes
  ///
  /// #139: HomeBloc.currentDay is the logical "today" (midnight of the
  /// configured day boundary). Comparing against a fresh logical "today"
  /// from the same wall clock requires knowing the offset, which we'd
  /// have to fetch from config asynchronously. Letting LoadItemsEvent
  /// re-resolve the offset and reload unconditionally on resume is the
  /// honest cheap path: it costs one config read plus a few Hive scans,
  /// and it is correct under any boundary setting.
  void _refreshPageOnDayChange() {
    // Home opens on today: coming back to the app leaves a browsed day.
    if (_homeBloc.viewedDay != null) {
      _homeBloc.add(const ChangeHomeDayEvent(null));
    } else {
      _homeBloc.add(const LoadItemsEvent());
    }
  }

  /// Picks up workouts that landed in the platform health store while the app
  /// was away — at launch and on every resume. Debounced, serialized and
  /// opt-in inside the use case, so this costs nothing on an ordinary resume;
  /// the diary only reloads when something actually came in. Failures are
  /// swallowed by [ImportWorkoutsUsecase.importIfDue]: there is no user
  /// waiting on this and nowhere to show an error.
  Future<void> _importHealthWorkouts() async {
    final imported = await locator<ImportWorkoutsUsecase>().importIfDue();
    if (imported == 0 || !mounted) return;
    _homeBloc.add(const LoadItemsEvent());
    locator<DiaryBloc>().add(const LoadDiaryYearEvent());
    locator<CalendarDayBloc>().add(RefreshCalendarDayEvent());
  }
}
