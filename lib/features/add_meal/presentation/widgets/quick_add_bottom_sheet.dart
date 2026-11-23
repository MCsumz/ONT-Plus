import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:logging/logging.dart';
import 'package:opennutritracker/core/utils/custom_text_input_formatter.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/domain/entity/intake_type_entity.dart';
import 'package:opennutritracker/core/domain/usecase/add_intake_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/add_tracked_day_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_kcal_goal_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_macro_goal_usecase.dart';
import 'package:opennutritracker/core/utils/calc/unit_calc.dart';
import 'package:opennutritracker/core/utils/energy_unit_provider.dart';
import 'package:opennutritracker/core/utils/id_generator.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/core/utils/navigation_options.dart';
import 'package:opennutritracker/core/utils/sheet_bottom_inset.dart';
import 'package:opennutritracker/core/utils/tracked_day_lock.dart';
import 'package:opennutritracker/core/utils/user_image_storage.dart';
import 'package:opennutritracker/features/add_meal/presentation/log_tray.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_nutriments_entity.dart';
import 'package:opennutritracker/features/diary/presentation/bloc/calendar_day_bloc.dart';
import 'package:opennutritracker/features/diary/presentation/bloc/diary_bloc.dart';
import 'package:opennutritracker/features/home/presentation/bloc/home_bloc.dart';
import 'package:opennutritracker/generated/l10n.dart';
import 'package:provider/provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

class QuickAddBottomSheet extends StatefulWidget {
  final IntakeTypeEntity intakeType;
  final DateTime day;

  /// The add-food screen's "To log" list. Once it has items, the entry goes
  /// on the list and the sheet closes, instead of logging and leaving for
  /// home — which would drop everything already on the list. While it is
  /// empty the entry is logged at once, as before the list existed, and a
  /// second button puts it on the list instead (#1520). A food still on its
  /// way onto the list counts as an item (see [LogTray.collects]).
  final LogTray? logTray;

  /// Always put the entry on [logTray], never log it on its own. For a
  /// caller with unsaved foods of its own that are not on the list yet —
  /// the review screen, whose batch joins the list only when confirmed —
  /// which logging on its own would leave and lose.
  final bool addsToListOnly;

  const QuickAddBottomSheet({
    super.key,
    required this.intakeType,
    required this.day,
    this.logTray,
    this.addsToListOnly = false,
  });

  @override
  State<QuickAddBottomSheet> createState() => _QuickAddBottomSheetState();
}

class _QuickAddBottomSheetState extends State<QuickAddBottomSheet> {
  final _log = Logger('QuickAddBottomSheet');

  final _titleController = TextEditingController();
  final _energyController = TextEditingController();
  final _carbsController = TextEditingController();
  final _fatController = TextEditingController();
  final _proteinController = TextEditingController();

  bool _saving = false;

  /// The entry's food id, fixed up front: an optional photo is stored under
  /// it, as custom foods store theirs.
  final String _mealCode = IdGenerator.getUniqueID();

  /// The photo taken or picked for this entry, relative to the app's image
  /// folder; null without one.
  String? _photoPath;

  /// [_photoPath] resolved once, so the preview does not reload (and
  /// flicker) on every keystroke.
  String? _photoFile;
  bool _pickingPhoto = false;

  /// Set once the entry is logged or listed; a photo of an entry that was
  /// not is removed when the sheet closes.
  bool _photoKept = false;

  @override
  void initState() {
    super.initState();
    _titleController.addListener(_onRequiredFieldChanged);
    _energyController.addListener(_onRequiredFieldChanged);
    // The button reads "Add" or "Add to list" from the list's state, which
    // a food arriving from a + changes while the sheet is open.
    widget.logTray?.addListener(_onTrayChanged);
  }

  @override
  void dispose() {
    final photo = _photoPath;
    if (photo != null && !_photoKept) {
      UserImageStorage.delete(photo);
    }
    widget.logTray?.removeListener(_onTrayChanged);
    _titleController.removeListener(_onRequiredFieldChanged);
    _energyController.removeListener(_onRequiredFieldChanged);
    _titleController.dispose();
    _energyController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    _proteinController.dispose();
    super.dispose();
  }

  void _onRequiredFieldChanged() => setState(() {});

  void _onTrayChanged() => setState(() {});

  double? _parsed(TextEditingController c) {
    final raw = c.text.trim().replaceAll(',', '.');
    if (raw.isEmpty) return null;
    final value = double.tryParse(raw);
    if (value == null || value < 0) return null;
    return value;
  }

  bool get _canSubmit {
    final energy = _parsed(_energyController);
    // With a photo the title is optional: snap, type the calories, done.
    final hasTitle =
        _titleController.text.trim().isNotEmpty || _photoPath != null;
    return !_saving &&
        !_pickingPhoto &&
        hasTitle &&
        energy != null &&
        energy > 0;
  }

  Future<void> _pickPhoto(ImageSource source) async {
    setState(() => _pickingPhoto = true);
    try {
      final picked = await ImagePicker().pickImage(source: source);
      if (picked == null) return;
      // Compressed and stored like a custom food's photo, under this
      // entry's food id, so a retake replaces it in place.
      final relative = await UserImageStorage.importFrom(
        kind: UserImageKind.meal,
        ownerId: _mealCode,
        sourcePath: picked.path,
      );
      final file = await UserImageStorage.absolutePath(relative);
      FileImage(File(file)).evict();
      if (mounted) {
        setState(() {
          _photoPath = relative;
          _photoFile = file;
        });
      }
    } catch (e, st) {
      _log.warning('Quick Add photo failed', e, st);
    } finally {
      if (mounted) setState(() => _pickingPhoto = false);
    }
  }

  Future<void> _removePhoto() async {
    final photo = _photoPath;
    if (photo == null) return;
    setState(() {
      _photoPath = null;
      _photoFile = null;
    });
    await UserImageStorage.delete(photo);
  }

  /// Whether the main button adds to the list rather than logging.
  bool get _addsToList {
    final logTray = widget.logTray;
    return logTray != null && (widget.addsToListOnly || logTray.collects);
  }

  Future<void> _onSubmit({bool toList = false}) async {
    if (!_canSubmit) return;
    setState(() => _saving = true);

    final usesKj = context.read<EnergyUnitProvider>().usesKilojoules;
    final enteredEnergy = _parsed(_energyController)!;
    final kcal = usesKj ? UnitCalc.kjToKcal(enteredEnergy) : enteredEnergy;
    final carbs = _parsed(_carbsController);
    final fat = _parsed(_fatController);
    final protein = _parsed(_proteinController);
    final typed = _titleController.text.trim();
    final title = typed.isNotEmpty ? typed : S.of(context).quickAddDefaultName;

    try {
      final intake = _buildIntake(
        kcal: kcal,
        carbs: carbs,
        fat: fat,
        protein: protein,
        title: title,
      );
      final logTray = widget.logTray;
      // Asked again, not taken from the press: a food that reached the list
      // since must not be left behind by logging on its own.
      if (logTray != null && (toList || _addsToList)) {
        _photoKept = true;
        logTray.add(
          LogTrayItem(
            meal: intake.meal,
            unit: intake.unit,
            amount: intake.amount,
            amountLabel: S.of(context).quickAddCardLabel,
          ),
        );
        Navigator.of(context).pop();
        return;
      }
      // The entry and its row together, so no reconciliation counts the
      // entry before the row has it (#1317).
      final saved = await withTrackedDayLockOnProfile(() async {
        await locator<AddIntakeUsecase>().addIntake(intake);
        await _updateTrackedDay(intake);
        return true;
      });
      if (saved != true) {
        if (mounted) setState(() => _saving = false);
        return;
      }
      _photoKept = true;

      locator<HomeBloc>().add(const LoadItemsEvent());
      locator<DiaryBloc>().add(const LoadDiaryYearEvent());
      locator<CalendarDayBloc>().add(RefreshCalendarDayEvent());

      if (!mounted) return;
      final mealTypeLabel = _intakeTypeLabel(context, widget.intakeType);
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      // Resolve the localized message before navigating: the push below
      // removes every route (including this sheet's), so reading from
      // context afterwards would be looking up a deactivated widget.
      final addedMessage = S.of(context).quickAddAddedSnack(mealTypeLabel);
      Navigator.of(
        context,
        rootNavigator: true,
      ).pushNamedAndRemoveUntil(NavigationOptions.mainRoute, (route) => false);
      scaffoldMessenger.showSnackBar(SnackBar(content: Text(addedMessage)));
    } catch (e, st) {
      _log.severe('Quick Add save failed', e, st);
      Sentry.captureException(e, stackTrace: st);
      if (!mounted) return;
      setState(() => _saving = false);
    }
  }

  IntakeEntity _buildIntake({
    required double kcal,
    required double? carbs,
    required double? fat,
    required double? protein,
    required String title,
  }) {
    // Store per-100g, intake amount = 100g, so totals math returns the
    // exact values the user typed.
    final nutriments = MealNutrimentsEntity(
      energyKcal100: kcal,
      carbohydrates100: carbs,
      fat100: fat,
      proteins100: protein,
      sugars100: null,
      saturatedFat100: null,
      fiber100: null,
    );
    final meal = MealEntity(
      code: _mealCode,
      name: title,
      url: null,
      mealQuantity: '100',
      mealUnit: 'gml',
      servingQuantity: null,
      servingUnit: 'gml',
      servingSize: '',
      nutriments: nutriments,
      source: MealSourceEntity.custom,
      localImagePath: _photoPath,
    );
    return IntakeEntity(
      id: IdGenerator.getUniqueID(),
      unit: 'g',
      amount: 100,
      type: widget.intakeType,
      meal: meal,
      dateTime: widget.day,
    );
  }

  Future<void> _updateTrackedDay(IntakeEntity intake) async {
    final addTrackedDay = locator<AddTrackedDayUsecase>();
    final hasTrackedDay = await addTrackedDay.hasTrackedDay(widget.day);
    if (!hasTrackedDay) {
      final kcalGoal = await locator<GetKcalGoalUsecase>().getKcalGoal();
      final macroGoal = locator<GetMacroGoalUsecase>();
      await addTrackedDay.addNewTrackedDayIfAbsent(
        widget.day,
        kcalGoal,
        await macroGoal.getCarbsGoal(kcalGoal),
        await macroGoal.getFatsGoal(kcalGoal),
        await macroGoal.getProteinsGoal(kcalGoal),
      );
    }
    await addTrackedDay.addDayCaloriesTracked(widget.day, intake.totalKcal);
    await addTrackedDay.addDayMacrosTracked(
      widget.day,
      carbsTracked: intake.totalCarbsGram,
      fatTracked: intake.totalFatsGram,
      proteinTracked: intake.totalProteinsGram,
    );
  }

  String _intakeTypeLabel(BuildContext context, IntakeTypeEntity type) {
    switch (type) {
      case IntakeTypeEntity.breakfast:
        return S.of(context).breakfastLabel;
      case IntakeTypeEntity.lunch:
        return S.of(context).lunchLabel;
      case IntakeTypeEntity.dinner:
        return S.of(context).dinnerLabel;
      case IntakeTypeEntity.snack:
        return S.of(context).snackLabel;
    }
  }

  @override
  Widget build(BuildContext context) {
    final usesKj = context.watch<EnergyUnitProvider>().usesKilojoules;
    final s = S.of(context);

    return Padding(
      padding: EdgeInsets.only(bottom: sheetBottomInset(context)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                s.quickAddBottomSheetTitle,
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
            ),
            _buildPhotoRow(context),
            _field(
              controller: _titleController,
              identifier: 'quick-add-title',
              label: s.quickAddTitleHint,
              isRequired: _photoPath == null,
              numeric: false,
              autofocus: true,
            ),
            _field(
              controller: _energyController,
              identifier: 'quick-add-energy',
              label: usesKj
                  ? s.quickAddEnergyLabelKj
                  : s.quickAddEnergyLabelKcal,
              isRequired: true,
              numeric: true,
            ),
            _field(
              controller: _carbsController,
              identifier: 'quick-add-carbs',
              label: s.quickAddCarbsHint,
              isRequired: false,
              numeric: true,
            ),
            _field(
              controller: _fatController,
              identifier: 'quick-add-fat',
              label: s.quickAddFatHint,
              isRequired: false,
              numeric: true,
            ),
            _field(
              controller: _proteinController,
              identifier: 'quick-add-protein',
              label: s.quickAddProteinHint,
              isRequired: false,
              numeric: true,
            ),
            const SizedBox(height: 16),
            Semantics(
              identifier: 'quick-add-submit',
              child: FilledButton(
                onPressed: _canSubmit
                    ? () => _onSubmit(toList: _addsToList)
                    : null,
                child: _saving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        _addsToList ? s.addToListLabel : s.quickAddSubmitLabel,
                      ),
              ),
            ),
            if (widget.logTray != null && !_addsToList) ...[
              const SizedBox(height: 8),
              Semantics(
                identifier: 'quick-add-add-to-list',
                child: OutlinedButton(
                  onPressed: _canSubmit ? () => _onSubmit(toList: true) : null,
                  child: Text(s.addToListLabel),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Take or choose a photo of the meal; once set, a thumbnail with a way
  /// to remove it.
  Widget _buildPhotoRow(BuildContext context) {
    final s = S.of(context);
    final photo = _photoPath;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          if (photo != null) ...[
            Semantics(
              identifier: 'quick-add-photo-preview',
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 56,
                      height: 56,
                      child: _photoFile == null
                          ? const SizedBox.shrink()
                          : Image.file(
                              File(_photoFile!),
                              fit: BoxFit.cover,
                              cacheWidth: 168,
                            ),
                    ),
                  ),
                  Positioned(
                    top: -10,
                    right: -10,
                    child: IconButton.filledTonal(
                      visualDensity: VisualDensity.compact,
                      iconSize: 16,
                      tooltip: s.mealImageRemove,
                      onPressed: _removePhoto,
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
          ],
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                Semantics(
                  identifier: 'quick-add-take-photo',
                  child: OutlinedButton.icon(
                    onPressed: _pickingPhoto
                        ? null
                        : () => _pickPhoto(ImageSource.camera),
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: Text(s.mealImageTakePhoto),
                  ),
                ),
                Semantics(
                  identifier: 'quick-add-choose-photo',
                  child: OutlinedButton.icon(
                    onPressed: _pickingPhoto
                        ? null
                        : () => _pickPhoto(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: Text(s.mealImagePickFromGallery),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String identifier,
    required String label,
    required bool isRequired,
    required bool numeric,
    bool autofocus = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Semantics(
        identifier: identifier,
        child: TextField(
          controller: controller,
          autofocus: autofocus,
          keyboardType: numeric
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text,
          inputFormatters: numeric
              ? CustomTextInputFormatter.doubleOnly()
              : null,
          decoration: InputDecoration(
            labelText: isRequired ? '$label *' : label,
            border: const OutlineInputBorder(),
          ),
        ),
      ),
    );
  }
}
