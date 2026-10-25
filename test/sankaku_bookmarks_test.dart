// Dart imports:
import 'dart:async';
import 'dart:typed_data';

// Package imports:
import 'package:booru_clients/sankaku.dart';
import 'package:cache_manager/cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:boorusama/boorus/e621/e621_repository.dart';
import 'package:boorusama/boorus/sankaku/bookmarks/types.dart';
import 'package:boorusama/boorus/sankaku/sankaku_repository.dart';
import 'package:boorusama/core/bookmarks/src/data/aliased_image_cache.dart';
import 'package:boorusama/core/bookmarks/types.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'riverpod_test_utils.dart';

final _now = DateTime.fromMillisecondsSinceEpoch(1792897000 * 1000);
const _past = 1792896000;
const _future = 1792900000;

String _signed(String path, int expiry) =>
    'https://s.sankakucomplex.com/$path?e=$expiry&m=abc';

Bookmark _bookmark({
  required String originalUrl,
  String sourceUrl = 'https://chan.sankakucomplex.com/post/62946932',
}) => Bookmark(
  id: 1,
  booruId: 27,
  createdAt: _now,
  updatedAt: _now,
  thumbnailUrl: originalUrl,
  sampleUrl: originalUrl,
  originalUrl: originalUrl,
  sourceUrl: sourceUrl,
  width: 100,
  height: 100,
  md5: 'md5',
  tags: const {},
  realSourceUrl: null,
  format: null,
  imageUrlResolver: const DefaultImageUrlResolver(),
  postId: null,
  metadata: const {},
);

void main() {
  group('Sankaku media URL expiry', () {
    final cases = [
      (url: _signed('o/a.jpg', _past), expected: _past),
      (
        url: 'https://v.sankakucomplex.com/x.webp?expires=$_future&m=x',
        expected: _future,
      ),
      (url: 'https://s.sankakucomplex.com/o/a.jpg', expected: null),
      (url: 'https://s.sankakucomplex.com/o/a.jpg?e=soon', expected: null),
    ];

    for (final c in cases) {
      test('reads ${c.expected} from ${c.url}', () {
        expect(
          sankakuUrlExpiry(c.url)?.millisecondsSinceEpoch,
          c.expected == null ? null : c.expected! * 1000,
        );
      });
    }
  });

  group('Sankaku post id from a post link', () {
    final cases = [
      (url: 'https://chan.sankakucomplex.com/post/62946932', id: '62946932'),
      (
        url: 'https://chan.sankakucomplex.com/posts/1QaEx8z82M9',
        id: '1QaEx8z82M9',
      ),
      (url: 'https://chan.sankakucomplex.com/post/show/123', id: '123'),
      (url: 'https://sankaku.app/posts/abc123?lang=en#top', id: 'abc123'),
      (url: 'https://chan.sankakucomplex.com/', id: null),
      (url: '', id: null),
    ];

    for (final c in cases) {
      test('finds ${c.id} in "${c.url}"', () {
        expect(sankakuIdFromSourceUrl(c.url), c.id);
      });
    }
  });

  group('Refreshing Sankaku bookmark media', () {
    test('keeps stored URLs without fetching while they are valid', () async {
      var fetched = false;
      final refresh = sankakuBookmarkMediaRefresher(
        fetchPost: (_) async {
          fetched = true;
          return null;
        },
        now: () => _now,
      );

      final result = await refresh(
        _bookmark(originalUrl: _signed('o/a.jpg', _future)),
      );

      expect(result, isNull);
      expect(fetched, isFalse);
    });

    test('fetches fresh URLs by post id once they expire', () async {
      String? requestedId;
      final refresh = sankakuBookmarkMediaRefresher(
        fetchPost: (id) async {
          requestedId = id;
          return PostDto(
            previewUrl: 'https://fresh/preview',
            sampleUrl: 'https://fresh/sample',
            fileUrl: 'https://fresh/file.jpg',
          );
        },
        now: () => _now,
      );

      final result = await refresh(
        _bookmark(originalUrl: _signed('o/a.jpg', _past)),
      );

      expect(requestedId, '62946932');
      expect(
        result,
        const BookmarkMediaUrls(
          thumbnailUrl: 'https://fresh/preview',
          sampleUrl: 'https://fresh/sample',
          originalUrl: 'https://fresh/file.jpg',
          originalCacheUrl: 'https://s.sankakucomplex.com/o/a.jpg',
        ),
      );
    });

    final unusable = [
      (
        name: 'the post link has no id',
        bookmark: _bookmark(
          originalUrl: _signed('o/a.jpg', _past),
          sourceUrl: 'https://chan.sankakucomplex.com/',
        ),
        post: PostDto(fileUrl: 'https://fresh/file.jpg'),
      ),
      (
        name: 'the refetched post has no file',
        bookmark: _bookmark(originalUrl: _signed('o/a.jpg', _past)),
        post: PostDto(),
      ),
    ];

    for (final c in unusable) {
      test('keeps stored URLs when ${c.name}', () async {
        final refresh = sankakuBookmarkMediaRefresher(
          fetchPost: (_) async => c.post,
          now: () => _now,
        );

        expect(await refresh(c.bookmark), isNull);
      });
    }
  });

  group('Where a refreshed Sankaku original is cached', () {
    final cases = [
      (
        stored: _signed('o/4f/92/abc.jpg', _past),
        expected: 'https://s.sankakucomplex.com/o/4f/92/abc.jpg',
      ),
      (
        stored: 'https://s.sankakucomplex.com/o/4f/92/abc.png',
        expected: 'https://s.sankakucomplex.com/o/4f/92/abc.png',
      ),
    ];

    for (final c in cases) {
      test('uses ${c.expected} for ${c.stored}', () {
        expect(sankakuOriginalCacheUrl(c.stored), c.expected);
      });
    }

    test('differs from a signed stored URL, whose key may hold the '
        'expired-link placeholder', () {
      final stored = _signed('o/4f/92/abc.jpg', _past);

      expect(sankakuOriginalCacheUrl(stored), isNot(stored));
    });

    test('is the same file bookmark removal clears', () async {
      final bookmark = _bookmark(originalUrl: _signed('o/a.jpg', _past));
      final container = createContainer();
      final repo = container.read(
        Provider((ref) => SankakuRepository(ref: ref)),
      );
      final refresh = sankakuBookmarkMediaRefresher(
        fetchPost: (_) async => PostDto(fileUrl: _signed('o/a.jpg', _future)),
        now: () => _now,
      );

      final refreshed = await refresh(bookmark);

      expect(
        repo.bookmarkOriginalCacheUrl(bookmark),
        refreshed?.originalCacheUrl,
      );
    });
  });

  group('Aliased bookmark image cache', () {
    final cache = AliasedImageCacheManager(
      inner: _KeyEchoCache(),
      aliases: {'https://fresh/file.jpg': 'https://stored/file.jpg'},
    );

    test('stores a refreshed URL under the stored URL key', () {
      expect(
        cache.generateCacheKey('https://fresh/file.jpg'),
        'key:https://stored/file.jpg',
      );
    });

    test('leaves other URLs keyed by themselves', () {
      expect(
        cache.generateCacheKey('https://other/file.jpg'),
        'key:https://other/file.jpg',
      );
    });
  });

  test(
    'other engines neither refresh bookmark media nor cache it elsewhere',
    () {
      final container = createContainer();
      final repo = container.read(
        Provider((ref) => E621Repository(ref: ref)),
      );
      final config = BooruConfig.defaultConfig(
        booruType: BooruType.e621,
        url: 'https://e621.net/',
        customDownloadFileNameFormat: null,
      ).auth;

      expect(repo.bookmarkMediaRefresher(config), isNull);
      expect(
        repo.bookmarkOriginalCacheUrl(
          _bookmark(originalUrl: 'https://static1.e621.net/data/a.jpg'),
        ),
        isNull,
      );
    },
  );
}

class _KeyEchoCache implements ImageCacheManager {
  @override
  String generateCacheKey(String url, {String? customKey}) =>
      customKey ?? 'key:$url';

  @override
  FutureOr<String?> getCachedFilePath(String key, {Duration? maxAge}) => null;

  @override
  FutureOr<Uint8List?> getCachedFileBytes(String key, {Duration? maxAge}) =>
      null;

  @override
  Future<void> saveFile(String key, Uint8List bytes) async {}

  @override
  FutureOr<bool> hasValidCache(String key, {Duration? maxAge}) => false;

  @override
  Future<void> clearCache(String key) async {}

  @override
  Future<void> clearAllCache() async {}

  @override
  void invalidateCacheDirectory() {}

  @override
  Future<void> dispose() async {}
}
