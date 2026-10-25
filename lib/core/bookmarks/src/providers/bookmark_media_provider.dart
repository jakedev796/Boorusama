// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../../boorus/engine/providers.dart';
import '../../../configs/config/providers.dart';
import '../../../configs/config/types.dart';
import '../types/bookmark.dart';
import '../types/bookmark_media.dart';

/// Fresh media URLs for a bookmark whose stored ones have expired, or null to
/// keep using the stored URLs.
final bookmarkMediaUrlsProvider = FutureProvider.autoDispose
    .family<BookmarkMediaUrls?, Bookmark>((ref, bookmark) async {
      final config = ref.watch(
        firstMatchingConfigBySourceUrlProvider((
          bookmark.booruId,
          bookmark.sourceUrl,
        )),
      );

      if (config == null) return null;

      final refresher = ref
          .watch(booruRepoProvider(config.auth))
          ?.bookmarkMediaRefresher(config.auth);

      if (refresher == null) return null;

      try {
        return await refresher(bookmark);
      } catch (_) {
        // Falling back to the stored URLs keeps today's behaviour.
        return null;
      }
    });
