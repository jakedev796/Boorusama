// Dart imports:
import 'dart:typed_data';

// Package imports:
import 'package:equatable/equatable.dart';

// Project imports:
import 'bookmark.dart';

class BookmarkMediaUrls extends Equatable {
  const BookmarkMediaUrls({
    required this.thumbnailUrl,
    required this.sampleUrl,
    required this.originalUrl,
    required this.cacheAliases,
    this.expiresAt,
  });

  final String thumbnailUrl;
  final String sampleUrl;
  final String originalUrl;

  /// Maps each refreshed URL to the URL whose cache key it is stored under.
  /// Targets must stay the same across refreshes and differ from the stored
  /// URLs, whose keys may already hold a placeholder served after expiry.
  final Map<String, String> cacheAliases;

  /// When the earliest of the refreshed URLs stops working, if known.
  final DateTime? expiresAt;

  bool isUsableAt(DateTime now, {required Duration margin}) =>
      switch (expiresAt) {
        null => true,
        final expiresAt => expiresAt.isAfter(now.add(margin)),
      };

  @override
  List<Object?> get props => [
    thumbnailUrl,
    sampleUrl,
    originalUrl,
    cacheAliases,
    expiresAt,
  ];
}

/// Renews bookmark media for engines whose stored URLs expire.
abstract interface class BookmarkMediaRefresher {
  /// Whether the stored URLs have expired, decided without network access.
  bool needsRefresh(Bookmark bookmark);

  Future<BookmarkMediaUrls?> refresh(Bookmark bookmark);

  /// Whether downloaded bytes are the image the server sends in place of an
  /// expired file, which must never be cached as the bookmark's media.
  bool isExpiredPlaceholder(Uint8List bytes);
}

/// What a bookmark's media should be rendered from.
sealed class BookmarkMedia {
  const BookmarkMedia();
}

final class BookmarkMediaStored extends BookmarkMedia {
  const BookmarkMediaStored();
}

/// Fresh URLs are on their way; nothing should be requested meanwhile.
final class BookmarkMediaRefreshing extends BookmarkMedia {
  const BookmarkMediaRefreshing();
}

final class BookmarkMediaRefreshed extends BookmarkMedia {
  const BookmarkMediaRefreshed(this.urls, {required this.fetchedAt});

  final BookmarkMediaUrls urls;
  final DateTime fetchedAt;
}

class BookmarkMediaRenewal {
  const BookmarkMediaRenewal({
    this.renewMargin = const Duration(minutes: 1),
    this.minRenewDelay = const Duration(minutes: 5),
    this.now = DateTime.now,
  });

  /// How long before expiry refreshed URLs stop being used. Renewal starts
  /// twice as early, so the new URLs normally arrive first.
  final Duration renewMargin;

  /// The shortest wait before another refresh, so short-lived signatures or a
  /// clock running ahead can't cause back-to-back requests.
  final Duration minRenewDelay;

  final DateTime Function() now;
}
