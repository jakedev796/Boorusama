// Package imports:
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:boorusama/core/posts/explores/types.dart';
import 'package:boorusama/core/posts/explores/widgets.dart';

void main() {
  group('stepping a date within a bounded range', () {
    final cases = [
      (
        description: 'a date well inside the range, day scale',
        date: DateTime.utc(2024, 6, 15),
        scale: TimeScale.day,
        firstDate: DateTime.utc(2024),
        lastDate: DateTime.utc(2024, 12, 31),
        canStepForward: true,
        canStepBack: true,
      ),
      (
        description: 'exactly at the last-date boundary, day scale',
        date: DateTime.utc(2024, 12, 31),
        scale: TimeScale.day,
        firstDate: DateTime.utc(2024),
        lastDate: DateTime.utc(2024, 12, 31),
        canStepForward: false,
        canStepBack: true,
      ),
      (
        description: 'exactly at the first-date boundary, day scale',
        date: DateTime.utc(2024),
        scale: TimeScale.day,
        firstDate: DateTime.utc(2024),
        lastDate: DateTime.utc(2024, 12, 31),
        canStepForward: true,
        canStepBack: false,
      ),
      (
        description: 'one day short of the last-date boundary',
        date: DateTime.utc(2024, 12, 30),
        scale: TimeScale.day,
        firstDate: DateTime.utc(2024),
        lastDate: DateTime.utc(2024, 12, 31),
        canStepForward: true,
        canStepBack: true,
      ),
      (
        description: 'one day past the first-date boundary',
        date: DateTime.utc(2024, 1, 2),
        scale: TimeScale.day,
        firstDate: DateTime.utc(2024),
        lastDate: DateTime.utc(2024, 12, 31),
        canStepForward: true,
        canStepBack: true,
      ),
      (
        description: 'a single-day range with nowhere to step either way',
        date: DateTime.utc(2024, 6, 15),
        scale: TimeScale.day,
        firstDate: DateTime.utc(2024, 6, 15),
        lastDate: DateTime.utc(2024, 6, 15),
        canStepForward: false,
        canStepBack: false,
      ),
      (
        description: 'a date well inside the range, month scale',
        date: DateTime.utc(2024, 6, 15),
        scale: TimeScale.month,
        firstDate: DateTime.utc(2024),
        lastDate: DateTime.utc(2024, 12, 31),
        canStepForward: true,
        canStepBack: true,
      ),
      (
        description: 'stepping a month forward would cross the last date',
        date: DateTime.utc(2024, 12, 15),
        scale: TimeScale.month,
        firstDate: DateTime.utc(2024),
        lastDate: DateTime.utc(2024, 12, 31),
        canStepForward: false,
        canStepBack: true,
      ),
      (
        description: 'a date well inside the range, week scale',
        date: DateTime.utc(2024, 6),
        scale: TimeScale.week,
        firstDate: DateTime.utc(2024),
        lastDate: DateTime.utc(2024, 12, 31),
        canStepForward: true,
        canStepBack: true,
      ),
      (
        description: 'a time-of-day component on all three dates is ignored',
        date: DateTime.utc(2024, 12, 31, 23, 59),
        scale: TimeScale.day,
        firstDate: DateTime.utc(2024, 1, 1, 6),
        lastDate: DateTime.utc(2024, 12, 31, 0, 1),
        canStepForward: false,
        canStepBack: true,
      ),
    ];

    for (final c in cases) {
      test('forward is ${c.canStepForward} for ${c.description}', () {
        expect(
          canStepDateTime(
            date: c.date,
            scale: c.scale,
            forward: true,
            firstDate: c.firstDate,
            lastDate: c.lastDate,
          ),
          c.canStepForward,
        );
      });

      test('backward is ${c.canStepBack} for ${c.description}', () {
        expect(
          canStepDateTime(
            date: c.date,
            scale: c.scale,
            forward: false,
            firstDate: c.firstDate,
            lastDate: c.lastDate,
          ),
          c.canStepBack,
        );
      });
    }
  });
}
