// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurumi/cupertino.dart';

// Project imports:
import '../../core/router.dart';
import 'creators/widgets.dart';

/// Deep-link route for the Creators page, so it is reachable directly and
/// not only by selecting it as the home-screen layout.
///
/// Registered in `lib/core/router.dart` as `...pawchiveRoutes,` alongside the
/// other engines' route lists.
final pawchiveCreatorsRoute = GoRoute(
  path: '/pawchive/creators',
  pageBuilder: (context, state) => CupertinoPage(
    key: state.pageKey,
    child: const PawchiveCreatorsPage(),
  ),
);

final pawchiveRoutes = [
  pawchiveCreatorsRoute,
];

void goToPawchiveCreatorsPage(WidgetRef ref) {
  ref.router.push('/pawchive/creators');
}
