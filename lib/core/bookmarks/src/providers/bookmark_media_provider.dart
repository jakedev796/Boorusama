// Dart imports:
import 'dart:async';

// Package imports:
import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../../boorus/engine/providers.dart';
import '../../../configs/config/providers.dart';
import '../../../configs/config/types.dart';
import '../types/bookmark.dart';
import '../types/bookmark_media.dart';

final bookmarkMediaRenewalProvider = Provider<BookmarkMediaRenewal>(
  (ref) => const BookmarkMediaRenewal(),
);

final bookmarkMediaRefresherProvider = Provider.autoDispose
    .family<BookmarkMediaRefresher?, Bookmark>((ref, bookmark) {
      final config = ref.watch(
        firstMatchingConfigBySourceUrlProvider((
          bookmark.booruId,
          bookmark.sourceUrl,
        )),
      );

      return switch (config) {
        null => null,
        final config =>
          ref
              .watch(booruRepoProvider(config.auth))
              ?.bookmarkMediaRefresher(config.auth),
      };
    });

class BookmarkMediaFetch extends Equatable {
  const BookmarkMediaFetch({
    required this.urls,
    required this.fetchedAt,
  });

  final BookmarkMediaUrls? urls;
  final DateTime fetchedAt;

  @override
  List<Object?> get props => [urls, fetchedAt];
}

/// Refreshed media for a bookmark, renewed before it expires. A renewal that
/// fails keeps the previous URLs and retries later rather than falling back
/// to the stored ones.
final bookmarkMediaFetchProvider = FutureProvider.autoDispose
    .family<BookmarkMediaFetch, Bookmark>((ref, bookmark) async {
      final renewal = ref.watch(bookmarkMediaRenewalProvider);
      final refresher = ref.watch(bookmarkMediaRefresherProvider(bookmark));
      final previous = ref.state.valueOrNull?.urls;

      Timer? timer;
      var disposed = false;
      ref.onDispose(() {
        disposed = true;
        timer?.cancel();
      });

      // A provider disposed while refreshing must not leave a timer behind:
      // it would later invalidate whichever instance is alive by then.
      void renewAfter(Duration delay) {
        if (!disposed) timer = Timer(delay, ref.invalidateSelf);
      }

      if (refresher == null) {
        return BookmarkMediaFetch(urls: null, fetchedAt: renewal.now());
      }

      BookmarkMediaUrls? fresh;
      try {
        fresh = await refresher.refresh(bookmark);
      } catch (_) {
        fresh = null;
      }

      final now = renewal.now();

      switch (fresh) {
        case null when previous != null:
          renewAfter(renewal.minRenewDelay);
          return BookmarkMediaFetch(urls: previous, fetchedAt: now);
        case null:
          return BookmarkMediaFetch(urls: null, fetchedAt: now);
        case final fresh:
          if (fresh.expiresAt case final expiresAt?) {
            // Renew a margin ahead of when display stops using the URLs, so
            // the renewed ones arrive before anything has to go blank.
            final delay = expiresAt.difference(now) - renewal.renewMargin * 2;
            if (delay >= renewal.minRenewDelay) renewAfter(delay);
          }
          return BookmarkMediaFetch(urls: fresh, fetchedAt: now);
      }
    });

final bookmarkMediaProvider = Provider.autoDispose
    .family<BookmarkMedia, Bookmark>((ref, bookmark) {
      final refresher = ref.watch(bookmarkMediaRefresherProvider(bookmark));

      if (refresher == null || !refresher.needsRefresh(bookmark)) {
        return const BookmarkMediaStored();
      }

      final fetch = ref.watch(bookmarkMediaFetchProvider(bookmark));

      return switch (fetch.valueOrNull) {
        BookmarkMediaFetch(urls: final urls?, :final fetchedAt) =>
          BookmarkMediaRefreshed(urls, fetchedAt: fetchedAt),
        BookmarkMediaFetch() => const BookmarkMediaStored(),
        null when fetch.hasError => const BookmarkMediaStored(),
        null => const BookmarkMediaRefreshing(),
      };
    });

/// Refreshed URLs can outlive their signature while held in memory, e.g.
/// across device sleep, which pauses timers. Loading them then caches the
/// expired-link image, so they count as refreshing and are fetched again.
({BookmarkMedia media, bool refetch}) bookmarkMediaForDisplay(
  BookmarkMedia media, {
  required DateTime now,
  required BookmarkMediaRenewal renewal,
  required bool isFetching,
}) => switch (media) {
  BookmarkMediaRefreshed(:final urls, :final fetchedAt)
      when !urls.isUsableAt(now, margin: renewal.renewMargin) =>
    (
      media: const BookmarkMediaRefreshing(),
      refetch:
          !isFetching && now.difference(fetchedAt) >= renewal.minRenewDelay,
    ),
  _ => (media: media, refetch: false),
};

extension BookmarkMediaWidgetRefX on WidgetRef {
  BookmarkMedia watchBookmarkMedia(Bookmark bookmark) {
    final current = watch(bookmarkMediaProvider(bookmark));

    if (current is! BookmarkMediaRefreshed) return current;

    final (:media, :refetch) = bookmarkMediaForDisplay(
      current,
      now: read(bookmarkMediaRenewalProvider).now(),
      renewal: read(bookmarkMediaRenewalProvider),
      isFetching: read(bookmarkMediaFetchProvider(bookmark)).isLoading,
    );

    if (refetch) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => invalidate(bookmarkMediaFetchProvider(bookmark)),
      );
    }

    return media;
  }
}
