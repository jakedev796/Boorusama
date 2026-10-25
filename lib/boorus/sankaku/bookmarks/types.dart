// Dart imports:
import 'dart:typed_data';

// Package imports:
import 'package:booru_clients/sankaku.dart';
import 'package:crypto/crypto.dart';

// Project imports:
import '../../../core/bookmarks/types.dart';

/// When a signed Sankaku media URL stops working, read from its `e` (or
/// `expires`) query parameter in epoch seconds.
DateTime? sankakuUrlExpiry(String url) {
  final params = Uri.tryParse(url)?.queryParameters ?? const {};
  final seconds = int.tryParse(params['e'] ?? params['expires'] ?? '');

  return switch (seconds) {
    final s? => DateTime.fromMillisecondsSinceEpoch(s * 1000),
    null => null,
  };
}

final _postPathPattern = RegExp(r'/posts?/(?:show/)?([A-Za-z0-9]+)/?$');

/// The post id in a Sankaku post page link such as `/post/123`,
/// `/posts/1QaEx8z82M9` or `/post/show/123`.
String? sankakuIdFromSourceUrl(String url) {
  final path = Uri.tryParse(url)?.path;
  if (path == null) return null;

  return _postPathPattern.firstMatch(path)?.group(1);
}

/// Where refreshed media for a stored URL is cached: the stored URL without
/// its signature, which stays the same however often Sankaku re-signs the
/// file. Expired files redirect to an "expired link" image that may already
/// be cached under the signed URL, so that key can't be reused.
String sankakuStableCacheUrl(String storedUrl) => storedUrl.split('?').first;

/// The cache URLs refreshed media of a bookmark can be stored under.
Iterable<String> sankakuStableCacheUrls(Bookmark bookmark) => {
  sankakuStableCacheUrl(bookmark.originalUrl),
  sankakuStableCacheUrl(bookmark.sampleUrl),
  sankakuStableCacheUrl(bookmark.thumbnailUrl),
};

// sha1 of https://chan.sankakucomplex.com/expired.png, the image expired
// original URLs redirect to.
const _kExpiredPlaceholderSha1 = 'afc469a87439f73495d6a1ec7837970e29bf72ac';

bool isSankakuExpiredPlaceholder(Uint8List bytes) =>
    sha1.convert(bytes).toString() == _kExpiredPlaceholderSha1;

// Refresh slightly early so a URL doesn't expire between check and download.
const _kExpiryMargin = Duration(minutes: 1);

class SankakuBookmarkMediaRefresher implements BookmarkMediaRefresher {
  SankakuBookmarkMediaRefresher({
    required this.fetchPost,
    this.now = DateTime.now,
  });

  final Future<PostDto?> Function(String id) fetchPost;
  final DateTime Function() now;

  @override
  bool needsRefresh(Bookmark bookmark) {
    final deadline = now().add(_kExpiryMargin);

    return [
      bookmark.thumbnailUrl,
      bookmark.sampleUrl,
      bookmark.originalUrl,
    ].map(sankakuUrlExpiry).nonNulls.any((e) => !e.isAfter(deadline));
  }

  @override
  Future<BookmarkMediaUrls?> refresh(Bookmark bookmark) async {
    if (!needsRefresh(bookmark)) return null;

    final id = sankakuIdFromSourceUrl(bookmark.sourceUrl);
    if (id == null) return null;

    final post = await fetchPost(id);
    final original = post?.fileUrl;
    if (original == null || original.isEmpty) return null;

    final sample = post?.sampleUrl ?? original;
    final thumbnail = post?.previewUrl ?? sample;

    // Inserted from largest to smallest, so when two fresh URLs are the same
    // file the larger one's cache location wins.
    final aliases = <String, String>{}
      ..putIfAbsent(original, () => sankakuStableCacheUrl(bookmark.originalUrl))
      ..putIfAbsent(sample, () => sankakuStableCacheUrl(bookmark.sampleUrl))
      ..putIfAbsent(
        thumbnail,
        () => sankakuStableCacheUrl(bookmark.thumbnailUrl),
      );

    final expiries = [
      original,
      sample,
      thumbnail,
    ].map(sankakuUrlExpiry).nonNulls;

    return BookmarkMediaUrls(
      thumbnailUrl: thumbnail,
      sampleUrl: sample,
      originalUrl: original,
      cacheAliases: aliases,
      expiresAt: expiries.isEmpty
          ? null
          : expiries.reduce((a, b) => a.isBefore(b) ? a : b),
    );
  }

  @override
  bool isExpiredPlaceholder(Uint8List bytes) =>
      isSankakuExpiredPlaceholder(bytes);
}
