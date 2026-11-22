import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:opennutritracker/core/data/data_source/remote_search_cache_data_source.dart';
import 'package:opennutritracker/core/data/dbo/meal_dbo.dart';
import 'package:opennutritracker/core/domain/entity/app_theme_entity.dart';
import 'package:opennutritracker/core/domain/entity/config_entity.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/domain/entity/intake_type_entity.dart';
import 'package:opennutritracker/core/domain/entity/tracked_day_entity.dart';
import 'package:opennutritracker/core/domain/usecase/add_intake_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/add_tracked_day_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_config_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_intake_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_kcal_goal_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_macro_goal_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_tracked_day_usecase.dart';
import 'package:opennutritracker/core/utils/energy_unit_provider.dart';
import 'package:opennutritracker/features/add_meal/data/repository/products_repository.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_nutriments_entity.dart';
import 'package:opennutritracker/features/add_meal/presentation/bloc/favourite_toggle_bloc.dart';
import 'package:opennutritracker/features/diary/presentation/bloc/calendar_day_bloc.dart';
import 'package:opennutritracker/features/diary/presentation/bloc/diary_bloc.dart';
import 'package:opennutritracker/features/home/presentation/bloc/home_bloc.dart';
import 'package:opennutritracker/features/meal_detail/meal_detail_screen.dart';
import 'package:opennutritracker/features/meal_detail/presentation/bloc/meal_detail_bloc.dart';
import 'package:opennutritracker/generated/l10n.dart';
import 'package:provider/provider.dart';
import '../../helpers/fake_favourites.dart';

import '../../helpers/test_l10n.dart';

// Tapping a logged entry opens the food detail screen pre-filled with it;
// the button saves amount, unit and meal back instead of logging anew.

const _nutriments = MealNutrimentsEntity(
  energyKcal100: 100,
  carbohydrates100: 10,
  fat100: 5,
  proteins100: 5,
  sugars100: 2,
  saturatedFat100: 1,
  fiber100: 1,
);

MealEntity _solidWithServing() => MealEntity(
      code: 'edit-entry-solid',
      name: 'Oat bar',
      url: null,
      mealQuantity: '100',
      mealUnit: 'g',
      servingQuantity: 30,
      servingUnit: 'g',
      servingSize: '30 g',
      nutriments: _nutriments,
      source: MealSourceEntity.custom,
    );

IntakeEntity _logged({required double amount, required String unit}) =>
    IntakeEntity(
      id: 'entry-1',
      unit: unit,
      amount: amount,
      type: IntakeTypeEntity.breakfast,
      meal: _solidWithServing(),
      dateTime: DateTime(2026, 9, 14, 8),
    );

void main() {
  final getIt = GetIt.instance;

  setUp(() {
    getIt.registerLazySingleton<MealDetailBloc>(
      () => MealDetailBloc(
        _FakeAddIntakeUsecase(),
        _FakeAddTrackedDayUsecase(),
        _FakeGetKcalGoalUsecase(),
        _FakeGetMacroGoalUsecase(),
        _FakeGetTrackedDayUsecase(),
        _FakeProductsRepository(() => null),
        _FakeRemoteSearchCacheDataSource(),
      ),
    );
    getIt.registerLazySingleton<GetConfigUsecase>(
      () => _FakeGetConfigUsecase(() => false),
    );
    getIt.registerLazySingleton<GetIntakeUsecase>(_FakeGetIntakeUsecase.new);
    getIt.registerLazySingleton<CacheManager>(_FakeCacheManager.new);
    final favourites = FakeFavourites();
    getIt.registerFactory<FavouriteToggleBloc>(
      () => FavouriteToggleBloc(favourites.get, favourites.toggle),
    );
    getIt.registerLazySingleton<HomeBloc>(_FakeHomeBloc.new);
    getIt.registerLazySingleton<DiaryBloc>(_FakeDiaryBloc.new);
    getIt.registerLazySingleton<CalendarDayBloc>(_FakeCalendarDayBloc.new);
  });

  tearDown(() async {
    await getIt.reset();
  });

  /// Opens [entry] for editing from a host page, as Home and the Diary do,
  /// and returns a getter for what the editor handed back.
  Future<LoggedIntakeEdit? Function()> openEditor(
    WidgetTester tester,
    IntakeEntity entry,
  ) async {
    tester.view.physicalSize = const Size(600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    LoggedIntakeEdit? result;
    await tester.pumpWidget(
      ChangeNotifierProvider<EnergyUnitProvider>(
        create: (_) => EnergyUnitProvider(),
        child: MaterialApp(
          localizationsDelegates: const [S.delegate],
          supportedLocales: S.supportedLocales,
          onGenerateRoute: (settings) => MaterialPageRoute(
            settings: settings,
            builder: (_) => const MealDetailScreen(),
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async => result = await openLoggedIntakeEditor(
                  context,
                  entry,
                  DateTime(2026, 9, 14),
                  false,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return () => result;
  }

  Finder quantityField() => find.byType(TextFormField).first;

  String quantityText(WidgetTester tester) =>
      tester.widget<TextFormField>(quantityField()).controller!.text;

  Future<void> save(WidgetTester tester) async {
    await tester.ensureVisible(find.text(l10nEn.saveChangesLabel));
    await tester.tap(find.text(l10nEn.saveChangesLabel));
    await tester.pumpAndSettle();
  }

  testWidgets('opens pre-filled in the logged unit, with Save instead of Add',
      (tester) async {
    await openEditor(tester, _logged(amount: 60, unit: 'serving'));

    expect(quantityText(tester), '2', reason: '60 g is two 30 g servings');
    expect(find.text(l10nEn.saveChangesLabel), findsOneWidget);
    expect(find.text(l10nEn.addLabel), findsNothing);
    expect(find.text(l10nEn.editLoggedEntryMealLabel), findsOneWidget);
    // 2 x 30 g at 100 kcal/100 g.
    expect(find.text('60 ${l10nEn.kcalLabel}'), findsWidgets);
  });

  testWidgets('saving untouched keeps the exact amount, and moves the meal',
      (tester) async {
    final result = await openEditor(
      tester,
      _logged(amount: 61.234, unit: 'serving'),
    );

    await tester.tap(find.text(l10nEn.lunchLabel));
    await tester.pumpAndSettle();
    await save(tester);

    final edit = result()!;
    expect(edit.amount, 61.234, reason: 'not the rounded 2.04 servings');
    expect(edit.unit, 'serving');
    expect(edit.type, IntakeTypeEntity.lunch);
  });

  testWidgets('a changed amount is saved in grams', (tester) async {
    final result = await openEditor(tester, _logged(amount: 60, unit: 'serving'));

    await tester.enterText(quantityField(), '3');
    await tester.pumpAndSettle();
    await save(tester);

    final edit = result()!;
    expect(edit.amount, 90);
    expect(edit.unit, 'serving');
    expect(edit.type, IntakeTypeEntity.breakfast);
  });

  testWidgets('a unit the food no longer offers falls back to grams',
      (tester) async {
    await openEditor(tester, _logged(amount: 45, unit: 'serving#2'));

    expect(quantityText(tester), '45');
  });

  testWidgets('backing out hands back nothing', (tester) async {
    final result = await openEditor(tester, _logged(amount: 60, unit: 'g'));

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(result(), isNull);
  });
}

class _FakeGetConfigUsecase implements GetConfigUsecase {
  final bool Function() defaultToRawFoodUnitsProvider;

  _FakeGetConfigUsecase(this.defaultToRawFoodUnitsProvider);

  @override
  Future<ConfigEntity> getConfig() async {
    return ConfigEntity(
      true,
      true,
      false,
      AppThemeEntity.system,
      defaultToRawFoodUnits: defaultToRawFoodUnitsProvider(),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('Unexpected call: ${invocation.memberName}');
}

class _FakeAddIntakeUsecase implements AddIntakeUsecase {
  @override
  Future<void> addIntake(IntakeEntity intakeEntity) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('Unexpected call: ${invocation.memberName}');
}

class _FakeAddTrackedDayUsecase implements AddTrackedDayUsecase {
  @override
  Future<bool> hasTrackedDay(DateTime day) async => true;

  @override
  Future<void> addDayCaloriesTracked(DateTime day, double kcal) async {}

  @override
  Future<void> addDayMacrosTracked(
    DateTime day, {
    double? carbsTracked,
    double? fatTracked,
    double? proteinTracked,
  }) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('Unexpected call: ${invocation.memberName}');
}

class _FakeGetKcalGoalUsecase implements GetKcalGoalUsecase {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('Unexpected call: ${invocation.memberName}');
}

class _FakeGetMacroGoalUsecase implements GetMacroGoalUsecase {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('Unexpected call: ${invocation.memberName}');
}

class _FakeGetTrackedDayUsecase implements GetTrackedDayUsecase {
  @override
  Future<TrackedDayEntity?> getTrackedDay(DateTime day) async =>
      TrackedDayEntity(
        day: day,
        calorieGoal: 2200,
        caloriesTracked: 800,
        carbsGoal: 250,
        carbsTracked: 100,
        fatGoal: 70,
        fatTracked: 30,
        proteinGoal: 120,
        proteinTracked: 50,
      );

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('Unexpected call: ${invocation.memberName}');
}

class _FakeProductsRepository implements ProductsRepository {
  final MealEntity? Function() hydratedProvider;

  _FakeProductsRepository(this.hydratedProvider);

  @override
  Future<MealEntity> getOFFProductByBarcode(
    String barcode, {
    String? knownName,
  }) async {
    final hydrated = hydratedProvider();
    if (hydrated == null) {
      throw StateError('No hydrated product configured for barcode $barcode');
    }
    return hydrated;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('Unexpected call: ${invocation.memberName}');
}

class _FakeRemoteSearchCacheDataSource implements RemoteSearchCacheDataSource {
  @override
  Future<void> touch(String barcode) async {}

  @override
  MealDBO? getDetailedByBarcode(String barcode) => null;

  @override
  Future<void> cache(MealDBO meal) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('Unexpected call: ${invocation.memberName}');
}

class _FakeGetIntakeUsecase implements GetIntakeUsecase {
  @override
  Future<List<IntakeEntity>> getBreakfastIntakeByDay(
    DateTime day, {
    int dayStartOffsetHours = 0,
    int dayStartOffsetMinutes = 0,
  }) async =>
      [];

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('Unexpected call: ${invocation.memberName}');
}

class _FakeHomeBloc implements HomeBloc {
  @override
  void add(HomeEvent event) {}

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('Unexpected call: ${invocation.memberName}');
}

class _FakeDiaryBloc implements DiaryBloc {
  @override
  void add(DiaryEvent event) {}

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('Unexpected call: ${invocation.memberName}');
}

class _FakeCalendarDayBloc implements CalendarDayBloc {
  @override
  void add(CalendarDayEvent event) {}

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('Unexpected call: ${invocation.memberName}');
}

class _FakeCacheManager implements CacheManager {
  @override
  Stream<FileResponse> getFileStream(
    String url, {
    String? key,
    Map<String, String>? headers,
    bool withProgress = false,
  }) =>
      const Stream<FileResponse>.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('Unexpected call: ${invocation.memberName}');
}
