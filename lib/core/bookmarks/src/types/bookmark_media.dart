// Package imports:
import 'package:equatable/equatable.dart';

// Project imports:
import 'bookmark.dart';

class BookmarkMediaUrls extends Equatable {
  const BookmarkMediaUrls({
    required this.thumbnailUrl,
    required this.sampleUrl,
    required this.originalUrl,
    required this.originalCacheUrl,
  });

  final String thumbnailUrl;
  final String sampleUrl;
  final String originalUrl;

  /// The URL whose cache key the refreshed original is stored under. It must
  /// stay the same across refreshes and differ from the stored URL, whose
  /// key may already hold a placeholder served after expiry.
  final String originalCacheUrl;

  @override
  List<Object?> get props => [
    thumbnailUrl,
    sampleUrl,
    originalUrl,
    originalCacheUrl,
  ];
}

/// Fetches fresh media URLs for a bookmark whose stored ones no longer load.
/// Returns null when the stored URLs are still usable.
typedef BookmarkMediaRefresher =
    Future<BookmarkMediaUrls?> Function(Bookmark bookmark);
