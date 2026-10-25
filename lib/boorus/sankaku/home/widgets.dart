// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/cupertino.dart';
import 'package:kurumi/material.dart';
import 'package:material_symbols_icons/symbols.dart';

// Project imports:
import '../../../core/configs/config/providers.dart';
import '../../../core/home/widgets.dart';
import '../../../core/posts/favorites/routes.dart';
import '../../../core/widgets/widgets.dart';
import '../explore/widgets.dart';
import '../favorites/widgets.dart';

class SankakuHomePage extends ConsumerWidget {
  const SankakuHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watchConfigAuth;
    final login = config.login;

    return HomePageScaffold(
      mobileMenu: [
        SideMenuTile(
          icon: const Icon(
            Symbols.explore,
            fill: 1,
          ),
          title: Text(context.t.explore.explore),
          onTap: () => Navigator.of(context).push(
            CupertinoPageRoute(
              settings: const RouteSettings(name: 'explore'),
              builder: (_) => Scaffold(
                appBar: AppBar(
                  title: Text(context.t.explore.explore),
                ),
                body: const CustomContextMenuOverlay(
                  child: SankakuExplorePage(),
                ),
              ),
            ),
          ),
        ),
        if (login != null)
          SideMenuTile(
            icon: const Icon(Symbols.favorite),
            title: Text(context.t.profile.favorites),
            onTap: () {
              goToFavoritesPage(ref);
            },
          ),
      ],
      desktopMenuBuilder: (context, constraints) => [
        HomeNavigationTile(
          value: 1,
          constraints: constraints,
          selectedIcon: Symbols.explore,
          icon: Symbols.explore,
          title: 'Explore',
        ),
        if (login != null)
          HomeNavigationTile(
            value: 2,
            constraints: constraints,
            selectedIcon: Symbols.favorite,
            icon: Symbols.favorite,
            title: 'Favorites',
          ),
      ],
      desktopViews: [
        const SankakuExplorePage(),
        if (login != null) const SankakuFavoritesPage(),
      ],
    );
  }
}
