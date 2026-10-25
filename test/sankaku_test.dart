// Package imports:
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:boorusama/boorus/sankaku/explore/types.dart';
import 'package:boorusama/boorus/sankaku/posts/types.dart';
import 'package:boorusama/core/posts/explores/types.dart';

void main() {
  group('Hiding posts in books', () {
    final cases = [
      (tags: <String>[], hidden: true),
      (tags: ['blue_eyes', 'order:popularity'], hidden: true),
      (tags: ['-pool:abc'], hidden: true),
      (tags: ['pool:abc'], hidden: false),
      (tags: ['blue_eyes', 'fav:someone'], hidden: false),
    ];

    for (final c in cases) {
      test('hides book pages is ${c.hidden} for "${c.tags.join(' ')}"', () {
        expect(shouldHidePostsInBooks(c.tags), c.hidden);
      });
    }
  });

  group('Explore query', () {
    final cases = [
      (
        scale: TimeScale.day,
        date: DateTime(2026, 10, 22, 18, 30),
        range: 'date:2026-10-22..2026-10-23',
      ),
      (
        scale: TimeScale.week,
        date: DateTime(2026, 10, 3),
        range: 'date:2026-09-27..2026-10-04',
      ),
      (
        scale: TimeScale.month,
        date: DateTime(2026, 12, 15),
        range: 'date:2026-12-01..2027-01-01',
      ),
    ];

    for (final c in cases) {
      test('covers ${c.range} for a ${c.scale.name} ending ${c.date}', () {
        expect(
          sankakuExploreQuery(
            order: SankakuExploreOrder.popularity,
            scale: c.scale,
            date: c.date,
          ),
          'order:popularity ${c.range}',
        );
      });
    }

    test('sorts top rated posts by quality', () {
      expect(
        sankakuExploreQuery(
          order: SankakuExploreOrder.quality,
          scale: TimeScale.day,
          date: DateTime(2026, 10, 22),
        ),
        startsWith('order:quality '),
      );
    });
  });
}
