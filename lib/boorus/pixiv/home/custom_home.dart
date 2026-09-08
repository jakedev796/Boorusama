// Package imports:
import 'package:i18n/i18n.dart';

// Project imports:
import '../../../core/home/types.dart';
import '../ranking/widgets.dart';

/// The Ranking page offered as an alternate home view — pre-made
/// Day/Week/Month popularity filters with step back/forward through
/// pixiv's per-day ranking snapshots. Not the default: most users land on
/// the regular search/browse feed, with ranking as an opt-in alternative.
final pixivCustomHome = {
  ...kDefaultAltHomeView,
  const CustomHomeViewKey('ranking'): CustomHomeDataBuilder(
    displayName: (context) => context.t.pixiv.ranking.title,
    builder: (context, _) => const PixivRankingPage(),
  ),
};
