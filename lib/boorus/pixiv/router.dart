// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurumi/cupertino.dart';

// Project imports:
import '../../core/router.dart';
import 'ranking/widgets.dart';

/// Deep-link route for the Ranking page, following the
/// `lib/boorus/eshuushuu/router.dart` / `danbooru/router.dart` convention
/// so it is reachable directly, not only via the custom-home selector.
///
/// Registered in `lib/core/router.dart` as `...pixivRoutes,` alongside the
/// other engines' route lists.
final pixivRankingRoute = GoRoute(
  path: '/pixiv/ranking',
  pageBuilder: (context, state) => CupertinoPage(
    key: state.pageKey,
    child: const PixivRankingPage(),
  ),
);

final pixivRoutes = [
  pixivRankingRoute,
];

void goToPixivRankingPage(WidgetRef ref) {
  ref.router.push('/pixiv/ranking');
}
