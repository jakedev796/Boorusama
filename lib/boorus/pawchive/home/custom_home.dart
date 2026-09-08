// Package imports:
import 'package:i18n/i18n.dart';

// Project imports:
import '../../../core/home/types.dart';
import '../creators/widgets.dart';

/// Creator browsing offered as an alternate home view.
///
/// Pawchive is creator-centric — it has no global tag pool — so this is the
/// view that matches the data, with the default recent-posts feed still
/// available. It is not the default because opening it downloads the entire
/// creator list.
final pawchiveCustomHome = {
  ...kDefaultAltHomeView,
  const CustomHomeViewKey('creators'): CustomHomeDataBuilder(
    displayName: (context) => context.t.artists.title,
    builder: (context, _) => const PawchiveCreatorsPage(),
  ),
};
