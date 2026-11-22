import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:opennutritracker/core/styles/dimens.dart';
import 'package:opennutritracker/generated/l10n.dart';

/// The day Home shows, with arrows to step through days, a tap on the date
/// to pick one, and a way back to today.
class HomeDateBar extends StatelessWidget {
  final DateTime day;
  final DateTime today;
  final bool canGoBack;
  final bool canGoForward;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onToday;
  final ValueChanged<DateTime> onPick;
  final DateTime firstDay;
  final DateTime lastDay;

  const HomeDateBar({
    super.key,
    required this.day,
    required this.today,
    required this.canGoBack,
    required this.canGoForward,
    required this.onPrevious,
    required this.onNext,
    required this.onToday,
    required this.onPick,
    required this.firstDay,
    required this.lastDay,
  });

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final offset = DateUtils.dateOnly(day).difference(today).inDays;
    final relative = switch (offset) {
      0 => s.homeDayToday,
      -1 => s.homeDayYesterday,
      1 => s.homeDayTomorrow,
      _ => null,
    };
    final locale = Localizations.localeOf(context).toLanguageTag();
    final date = DateFormat.MMMEd(locale).format(day);
    final isToday = offset == 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Dimens.spacing4,
        Dimens.spacing8,
        Dimens.spacing4,
        0,
      ),
      child: Row(
        children: [
          Semantics(
            identifier: 'home-previous-day',
            child: IconButton(
              tooltip: s.homePreviousDayLabel,
              onPressed: canGoBack ? onPrevious : null,
              icon: const Icon(Icons.chevron_left_rounded),
            ),
          ),
          Expanded(
            child: Semantics(
              identifier: 'home-pick-day',
              button: true,
              child: InkWell(
                borderRadius: Dimens.borderRadiusM,
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: day,
                    firstDate: firstDay,
                    lastDate: lastDay,
                  );
                  if (picked != null) onPick(picked);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: Dimens.spacing4,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        relative ?? date,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: isToday ? null : theme.colorScheme.primary,
                        ),
                      ),
                      if (relative != null)
                        Text(
                          date,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (!isToday)
            Semantics(
              identifier: 'home-back-to-today',
              child: TextButton(
                onPressed: onToday,
                child: Text(s.homeBackToTodayLabel),
              ),
            ),
          Semantics(
            identifier: 'home-next-day',
            child: IconButton(
              tooltip: s.homeNextDayLabel,
              onPressed: canGoForward ? onNext : null,
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ),
        ],
      ),
    );
  }
}
