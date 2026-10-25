// Package imports:
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:boorusama/boorus/sankaku/posts/types.dart';

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
}
