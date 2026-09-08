// Package imports:
import 'package:booru_clients/pawchive.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../../core/configs/config/types.dart';
import '../client_provider.dart';

/// Every archived creator, fetched once per session.
///
/// `/creators` is unpaginated and unsorted, and it is the only way the API
/// exposes the creator list — there is no search or page parameter. The
/// response is large (tens of megabytes), so this is deliberately *not*
/// autoDispose and must only be read from the creators view, never eagerly at
/// startup.
///
/// The result is held for the session only; it is re-fetched after a restart.
final pawchiveCreatorsProvider =
    FutureProvider.family<List<PawchiveCreatorDto>, BooruConfigAuth>((
      ref,
      config,
    ) async {
      final client = ref.watch(pawchiveClientProvider(config));
      final creators = await client.getCreators();

      // Name order, since the API offers no ordering of its own.
      return creators.toList()..sort(
        (a, b) => (a.name ?? '').toLowerCase().compareTo(
          (b.name ?? '').toLowerCase(),
        ),
      );
    });

final pawchiveCreatorFilterProvider =
    NotifierProvider<PawchiveCreatorFilterNotifier, String>(
      PawchiveCreatorFilterNotifier.new,
    );

class PawchiveCreatorFilterNotifier extends Notifier<String> {
  @override
  String build() => '';

  void update(String query) => state = query;
}

/// [pawchiveCreatorsProvider] narrowed by the current filter.
///
/// Filtering happens locally because the API has no creator search.
final pawchiveFilteredCreatorsProvider =
    Provider.family<AsyncValue<List<PawchiveCreatorDto>>, BooruConfigAuth>((
      ref,
      config,
    ) {
      final creators = ref.watch(pawchiveCreatorsProvider(config));
      final filter = ref.watch(pawchiveCreatorFilterProvider).trim();

      return creators.whenData((data) {
        if (filter.isEmpty) return data;

        final needle = filter.toLowerCase();

        return data
            .where(
              (e) =>
                  (e.name ?? '').toLowerCase().contains(needle) ||
                  (e.service ?? '').toLowerCase().contains(needle),
            )
            .toList();
      });
    });
