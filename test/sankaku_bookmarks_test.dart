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
import 'package:boorusama/core/bookmarks/providers.dart';
import 'package:boorusama/core/bookmarks/src/data/aliased_image_cache.dart';
import 'package:boorusama/core/bookmarks/src/data/bookmark_convert.dart';
import 'package:boorusama/core/bookmarks/src/data/bookmark_tile_media.dart';
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
  String? sampleUrl,
  String? thumbnailUrl,
  String? format,
  String sourceUrl = 'https://chan.sankakucomplex.com/post/62946932',
}) => Bookmark(
  id: 1,
  booruId: 27,
  createdAt: _now,
  updatedAt: _now,
  thumbnailUrl: thumbnailUrl ?? originalUrl,
  sampleUrl: sampleUrl ?? originalUrl,
  originalUrl: originalUrl,
  sourceUrl: sourceUrl,
  width: 100,
  height: 100,
  md5: 'md5',
  tags: const {},
  realSourceUrl: null,
  format: format,
  imageUrlResolver: const DefaultImageUrlResolver(),
  postId: null,
  metadata: const {},
);

BookmarkMediaUrls _urls({DateTime? expiresAt, String tag = 'a'}) =>
    BookmarkMediaUrls(
      thumbnailUrl: 'https://fresh/$tag/preview.avif',
      sampleUrl: 'https://fresh/$tag/sample.webp',
      originalUrl: 'https://fresh/$tag/file.jpg',
      cacheAliases: {'https://fresh/$tag/file.jpg': 'https://stable/file.jpg'},
      expiresAt: expiresAt,
    );

SankakuBookmarkMediaRefresher _sankaku({
  Future<PostDto?> Function(String id)? fetchPost,
}) => SankakuBookmarkMediaRefresher(
  fetchPost: fetchPost ?? (_) async => null,
  now: () => _now,
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

  group('Whether a Sankaku bookmark needs fresh media', () {
    final cases = [
      (name: 'expired', url: _signed('o/a.jpg', _past), expected: true),
      (name: 'still valid', url: _signed('o/a.jpg', _future), expected: false),
      (
        name: 'unsigned',
        url: 'https://s.sankakucomplex.com/o/a.jpg',
        expected: false,
      ),
    ];

    for (final c in cases) {
      test('is ${c.expected} when the stored URLs are ${c.name}', () {
        expect(
          _sankaku().needsRefresh(_bookmark(originalUrl: c.url)),
          c.expected,
        );
      });
    }
  });

  group('Refreshing Sankaku bookmark media', () {
    test('keeps stored URLs without fetching while they are valid', () async {
      var fetched = false;
      final refresher = _sankaku(
        fetchPost: (_) async {
          fetched = true;
          return null;
        },
      );

      final result = await refresher.refresh(
        _bookmark(originalUrl: _signed('o/a.jpg', _future)),
      );

      expect(result, isNull);
      expect(fetched, isFalse);
    });

    test('fetches fresh URLs by post id once they expire', () async {
      String? requestedId;
      final refresher = _sankaku(
        fetchPost: (id) async {
          requestedId = id;
          return PostDto(
            previewUrl: 'https://v.x/preview.avif?e=${_future + 10}',
            sampleUrl: 'https://v.x/sample.webp?e=$_future',
            fileUrl: 'https://s.x/file.jpg?e=${_future + 20}',
          );
        },
      );

      final result = await refresher.refresh(
        _bookmark(
          originalUrl: _signed('o/a.jpg', _past),
          sampleUrl: 'https://v.sankakucomplex.com/s.webp?e=$_past',
          thumbnailUrl: 'https://v.sankakucomplex.com/p.avif?e=$_past',
        ),
      );

      expect(requestedId, '62946932');
      expect(
        result,
        BookmarkMediaUrls(
          thumbnailUrl: 'https://v.x/preview.avif?e=${_future + 10}',
          sampleUrl: 'https://v.x/sample.webp?e=$_future',
          originalUrl: 'https://s.x/file.jpg?e=${_future + 20}',
          cacheAliases: const {
            'https://s.x/file.jpg?e=${_future + 20}':
                'https://s.sankakucomplex.com/o/a.jpg',
            'https://v.x/sample.webp?e=$_future':
                'https://v.sankakucomplex.com/s.webp',
            'https://v.x/preview.avif?e=${_future + 10}':
                'https://v.sankakucomplex.com/p.avif',
          },
          expiresAt: DateTime.fromMillisecondsSinceEpoch(_future * 1000),
        ),
      );
    });

    test('stores a shared fresh URL where the larger file goes', () async {
      final refresher = _sankaku(
        fetchPost: (_) async => PostDto(fileUrl: 'https://s.x/file.jpg'),
      );

      final result = await refresher.refresh(
        _bookmark(
          originalUrl: _signed('o/a.jpg', _past),
          thumbnailUrl: 'https://v.sankakucomplex.com/p.avif?e=$_past',
        ),
      );

      expect(result?.cacheAliases, {
        'https://s.x/file.jpg': 'https://s.sankakucomplex.com/o/a.jpg',
      });
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
        final refresher = _sankaku(fetchPost: (_) async => c.post);

        expect(await refresher.refresh(c.bookmark), isNull);
      });
    }
  });

  group('Where refreshed Sankaku media is cached', () {
    test('uses the stored URL without its signature', () {
      expect(
        sankakuStableCacheUrl(_signed('o/4f/92/abc.jpg', _past)),
        'https://s.sankakucomplex.com/o/4f/92/abc.jpg',
      );
    });

    test('is what bookmark removal clears', () async {
      final bookmark = _bookmark(
        originalUrl: _signed('o/a.jpg', _past),
        sampleUrl: 'https://v.sankakucomplex.com/s.webp?e=$_past',
        thumbnailUrl: 'https://v.sankakucomplex.com/p.avif?e=$_past',
      );
      final container = createContainer();
      final repo = container.read(
        Provider((ref) => SankakuRepository(ref: ref)),
      );
      final refreshed = await _sankaku(
        fetchPost: (_) async => PostDto(
          previewUrl: 'https://v.x/p.avif?e=$_future',
          sampleUrl: 'https://v.x/s.webp?e=$_future',
          fileUrl: 'https://s.x/f.jpg?e=$_future',
        ),
      ).refresh(bookmark);

      expect(
        repo.bookmarkStableCacheUrls(bookmark).toSet(),
        refreshed?.cacheAliases.values.toSet(),
      );
    });
  });

  test('ordinary images are not taken for the expired-link placeholder', () {
    expect(
      isSankakuExpiredPlaceholder(Uint8List.fromList([137, 80, 78, 71])),
      isFalse,
    );
  });

  group('Aliased bookmark image cache', () {
    late _RecordingCache inner;
    late AliasedImageCacheManager cache;

    setUp(() {
      inner = _RecordingCache();
      cache = AliasedImageCacheManager(
        inner: inner,
        aliases: {'https://fresh/file.jpg': 'https://stable/file.jpg'},
        rejectSave: (bytes) => bytes.first == 0,
      );
    });

    test('stores a refreshed URL under its stable key', () {
      expect(
        cache.generateCacheKey('https://fresh/file.jpg'),
        'key:https://stable/file.jpg',
      );
    });

    test('leaves other URLs keyed by themselves', () {
      expect(
        cache.generateCacheKey('https://other/file.jpg'),
        'key:https://other/file.jpg',
      );
    });

    test('never stores rejected bytes', () async {
      await cache.saveFile('k', Uint8List.fromList([0, 1]));
      await cache.saveFile('k', Uint8List.fromList([1, 1]));

      expect(inner.saved, ['k:1']);
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
        repo.bookmarkStableCacheUrls(
          _bookmark(originalUrl: 'https://static1.e621.net/data/a.jpg'),
        ),
        isEmpty,
      );
    },
  );

  group('Bookmark media state', () {
    final bookmark = _bookmark(originalUrl: _signed('o/a.jpg', _past));

    ProviderContainer containerWith(_FakeRefresher? refresher) =>
        createContainer(
          overrides: [
            bookmarkMediaRefresherProvider.overrideWith((ref, _) => refresher),
          ],
        );

    test('uses stored URLs for engines without a refresher', () {
      final container = containerWith(null);

      expect(
        container.read(bookmarkMediaProvider(bookmark)),
        isA<BookmarkMediaStored>(),
      );
    });

    test('uses stored URLs without refreshing while they are valid', () {
      final refresher = _FakeRefresher(needs: false);
      final container = containerWith(refresher);

      expect(
        container.read(bookmarkMediaProvider(bookmark)),
        isA<BookmarkMediaStored>(),
      );
      expect(refresher.calls, 0);
    });

    test('is refreshing until fresh URLs arrive', () async {
      final container = containerWith(
        _FakeRefresher(results: [() async => _urls()]),
      );
      container.listen(bookmarkMediaProvider(bookmark), (_, _) {});

      expect(
        container.read(bookmarkMediaProvider(bookmark)),
        isA<BookmarkMediaRefreshing>(),
      );
      await container.read(bookmarkMediaFetchProvider(bookmark).future);
      expect(
        container.read(bookmarkMediaProvider(bookmark)),
        isA<BookmarkMediaRefreshed>().having((m) => m.urls, 'urls', _urls()),
      );
    });

    test('falls back to stored URLs when the first refresh fails', () async {
      final container = containerWith(
        _FakeRefresher(results: [() async => throw Exception('offline')]),
      );
      container.listen(bookmarkMediaProvider(bookmark), (_, _) {});

      await container.read(bookmarkMediaFetchProvider(bookmark).future);

      expect(
        container.read(bookmarkMediaProvider(bookmark)),
        isA<BookmarkMediaStored>(),
      );
    });
  });

  group('Renewing refreshed bookmark media', () {
    final bookmark = _bookmark(originalUrl: _signed('o/a.jpg', _past));
    const renewal = BookmarkMediaRenewal(
      renewMargin: Duration.zero,
      minRenewDelay: Duration(milliseconds: 500),
    );

    ProviderContainer containerWith(_FakeRefresher refresher) {
      final container = createContainer(
        overrides: [
          bookmarkMediaRefresherProvider.overrideWith((ref, _) => refresher),
          bookmarkMediaRenewalProvider.overrideWithValue(renewal),
        ],
      );
      container.listen(bookmarkMediaProvider(bookmark), (_, _) {});
      return container;
    }

    DateTime inMs(int ms) => DateTime.now().add(Duration(milliseconds: ms));

    test('refreshes again shortly before the fresh URLs expire', () async {
      final refresher = _FakeRefresher(
        results: [
          () async => _urls(expiresAt: inMs(1000)),
          () async => _urls(expiresAt: inMs(60000), tag: 'b'),
        ],
      );
      containerWith(refresher);

      await Future<void>.delayed(const Duration(seconds: 2));

      expect(refresher.calls, 2);
    });

    test('does not loop when fresh URLs are already about to expire', () async {
      final refresher = _FakeRefresher(
        results: [() async => _urls(expiresAt: inMs(100))],
      );
      containerWith(refresher);

      await Future<void>.delayed(const Duration(seconds: 2));

      expect(refresher.calls, 1);
    });

    test('keeps showing fresh URLs while renewing them', () async {
      final renewed = Completer<BookmarkMediaUrls?>();
      final container = containerWith(
        _FakeRefresher(
          results: [
            () async => _urls(expiresAt: inMs(700)),
            () => renewed.future,
          ],
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 1000));

      expect(
        container.read(bookmarkMediaProvider(bookmark)),
        isA<BookmarkMediaRefreshed>().having(
          (m) => m.urls.originalUrl,
          'original',
          _urls().originalUrl,
        ),
      );
      renewed.complete(null);
    });

    final failures =
        <({String name, Future<BookmarkMediaUrls?> Function() result})>[
          (name: 'finds nothing', result: () async => null),
          (name: 'fails', result: () async => throw Exception('offline')),
        ];

    for (final f in failures) {
      test(
        'keeps the previous URLs and retries when renewal ${f.name}',
        () async {
          final refresher = _FakeRefresher(
            results: [
              () async => _urls(expiresAt: inMs(700)),
              f.result,
              () async => _urls(expiresAt: inMs(60000), tag: 'b'),
            ],
          );
          final container = containerWith(refresher);
          final seen = <BookmarkMedia>[];
          container.listen(
            bookmarkMediaProvider(bookmark),
            (_, next) => seen.add(next),
          );

          await Future<void>.delayed(const Duration(milliseconds: 1000));

          expect(
            container.read(bookmarkMediaProvider(bookmark)),
            isA<BookmarkMediaRefreshed>().having(
              (m) => m.urls.originalUrl,
              'original',
              _urls().originalUrl,
            ),
          );
          expect(seen.whereType<BookmarkMediaStored>(), isEmpty);

          await Future<void>.delayed(const Duration(milliseconds: 800));

          expect(refresher.calls, 3);
        },
      );
    }
  });

  group('Renewal across a provider lifetime', () {
    final bookmark = _bookmark(originalUrl: _signed('o/a.jpg', _past));

    ProviderContainer containerWith(
      _FakeRefresher refresher,
      BookmarkMediaRenewal renewal,
    ) => createContainer(
      overrides: [
        bookmarkMediaRefresherProvider.overrideWith((ref, _) => refresher),
        bookmarkMediaRenewalProvider.overrideWithValue(renewal),
      ],
    );

    DateTime inMs(int ms) => DateTime.now().add(Duration(milliseconds: ms));
    const renewal = BookmarkMediaRenewal(
      renewMargin: Duration.zero,
      minRenewDelay: Duration(milliseconds: 200),
    );

    test(
      'renewal from a closed screen does not disturb a reopened one',
      () async {
        final refresher = _FakeRefresher(
          results: [
            () async => _urls(expiresAt: inMs(600)),
            () async => _urls(expiresAt: inMs(1500), tag: 'b'),
            () async => _urls(expiresAt: inMs(60000), tag: 'c'),
          ],
        );
        final container = containerWith(refresher, renewal);
        final sub = container.listen(
          bookmarkMediaProvider(bookmark),
          (_, _) {},
        );
        await container.read(bookmarkMediaFetchProvider(bookmark).future);
        sub.close();
        await Future<void>.delayed(const Duration(milliseconds: 50));
        container.listen(bookmarkMediaProvider(bookmark), (_, _) {});

        await Future<void>.delayed(const Duration(milliseconds: 2200));

        expect(
          container.read(bookmarkMediaProvider(bookmark)),
          isA<BookmarkMediaRefreshed>().having(
            (m) => m.urls.originalUrl,
            'original',
            _urls(tag: 'c').originalUrl,
          ),
        );
      },
    );

    test(
      'a refresh abandoned mid-flight does not stop later renewals',
      () async {
        final refresher = _FakeRefresher(
          results: [
            () async {
              await Future<void>.delayed(const Duration(milliseconds: 300));
              return _urls(expiresAt: inMs(800));
            },
            () async => _urls(expiresAt: inMs(1500), tag: 'b'),
            () async => _urls(expiresAt: inMs(60000), tag: 'c'),
          ],
        );
        final container = containerWith(refresher, renewal);
        container.listen(bookmarkMediaProvider(bookmark), (_, _) {}).close();
        await Future<void>.delayed(const Duration(milliseconds: 50));
        container.listen(bookmarkMediaProvider(bookmark), (_, _) {});

        await Future<void>.delayed(const Duration(milliseconds: 2200));

        expect(
          container.read(bookmarkMediaProvider(bookmark)),
          isA<BookmarkMediaRefreshed>().having(
            (m) => m.urls.originalUrl,
            'original',
            _urls(tag: 'c').originalUrl,
          ),
        );
      },
    );

    test(
      'never shows media as refreshing during a scheduled renewal',
      () async {
        const margined = BookmarkMediaRenewal(
          renewMargin: Duration(milliseconds: 400),
          minRenewDelay: Duration(milliseconds: 200),
        );
        final container = containerWith(
          _FakeRefresher(
            results: [
              () async => _urls(expiresAt: inMs(1600)),
              () async {
                await Future<void>.delayed(const Duration(milliseconds: 100));
                return _urls(expiresAt: inMs(60000), tag: 'b');
              },
            ],
          ),
          margined,
        );
        container.listen(bookmarkMediaProvider(bookmark), (_, _) {});
        await container.read(bookmarkMediaFetchProvider(bookmark).future);

        final shown = <BookmarkMedia>[];
        for (var i = 0; i < 36; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          shown.add(
            bookmarkMediaForDisplay(
              container.read(bookmarkMediaProvider(bookmark)),
              now: DateTime.now(),
              renewal: margined,
              isFetching: container
                  .read(bookmarkMediaFetchProvider(bookmark))
                  .isLoading,
            ).media,
          );
        }

        expect(shown.whereType<BookmarkMediaRefreshing>(), isEmpty);
        expect(
          shown.last,
          isA<BookmarkMediaRefreshed>().having(
            (m) => m.urls.originalUrl,
            'original',
            _urls(tag: 'b').originalUrl,
          ),
        );
      },
    );
  });

  group('Showing refreshed bookmark media', () {
    const renewal = BookmarkMediaRenewal();
    final fetchedAt = _now.subtract(const Duration(hours: 2));

    final cases = [
      (
        name: 'URLs that are still valid',
        expiresAt: _now.add(const Duration(minutes: 30)),
        isFetching: false,
        refreshing: false,
        refetch: false,
      ),
      (
        name: 'URLs that expired while held',
        expiresAt: _now.subtract(const Duration(minutes: 1)),
        isFetching: false,
        refreshing: true,
        refetch: true,
      ),
      (
        name: 'expired URLs already being renewed',
        expiresAt: _now.subtract(const Duration(minutes: 1)),
        isFetching: true,
        refreshing: true,
        refetch: false,
      ),
    ];

    for (final c in cases) {
      test('treats ${c.name} as refreshing: ${c.refreshing}', () {
        final result = bookmarkMediaForDisplay(
          BookmarkMediaRefreshed(
            _urls(expiresAt: c.expiresAt),
            fetchedAt: fetchedAt,
          ),
          now: _now,
          renewal: renewal,
          isFetching: c.isFetching,
        );

        expect(result.media is BookmarkMediaRefreshing, c.refreshing);
        expect(result.refetch, c.refetch);
      });
    }

    test('waits before refetching URLs it only just received', () {
      final result = bookmarkMediaForDisplay(
        BookmarkMediaRefreshed(
          _urls(expiresAt: _now.subtract(const Duration(minutes: 1))),
          fetchedAt: _now,
        ),
        now: _now,
        renewal: renewal,
        isFetching: false,
      );

      expect(result.refetch, isFalse);
    });
  });

  group('What a bookmark tile shows', () {
    final image = _bookmark(
      originalUrl: _signed('o/a.jpg', _past),
      sampleUrl: 'https://v.sankakucomplex.com/s.webp?e=$_past',
    ).toPost();
    final video = _bookmark(
      originalUrl: _signed('o/v.mp4', _past),
      thumbnailUrl: 'https://v.sankakucomplex.com/p.avif?e=$_past',
      format: '.mp4',
    ).toPost();
    final refreshed = BookmarkMediaRefreshed(_urls(), fetchedAt: _now);

    test('requests nothing while refreshing', () {
      final media = bookmarkTileMedia(const BookmarkMediaRefreshing(), image);

      expect(media.imageUrl, '');
      expect(media.cacheAliases, isNull);
    });

    test('uses the stored sample for images', () {
      expect(
        bookmarkTileMedia(const BookmarkMediaStored(), image).imageUrl,
        image.sampleImageUrl,
      );
    });

    final freshCases = [
      (name: 'image', post: image, url: _urls().sampleUrl),
      (name: 'video', post: video, url: _urls().thumbnailUrl),
    ];

    for (final c in freshCases) {
      test('shows the fresh URL with its cache aliases for an ${c.name}', () {
        final media = bookmarkTileMedia(refreshed, c.post);

        expect(media.imageUrl, c.url);
        expect(media.initialThumbnailUrl, c.url);
        expect(media.cacheAliases, _urls().cacheAliases);
      });
    }
  });
}

class _FakeRefresher implements BookmarkMediaRefresher {
  _FakeRefresher({
    this.needs = true,
    List<Future<BookmarkMediaUrls?> Function()>? results,
  }) : _results = results ?? [];

  final bool needs;
  final List<Future<BookmarkMediaUrls?> Function()> _results;
  var calls = 0;

  @override
  bool needsRefresh(Bookmark bookmark) => needs;

  @override
  Future<BookmarkMediaUrls?> refresh(Bookmark bookmark) {
    final index = calls++;
    return index < _results.length ? _results[index]() : Future.value();
  }

  @override
  bool isExpiredPlaceholder(Uint8List bytes) => false;
}

class _RecordingCache implements ImageCacheManager {
  final saved = <String>[];

  @override
  String generateCacheKey(String url, {String? customKey}) =>
      customKey ?? 'key:$url';

  @override
  FutureOr<String?> getCachedFilePath(String key, {Duration? maxAge}) => null;

  @override
  FutureOr<Uint8List?> getCachedFileBytes(String key, {Duration? maxAge}) =>
      null;

  @override
  Future<void> saveFile(String key, Uint8List bytes) async =>
      saved.add('$key:${bytes.first}');

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
