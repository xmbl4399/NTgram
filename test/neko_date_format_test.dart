import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:native_tavern/core/utils/neko_date_format.dart';

/// Pins the ported Nekogram date rules. The interesting cases are the ones a
/// naive implementation gets wrong, so they are all listed explicitly:
///
///  * the calendar-day test (not elapsed hours) for "yesterday"
///  * the 8 hour grace period that keeps yesterday's clock
///  * the absence of a "Yesterday" label — the weekday is shown instead
///  * the calendar-week boundary at 7 days
///  * the 365 day switch to the year pattern
///  * the in-chat divider borrowing the list's recency ladder — today on the
///    clock, the last week on the weekday — which upstream does not do
///  * 12月31日 → 1月1日, where upstream's `DAY_OF_YEAR` subtraction breaks
void main() {
  setUpAll(() async {
    await initializeDateFormatting();
  });

  // A Thursday evening — the same clock reading as the reported bug report.
  final now = DateTime(2026, 9, 10, 22, 0);

  String list(DateTime date) =>
      NekoDateFormat.messageListDate(date, now: now, locale: 'zh');

  group('messageListDate (chat list)', () {
    test('today shows the clock', () {
      expect(list(DateTime(2026, 9, 10, 9, 30)), '09:30');
      expect(list(DateTime(2026, 9, 10, 22, 0)), '22:00');
    });

    test('yesterday older than 8h shows the weekday, never "昨天"', () {
      // 23:50 the previous evening read at 22:00 the next day: 22h apart, but
      // one calendar day back — the old `inDays` check called this "today".
      expect(list(DateTime(2026, 9, 9, 23, 50)), '周三');
    });

    test('yesterday younger than 8h keeps the clock', () {
      // Read just after midnight: last night's late messages stay on the clock
      // because "22:50" tells the reader more than "周三" does.
      final afterMidnight = DateTime(2026, 9, 10, 0, 30);
      expect(
        NekoDateFormat.messageListDate(
          DateTime(2026, 9, 9, 22, 50),
          now: afterMidnight,
          locale: 'zh',
        ),
        '22:50',
      );
      // Same calendar day difference, but 26h old — outside the grace period.
      expect(list(DateTime(2026, 9, 9, 20, 0)), '周三');
    });

    test('within six days shows the weekday', () {
      expect(list(DateTime(2026, 9, 4, 12, 0)), '周五'); // 6 days back
      expect(list(DateTime(2026, 9, 8, 12, 0)), '周二'); // 2 days back
    });

    test('seven days back switches to the date', () {
      expect(list(DateTime(2026, 9, 3, 12, 0)), '9月3日');
      expect(list(DateTime(2026, 8, 31, 12, 0)), '8月31日');
    });

    test('beyond 365 days uses the year pattern', () {
      expect(list(DateTime(2025, 8, 12, 12, 0)), '12.08.25');
    });

    test('yesterday across a year boundary is still yesterday', () {
      final newYear = DateTime(2026, 1, 1, 10, 0);
      expect(
        NekoDateFormat.messageListDate(
          DateTime(2025, 12, 31, 9, 0),
          now: newYear,
          locale: 'zh',
        ),
        '周三',
      );
    });

    test('english locale uses its own time and weekday style', () {
      // intl separates the clock from AM/PM with U+202F, so normalise it.
      String normalise(String value) => value.replaceAll('\u202f', ' ');
      expect(
        normalise(
          NekoDateFormat.messageListDate(
            DateTime(2026, 9, 10, 9, 30),
            now: now,
            locale: 'en',
          ),
        ),
        '9:30 AM',
      );
      expect(
        NekoDateFormat.messageListDate(
          DateTime(2026, 9, 9, 23, 50),
          now: now,
          locale: 'en',
        ),
        'Wed',
      );
    });
  });

  group('chatDateDivider (in-chat day separator)', () {
    String divider(DateTime date) =>
        NekoDateFormat.chatDateDivider(date, now: now, locale: 'zh');

    test('today is on the clock, not the date', () {
      // The divider sits above today's first message, so it carries that
      // message's clock — same reading as the chat list.
      expect(divider(DateTime(2026, 9, 10, 9, 30)), '09:30');
      expect(divider(DateTime(2026, 9, 10, 0, 5)), '00:05');
    });

    test('the last six days show the weekday', () {
      // Nekogram prints `9月9日` here; the weekday is a deliberate deviation.
      expect(divider(DateTime(2026, 9, 9, 23, 50)), '周三');
      expect(divider(DateTime(2026, 9, 8, 12, 0)), '周二');
      expect(divider(DateTime(2026, 9, 4, 12, 0)), '周五');
    });

    test('seven days and older fall back to the date', () {
      expect(divider(DateTime(2026, 9, 3, 12, 0)), '9月3日');
      expect(divider(DateTime(2026, 8, 31, 23, 0)), '8月31日');
    });

    test('older than a year carries the year', () {
      expect(divider(DateTime(2025, 8, 12, 12, 0)), '2025年8月12日');
    });
  });

  group('helpers', () {
    test('calendarDayDiff counts days, not hours', () {
      expect(
        NekoDateFormat.calendarDayDiff(now, DateTime(2026, 9, 10, 0, 5)),
        0,
      );
      expect(
        NekoDateFormat.calendarDayDiff(now, DateTime(2026, 9, 9, 23, 55)),
        -1,
      );
    });

    test('isSameDay compares the local calendar day', () {
      expect(
        NekoDateFormat.isSameDay(
          DateTime(2026, 9, 10, 0, 1),
          DateTime(2026, 9, 10, 23, 59),
        ),
        isTrue,
      );
      expect(
        NekoDateFormat.isSameDay(
          DateTime(2026, 9, 10, 23, 59),
          DateTime(2026, 9, 11, 0, 1),
        ),
        isFalse,
      );
    });
  });
}
