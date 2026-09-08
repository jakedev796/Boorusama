// Package imports:
import 'package:booru_clients/pixiv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

// Project imports:
import 'package:boorusama/boorus/pixiv/ranking/providers.dart';
import 'package:boorusama/core/posts/explores/types.dart';

void main() {
  group('JST-yesterday computation', () {
    final cases = [
      (
        description: 'a UTC instant that is still the previous JST day',
        // 2024-03-10 12:00 UTC -> 2024-03-10 21:00 JST, so JST-yesterday is
        // 03-09 -- same calendar date on both sides once the +9h is added.
        nowUtc: DateTime.utc(2024, 3, 10, 12),
        expected: DateTime.utc(2024, 3, 9),
      ),
      (
        description:
            'a UTC instant just before midnight that has already rolled '
            'into the next JST day',
        // 2024-03-10 23:00 UTC -> 2024-03-11 08:00 JST: UTC and JST
        // disagree about today's date, so JST-yesterday must be 03-10, not
        // 03-09.
        nowUtc: DateTime.utc(2024, 3, 10, 23),
        expected: DateTime.utc(2024, 3, 10),
      ),
      (
        description: 'a UTC instant just after JST midnight',
        // 2024-03-10 15:30 UTC -> 2024-03-11 00:30 JST.
        nowUtc: DateTime.utc(2024, 3, 10, 15, 30),
        expected: DateTime.utc(2024, 3, 10),
      ),
      (
        description: 'a JST year boundary crossed while UTC is still last year',
        // 2023-12-31 20:00 UTC -> 2024-01-01 05:00 JST.
        nowUtc: DateTime.utc(2023, 12, 31, 20),
        expected: DateTime.utc(2023, 12, 31),
      ),
    ];

    for (final c in cases) {
      test('returns ${c.expected} for ${c.description}', () {
        expect(pixivRankingNewestDate(now: c.nowUtc), c.expected);
      });
    }
  });

  group('ranking date clamping', () {
    final now = DateTime.utc(2024, 3, 10, 12); // JST-yesterday: 2024-03-09
    final newest = DateTime.utc(2024, 3, 9);
    final earliest = DateTime.utc(2007, 9, 13);

    final cases = [
      (
        description: 'a date after the newest available snapshot',
        input: DateTime.utc(2024, 3, 15),
        expected: newest,
      ),
      (
        description: 'a date before pixiv launched',
        input: DateTime.utc(1999),
        expected: earliest,
      ),
      (
        description: 'a date inside the valid window',
        input: DateTime.utc(2020, 6),
        expected: DateTime.utc(2020, 6),
      ),
      (
        description: 'the newest-available boundary itself',
        input: newest,
        expected: newest,
      ),
      (
        description: 'the earliest-valid boundary itself',
        input: earliest,
        expected: earliest,
      ),
    ];

    for (final c in cases) {
      test('clamps to ${c.expected} for ${c.description}', () {
        expect(clampPixivRankingDate(c.input, now: now), c.expected);
      });
    }
  });

  group('newest-snapshot detection', () {
    final now = DateTime.utc(2024, 3, 10, 12); // JST-yesterday: 2024-03-09
    final newest = DateTime.utc(2024, 3, 9);

    final cases = [
      (description: 'the newest available date', input: newest, expected: true),
      (
        description: 'a date after the newest available date',
        input: DateTime.utc(2024, 3, 20),
        expected: true,
      ),
      (
        description: 'a date before the newest available date',
        input: DateTime.utc(2024, 3, 8),
        expected: false,
      ),
    ];

    for (final c in cases) {
      test('is ${c.expected} for ${c.description}', () {
        expect(isPixivRankingNewestDate(c.input, now: now), c.expected);
      });
    }
  });

  group('TimeScale to ranking mode mapping', () {
    final cases = [
      (scale: TimeScale.day, expected: PixivRankingMode.day),
      (scale: TimeScale.week, expected: PixivRankingMode.week),
      (scale: TimeScale.month, expected: PixivRankingMode.month),
    ];

    for (final c in cases) {
      test('maps ${c.scale} to ${c.expected}', () {
        expect(pixivRankingModeFrom(c.scale), c.expected);
      });
    }
  });

  group('ranking request date parameter', () {
    final now = DateTime.utc(2024, 3, 10, 12); // JST-yesterday: 2024-03-09
    final newest = DateTime.utc(2024, 3, 9);

    test('is omitted when the selected date is the newest snapshot', () {
      expect(pixivRankingRequestDateFor(newest, now: now), isNull);
    });

    test('is omitted for a date beyond the newest snapshot too', () {
      expect(
        pixivRankingRequestDateFor(DateTime.utc(2024, 3, 20), now: now),
        isNull,
      );
    });

    test('is present and formatted YYYY-MM-DD for an earlier date', () {
      final result = pixivRankingRequestDateFor(
        DateTime.utc(2020, 6),
        now: now,
      );

      expect(result, isNotNull);
      expect(DateFormat('yyyy-MM-dd').format(result!), '2020-06-01');
    });
  });

  group('ranking page offset formula', () {
    final cases = [
      (page: 1, expected: 0),
      (page: 2, expected: 30),
      (page: 5, expected: 120),
    ];

    for (final c in cases) {
      test('offset is ${c.expected} for page ${c.page}', () {
        expect(pixivRankingOffsetFor(c.page), c.expected);
      });
    }
  });
}
