// Package imports:
import 'package:booru_clients/sankaku.dart';

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

/// Where a bookmark's refreshed original is cached: its stored original
/// without the signature, which stays the same however often Sankaku re-signs
/// the file. Expired originals redirect to an "expired link" image that may
/// already be cached under the signed URL, so that key can't be reused.
String sankakuOriginalCacheUrl(String storedOriginalUrl) =>
    storedOriginalUrl.split('?').first;

// Refresh slightly early so a URL doesn't expire between check and download.
const _kExpiryMargin = Duration(minutes: 1);

BookmarkMediaRefresher sankakuBookmarkMediaRefresher({
  required Future<PostDto?> Function(String id) fetchPost,
  DateTime Function() now = DateTime.now,
}) => (bookmark) async {
  final deadline = now().add(_kExpiryMargin);
  final expired = [
    bookmark.thumbnailUrl,
    bookmark.sampleUrl,
    bookmark.originalUrl,
  ].map(sankakuUrlExpiry).nonNulls.any((e) => !e.isAfter(deadline));

  if (!expired) return null;

  final id = sankakuIdFromSourceUrl(bookmark.sourceUrl);
  if (id == null) return null;

  final post = await fetchPost(id);

  return switch (post?.fileUrl) {
    final original? when original.isNotEmpty => BookmarkMediaUrls(
      thumbnailUrl: post?.previewUrl ?? post?.sampleUrl ?? original,
      sampleUrl: post?.sampleUrl ?? original,
      originalUrl: original,
      originalCacheUrl: sankakuOriginalCacheUrl(bookmark.originalUrl),
    ),
    _ => null,
  };
};
