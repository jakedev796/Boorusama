// Project imports:
import '../types/bookmark_media.dart';
import 'bookmark_convert.dart';

typedef BookmarkTileMedia = ({
  String imageUrl,
  String initialThumbnailUrl,
  Map<String, String>? cacheAliases,
});

/// What a bookmark grid tile shows. While fresh URLs are on their way the
/// tile requests nothing, since its stored URLs may only return the
/// expired-link image.
BookmarkTileMedia bookmarkTileMedia(BookmarkMedia media, BookmarkPost post) =>
    switch (media) {
      BookmarkMediaRefreshed(:final urls) => (
        imageUrl: post.isVideo ? urls.thumbnailUrl : urls.sampleUrl,
        initialThumbnailUrl: post.isVideo ? urls.thumbnailUrl : urls.sampleUrl,
        cacheAliases: urls.cacheAliases,
      ),
      BookmarkMediaRefreshing() => (
        imageUrl: '',
        initialThumbnailUrl: _storedInitialThumbnailUrl(post),
        cacheAliases: null,
      ),
      BookmarkMediaStored() => (
        imageUrl: post.isVideo ? post.thumbnailImageUrl : post.sampleImageUrl,
        initialThumbnailUrl: _storedInitialThumbnailUrl(post),
        cacheAliases: null,
      ),
    };

String _storedInitialThumbnailUrl(BookmarkPost post) =>
    post.isVideo ? post.bookmark.thumbnailUrl : post.sampleImageUrl;
