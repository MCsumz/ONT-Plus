import 'package:flutter/material.dart';
import 'package:opennutritracker/core/domain/entity/tracked_day_entity.dart';
import 'package:opennutritracker/core/presentation/widgets/app_card.dart';
import 'package:opennutritracker/core/styles/app_palette.dart';
import 'package:opennutritracker/core/styles/dimens.dart';
import 'package:opennutritracker/core/utils/energy_display.dart';
import 'package:opennutritracker/core/utils/extensions.dart';
import 'package:opennutritracker/generated/l10n.dart';
import 'package:table_calendar/table_calendar.dart';

class DiaryTableCalendar extends StatefulWidget {
  final Function(DateTime, Map<String, TrackedDayEntity>) onDateSelected;
  final Duration calendarDurationDays;
  final DateTime focusedDate;
  final DateTime currentDate;
  final DateTime selectedDate;

  final Map<String, TrackedDayEntity> trackedDaysMap;

  /// The keys of the days with at least one entry logged. Only these are
  /// marked: a row can outlive its day's entries, kept for its goals.
  final Set<String> daysWithEntries;

  const DiaryTableCalendar({
    super.key,
    required this.onDateSelected,
    required this.calendarDurationDays,
    required this.focusedDate,
    required this.currentDate,
    required this.selectedDate,
    required this.trackedDaysMap,
    required this.daysWithEntries,
  });

  @override
  State<DiaryTableCalendar> createState() => _DiaryTableCalendarState();
}

/// What one line of [style] actually needs at the current text scale.
///
/// Measured rather than scaled from the package's 16.0: that constant only
/// equals a heading's height by coincidence — it is `labelSmall`'s line
/// height today — and scaling it lands fractionally short at some scales
/// (20.8 against the 21.0 wanted at 1.3x), which clips just as surely.
double _weekdayRowHeight(BuildContext context, TextStyle style) =>
    (TextPainter(
      // Any single line measures the same: the height comes from the font's
      // metrics, not from which glyphs are in it.
      text: TextSpan(text: 'Mon', style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout())
        .height;

class _DiaryTableCalendarState extends State<DiaryTableCalendar> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = isDark ? AppPalette.dark : AppPalette.light;
    final accent = Theme.of(context).colorScheme.primary;
    final textTheme = Theme.of(context).textTheme;
    final weekdayStyle =
        textTheme.labelSmall?.copyWith(color: palette.textMuted) ??
            const TextStyle();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Dimens.spacing16,
        Dimens.spacing8,
        Dimens.spacing16,
        Dimens.spacing4,
      ),
      child: AppCard(
        padding: const EdgeInsets.fromLTRB(
          Dimens.spacing8,
          Dimens.spacing12,
          Dimens.spacing8,
          Dimens.spacing12,
        ),
        child: TableCalendar(
          // Without this, `table_calendar` falls back to `en_US` and the
          // month header, day-of-week headings and selected-day label stay
          // English while the rest of the Diary follows the app locale
          // (#1442). `GlobalMaterialLocalizations` is wired in `main.dart`,
          // so the intl date symbols for every supported locale are already
          // loaded by the time this builds.
          locale: Localizations.localeOf(context).toLanguageTag(),
          headerStyle: HeaderStyle(
            titleCentered: true,
            formatButtonVisible: false,
            titleTextStyle: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: palette.textStrong,
                ) ??
                const TextStyle(),
            leftChevronIcon: Icon(
              Icons.chevron_left_rounded,
              color: palette.textMuted,
              size: 26,
              semanticLabel: S.of(context).calendarPreviousMonthLabel,
            ),
            rightChevronIcon: Icon(
              Icons.chevron_right_rounded,
              color: palette.textMuted,
              size: 26,
              semanticLabel: S.of(context).calendarNextMonthLabel,
            ),
            headerPadding: const EdgeInsets.symmetric(vertical: Dimens.spacing8),
          ),
          daysOfWeekStyle: DaysOfWeekStyle(
            weekdayStyle: weekdayStyle,
            weekendStyle: weekdayStyle,
          ),
          // The package default is a flat 16.0, and `labelSmall` is 11sp on a
          // 1.45 line height — exactly 16 logical pixels. So the row has no
          // slack at all at the default text size, and every step above it
          // cuts the headings: 21px of text in 16 at 1.3x, 32 in 16 at 2x.
          //
          // Nothing throws and no overflow stripes appear, because each
          // heading sits in a `SizedBox` of this height, and a tight
          // constraint squeezes its child rather than overflowing (#766).
          daysOfWeekHeight: _weekdayRowHeight(context, weekdayStyle),
          // Taller than the package's 52 so each logged day has room for its
          // net +/- value under the date.
          rowHeight: 60,
          focusedDay: widget.focusedDate,
          // The package marks DateTime.now() as today unless told
          // otherwise; the Diary's today is the logical day (#1360).
          currentDay: widget.currentDate,
          firstDay: widget.currentDate.subtract(widget.calendarDurationDays),
          lastDay: widget.currentDate.add(widget.calendarDurationDays),
          startingDayOfWeek: StartingDayOfWeek.monday,
          onDaySelected: (selectedDay, focusedDay) {
            widget.onDateSelected(selectedDay, widget.trackedDaysMap);
          },
          calendarStyle: CalendarStyle(
            markersMaxCount: 1,
            defaultTextStyle: textTheme.bodyMedium?.copyWith(color: palette.textStrong) ?? const TextStyle(),
            weekendTextStyle: textTheme.bodyMedium?.copyWith(color: palette.textStrong) ?? const TextStyle(),
            outsideTextStyle: textTheme.bodyMedium?.copyWith(color: palette.textMuted) ?? const TextStyle(),
            todayTextStyle: textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: accent,
                ) ??
                const TextStyle(),
            todayDecoration: BoxDecoration(
              border: Border.all(color: accent, width: 2.0),
              shape: BoxShape.circle,
            ),
            selectedTextStyle: textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onPrimary,
                ) ??
                const TextStyle(),
            selectedDecoration: BoxDecoration(
              color: accent,
              shape: BoxShape.circle,
            ),
          ),
          selectedDayPredicate: (day) => isSameDay(widget.selectedDate, day),
          calendarBuilders: CalendarBuilders(
            markerBuilder: (context, date, events) {
              final key = date.toParsedDay();
              final trackedDay = widget.trackedDaysMap[key];
              // A day with nothing logged gets no marker, even with a row
              // that keeps its goals (#1440). Asked of the entries, not the
              // row's totals: a zero-calorie entry still counts as logged,
              // and a deleted entry can leave a rounding residue behind.
              if (trackedDay != null && widget.daysWithEntries.contains(key)) {
                return _NetKcalMarker(trackedDay: trackedDay);
              } else {
                return const SizedBox();
              }
            },
          ),
        ),
      ),
    );
  }
}

/// The day's net balance under its date: "+350" still left under the goal,
/// "\u2212200" over it. The goal already includes that day's activities.
class _NetKcalMarker extends StatelessWidget {
  final TrackedDayEntity trackedDay;

  const _NetKcalMarker({required this.trackedDay});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final net = EnergyDisplay.displayValue(
      context,
      trackedDay.calorieGoal - trackedDay.caloriesTracked,
    );
    final isOver = net < 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          '${isOver ? '\u2212' : '+'}${net.abs()}',
          maxLines: 1,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontSize: 9.5,
                height: 1.0,
                fontWeight: FontWeight.w700,
                color: isOver ? colorScheme.error : colorScheme.primary,
              ),
        ),
      ),
    );
  }
}
