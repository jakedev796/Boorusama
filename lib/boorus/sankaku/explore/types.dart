// Package imports:
import 'package:intl/intl.dart';

// Project imports:
import '../../../core/posts/explores/types.dart';

enum SankakuExploreOrder {
  popularity,
  quality,
}

/// Sankaku's `date:` range excludes its end day, so every range ends the day
/// after the last day it should include.
String sankakuExploreQuery({
  required SankakuExploreOrder order,
  required TimeScale scale,
  required DateTime date,
}) {
  final day = DateTime(date.year, date.month, date.day);
  final (start, end) = switch (scale) {
    TimeScale.day => (day, day.add(const Duration(days: 1))),
    TimeScale.week => (
      day.subtract(const Duration(days: 6)),
      day.add(const Duration(days: 1)),
    ),
    TimeScale.month => (
      DateTime(day.year, day.month),
      DateTime(day.year, day.month + 1),
    ),
  };
  final format = DateFormat('yyyy-MM-dd');

  return 'order:${order.name} date:${format.format(start)}..${format.format(end)}';
}
