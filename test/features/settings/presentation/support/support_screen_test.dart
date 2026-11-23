import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:opennutritracker/core/utils/app_const.dart';
import 'package:opennutritracker/features/settings/presentation/bloc/tip_jar_cubit.dart';
import 'package:opennutritracker/features/settings/presentation/support/support_screen.dart';
import 'package:opennutritracker/generated/l10n.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:share_plus/share_plus.dart';
import 'package:share_plus_platform_interface/share_plus_platform_interface.dart';

import '../../../../helpers/fake_tip_store.dart';
import '../../../../helpers/test_l10n.dart';

class _FakeSharePlatform extends SharePlatform with MockPlatformInterfaceMixin {
  final calls = <ShareParams>[];

  @override
  Future<ShareResult> share(ShareParams params) async {
    calls.add(params);
    return const ShareResult('success', ShareResultStatus.success);
  }
}

void main() {
  late FakeTipStore store;
  late FakeTipConfig config;
  late TipJarCubit jar;
  late List<String> opened;
  late bool openResult;
  late _FakeSharePlatform sharePlatform;

  setUp(() async {
    store = FakeTipStore();
    config = FakeTipConfig();
    jar = TipJarCubit(store, config);
    opened = [];
    openResult = true;
    sharePlatform = _FakeSharePlatform();
  });

  tearDown(() async {
    await jar.close();
    await store.dispose();
  });

  Future<void> pumpPage(WidgetTester tester, {bool settle = true}) async {
    // Inside the test's zone, so purchase updates run under its fake clock.
    await jar.start();
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: S.supportedLocales,
        home: SupportScreen(
          tipJar: jar,
          sharePlus: SharePlus.custom(sharePlatform),
          openUrl: (url) async {
            opened.add(url);
            return openResult;
          },
        ),
      ),
    );
    if (settle) await tester.pumpAndSettle();
  }

  Finder byId(String id) => find.byWidgetPredicate(
    (w) => w is Semantics && w.properties.identifier == id,
  );

  Future<void> tapRow(WidgetTester tester, String id) async {
    await tester.scrollUntilVisible(byId(id), 200);
    await tester.tap(byId(id));
    await tester.pumpAndSettle();
  }

  group('layout', () {
    testWidgets('shows the header, two groups and six ways in order', (
      tester,
    ) async {
      final labels = [
        l10nEn.supportGroupSpreadWord,
        l10nEn.supportRateTitle,
        l10nEn.supportShareTitle,
        l10nEn.supportStarTitle,
        l10nEn.supportGroupSkills,
        l10nEn.supportTranslateTitle,
        l10nEn.supportReportTitle,
        l10nEn.supportCodeTitle,
      ];
      // Tall enough that the whole page is laid out at once.
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pumpPage(tester);

      final icons = [
        Icons.star_rate_rounded,
        Icons.ios_share_rounded,
        Icons.star_outline_rounded,
        Icons.translate_rounded,
        Icons.lightbulb_outline_rounded,
        Icons.code_rounded,
      ];
      double top(Finder f) => tester.getTopLeft(f).dy;
      for (var i = 1; i < labels.length; i++) {
        expect(
          top(find.text(labels[i])),
          greaterThan(top(find.text(labels[i - 1]))),
          reason: '${labels[i]} should come after ${labels[i - 1]}',
        );
      }
      for (var i = 1; i < icons.length; i++) {
        expect(
          top(find.byIcon(icons[i])),
          greaterThan(top(find.byIcon(icons[i - 1]))),
          reason: '${icons[i]} should come after ${icons[i - 1]}',
        );
      }
      expect(find.text(l10nEn.settingsSupportLabel), findsOneWidget);
      expect(find.text(l10nEn.supportHeader), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right_rounded), findsNWidgets(6));
      for (final subtitle in [
        l10nEn.supportRateSubtitle,
        l10nEn.supportShareSubtitle,
        l10nEn.supportStarSubtitle,
        l10nEn.supportTranslateSubtitle,
        l10nEn.supportReportSubtitle,
        l10nEn.supportCodeSubtitle,
      ]) {
        expect(find.text(subtitle), findsOneWidget, reason: subtitle);
      }

      for (final id in [
        'support-way-rate',
        'support-way-share',
        'support-way-star',
        'support-way-translate',
        'support-way-report',
        'support-way-code',
      ]) {
        expect(byId(id), findsOneWidget, reason: id);
      }
    });
  });

  group('links', () {
    testWidgets('each row opens its target', (tester) async {
      await pumpPage(tester);

      await tapRow(tester, 'support-way-star');
      await tapRow(tester, 'support-way-translate');
      await tapRow(tester, 'support-way-report');
      await tapRow(tester, 'support-way-code');

      expect(opened, [
        'https://github.com/MCsumz/ONT-Plus',
        'https://hosted.weblate.org/engage/opennutritracker/',
        'https://github.com/MCsumz/ONT-Plus/issues/new/choose',
        'https://github.com/MCsumz/ONT-Plus/blob/main/CONTRIBUTING.md',
      ]);
    });

    // ONT+ is not in the stores: rating it means starring its repository,
    // on either platform.
    for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
      testWidgets('Rate opens the ONT+ repository on ${platform.name}', (
        tester,
      ) async {
        debugDefaultTargetPlatformOverride = platform;
        await pumpPage(tester);

        await tapRow(tester, 'support-way-rate');

        expect(opened, ['https://github.com/MCsumz/ONT-Plus']);
        debugDefaultTargetPlatformOverride = null;
      });
    }

    testWidgets('a link that cannot open says so', (tester) async {
      openResult = false;
      await pumpPage(tester);

      await tapRow(tester, 'support-way-star');

      expect(find.text(l10nEn.errorOpeningBrowser), findsOneWidget);
    });

    testWidgets('Share sends the description and the ONT+ releases link', (
      tester,
    ) async {
      await pumpPage(tester);

      await tapRow(tester, 'support-way-share');

      final params = sharePlatform.calls.single;
      expect(params.text, startsWith(l10nEn.appDescription));
      expect(params.text, contains(AppConst.releasesUrl));
      expect(params.text, isNot(contains(AppConst.playStoreUrl)));
      expect(params.sharePositionOrigin, isNotNull);
      expect(opened, isEmpty);
    });
  });

  // The tip jar sells through the original app's store listing, which a
  // sideloaded ONT+ cannot reach, so it is not offered.
  testWidgets('the tip jar is not offered', (tester) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpPage(tester);

    expect(find.text(l10nEn.supportGroupMoney), findsNothing);
    expect(find.text(l10nEn.supportTipTitle), findsNothing);
  });
}
