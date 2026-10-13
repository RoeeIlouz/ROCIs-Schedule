import 'package:intl/intl.dart';
import 'package:rocis_schedule/shared/l10n/app_localizations.dart';
import 'package:rocis_schedule/shared/models/schedule_models.dart';

String formatClockTime(DateTime t, {required bool use24HourFormat}) =>
    use24HourFormat ? DateFormat.Hm().format(t) : DateFormat.jm().format(t);

/// When an event happens, as one line: "09:00 - 10:30", "All day",
/// "Oct 13 - Oct 15" for an all-day span, or "Oct 13, 22:00 - Oct 14, 02:00"
/// for a timed event that runs past midnight.
String formatEventTimeRange(
  ScheduleEvent event,
  AppLocalizations l10n, {
  required bool use24HourFormat,
}) {
  String time(DateTime t) =>
      formatClockTime(t, use24HourFormat: use24HourFormat);
  final day = DateFormat.MMMd();
  if (event.allDay) {
    if (!event.isMultiDay) return l10n.translate('all_day');
    return '${day.format(event.startDay)} - ${day.format(event.endDay)}';
  }
  if (event.isMultiDay) {
    return '${day.format(event.startTime)}, ${time(event.startTime)} - '
        '${day.format(event.endTime)}, ${time(event.endTime)}';
  }
  return '${time(event.startTime)} - ${time(event.endTime)}';
}

/// "Day 2 of 3" for a multi-day event shown on [date]; null otherwise.
String? formatDayOfSpan(
  ScheduleEvent event,
  DateTime date,
  AppLocalizations l10n,
) {
  if (!event.isMultiDay) return null;
  final total = _daysBetween(event.startDay, event.endDay) + 1;
  final index = _daysBetween(event.startDay, date) + 1;
  if (index < 1 || index > total) return null;
  return l10n
      .translate('day_of_span')
      .replaceAll('{day}', '$index')
      .replaceAll('{total}', '$total');
}

/// Calendar days from [a] to [b], unaffected by daylight-saving shifts.
int _daysBetween(DateTime a, DateTime b) => DateTime.utc(
  b.year,
  b.month,
  b.day,
).difference(DateTime.utc(a.year, a.month, a.day)).inDays;
