import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/features/home/presentation/widgets/home_day_swiper.dart';

void main() {
  /// Hosts the swiper the way Home does: an accepted move shows the new
  /// day, which slides in.
  Future<List<int>> pump(
    WidgetTester tester, {
    bool allow = true,
    bool deliver = true,
  }) async {
    final moves = <int>[];
    var day = DateTime(2026, 11, 22);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => HomeDaySwiper(
              day: day,
              onChangeDay: (delta) {
                moves.add(delta);
                if (allow && deliver) {
                  setState(() => day = day.add(Duration(days: delta)));
                }
                return allow;
              },
              child: const SizedBox.expand(child: Text('day content')),
            ),
          ),
        ),
      ),
    );
    return moves;
  }

  testWidgets('swiping left moves forward a day, right moves back', (
    tester,
  ) async {
    final moves = await pump(tester);
    await tester.drag(find.text('day content'), const Offset(-500, 0));
    await tester.pumpAndSettle();
    await tester.drag(find.text('day content'), const Offset(500, 0));
    await tester.pumpAndSettle();
    expect(moves, [1, -1]);
  });

  testWidgets('a short drag springs back without changing the day', (
    tester,
  ) async {
    final moves = await pump(tester);
    await tester.timedDrag(
      find.text('day content'),
      const Offset(-60, 0),
      const Duration(milliseconds: 600),
    );
    await tester.pumpAndSettle();
    expect(moves, isEmpty);
    expect(
      tester.getTopLeft(find.text('day content')).dx,
      0,
      reason: 'the page is back in place',
    );
  });

  testWidgets('a refused move springs back', (tester) async {
    final moves = await pump(tester, allow: false);
    await tester.drag(find.text('day content'), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(moves, [1]);
    expect(tester.getTopLeft(find.text('day content')).dx, 0);
  });

  testWidgets('a day that never arrives does not leave Home off screen', (
    tester,
  ) async {
    final moves = await pump(tester, deliver: false);
    await tester.drag(find.text('day content'), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(moves, [1]);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('day content')).dx, 0);
  });
}
