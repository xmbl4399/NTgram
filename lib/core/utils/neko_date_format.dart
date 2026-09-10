import 'package:intl/intl.dart';

/// Date/time formatting for the chat list and the in-chat day dividers.
///
/// Both rules are ported from Nekogram (the Telegram for Android fork this
/// client takes its visual language from) so the wording matches upstream
/// instead of being invented locally:
///
///  * [messageListDate] mirrors `LocaleController.stringForMessageListDate()`
///  * [chatDateDivider] follows `LocaleController.formatDateChat()` for the
///    date patterns, with the recent days deliberately switched to the clock
///    (today) and the weekday (last week) — see its own doc comment, it is the
///    one place where the wording deviates from upstream
///
/// The subtlety worth keeping in mind: "today" / "yesterday" are decided by a
/// **calendar day** comparison (`Calendar.DAY_OF_YEAR` upstream), not by
/// elapsed hours. A 23:50 message read the next day at 22:00 is *yesterday*
/// even though fewer than 24 hours have passed.
///
/// Two upstream behaviours that surprise people, both intentional here:
///
///  * There is no "Yesterday" label anywhere. Yesterday up to six days back
///    shows the **weekday** (`周三` / `Thu`).
///  * A one-day-old message younger than [clockGracePeriod] still shows the
///    clock, because "23:50" reads better than "周三" right after midnight.
class NekoDateFormat {
  const NekoDateFormat._();

  /// Nekogram keeps the clock for yesterday's messages younger than 8 hours
  /// (`System.currentTimeMillis() - date < 60 * 60 * 8 * 1000`).
  static const Duration clockGracePeriod = Duration(hours: 8);

  /// Anything farther than 365 days apart switches to the year pattern.
  static const Duration yearThreshold = Duration(days: 365);

  /// `dd.MM.yy` — Nekogram's `formatterYear`, e.g. `12.08.25`.
  static const String _yearPattern = 'dd.MM.yy';

  /// Timestamp shown on the right of a row in the chat/session list.
  ///
  /// * today, or yesterday younger than 8h → `23:50` (24h/12h per locale)
  /// * yesterday .. 6 days ago → `周三`
  /// * 7 .. 364 days ago → `8月31日`
  /// * 365+ days ago → `12.08.25`
  static String messageListDate(
    DateTime dateTime, {
    DateTime? now,
    String? locale,
  }) {
    final current = now ?? DateTime.now();
    final date = dateTime.toLocal();
    final age = current.difference(date);

    if (age.abs() >= yearThreshold) {
      return DateFormat(_yearPattern, locale).format(date);
    }

    final dayDiff = calendarDayDiff(current, date);
    if (dayDiff == 0 || (dayDiff == -1 && age < clockGracePeriod)) {
      return DateFormat.jm(locale).format(date);
    }
    if (dayDiff > -7 && dayDiff <= -1) {
      return DateFormat.E(locale).format(date);
    }
    return DateFormat.MMMd(locale).format(date);
  }

  /// Label of the day separator inserted inside a chat whenever the calendar
  /// day changes.
  ///
  /// Nekogram's `formatDateChat()` prints a plain date and nothing else, so a
  /// divider over yesterday's messages reads `9月9日`. That date tells the
  /// reader nothing they cannot already guess, so the recent days borrow the
  /// window from [messageListDate] instead — today is on the clock, the last
  /// week is the weekday — and everything older keeps upstream's date
  /// patterns. These are the intentional deviations from Nekogram's wording:
  ///
  /// * today → `10:00` (the clock of the day's first message, exactly like the
  ///   chat list — "今天" itself would only repeat the header)
  /// * 1 .. 6 days ago → `周三`
  /// * 7 .. 364 days ago → `9月3日` (upstream `chatDate` = `MMMM d`)
  /// * older → `2025年8月12日` (upstream `chatFullDate` = `MMMM d, yyyy`)
  static String chatDateDivider(
    DateTime dateTime, {
    DateTime? now,
    String? locale,
  }) {
    final current = now ?? DateTime.now();
    final date = dateTime.toLocal();
    final dayDiff = calendarDayDiff(current, date);
    if (dayDiff == 0) {
      return DateFormat.jm(locale).format(date);
    }
    if (dayDiff > -7 && dayDiff <= -1) {
      return DateFormat.E(locale).format(date);
    }
    if (current.difference(date).abs() < yearThreshold) {
      return DateFormat.MMMMd(locale).format(date);
    }
    return DateFormat.yMMMMd(locale).format(date);
  }

  /// Whole calendar days from [now] to [date]: `0` today, `-1` yesterday.
  ///
  /// Upstream subtracts `Calendar.DAY_OF_YEAR`, which breaks across a year
  /// boundary; comparing the truncated dates keeps the same intent and is
  /// correct on 12月31日 → 1月1日.
  static int calendarDayDiff(DateTime now, DateTime date) {
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(date.year, date.month, date.day);
    return day.difference(today).inDays;
  }

  /// Whether two timestamps fall on the same calendar day (local time).
  static bool isSameDay(DateTime a, DateTime b) {
    final localA = a.toLocal();
    final localB = b.toLocal();
    return localA.year == localB.year &&
        localA.month == localB.month &&
        localA.day == localB.day;
  }
}
