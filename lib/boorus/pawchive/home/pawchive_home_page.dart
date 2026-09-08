// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';
import 'package:material_symbols_icons/symbols.dart';

// Project imports:
import '../../../core/home/widgets.dart';
import '../creators/widgets.dart';
import '../router.dart';

/// Puts the Creators page in the app's navigation (mobile drawer and desktop
/// rail) alongside the existing custom-home entry in `home/custom_home.dart`,
/// so it is reachable without switching the home-screen layout, matching how
/// Danbooru/e621 surface their own secondary pages.
class PawchiveHomePage extends ConsumerWidget {
  const PawchiveHomePage({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return HomePageScaffold(
      mobileMenu: [
        SideMenuTile(
          icon: const Icon(Symbols.people),
          title: Text(context.t.artists.title),
          onTap: () => goToPawchiveCreatorsPage(ref),
        ),
      ],
      desktopMenuBuilder: (context, constraints) => [
        HomeNavigationTile(
          value: 1,
          constraints: constraints,
          selectedIcon: Symbols.people,
          icon: Symbols.people,
          title: context.t.artists.title,
        ),
      ],
      desktopViews: const [
        PawchiveCreatorsPage(),
      ],
    );
  }
}
