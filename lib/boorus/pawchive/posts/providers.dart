// Package imports:
import 'package:booru_clients/pawchive.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../../core/configs/config/types.dart';
import '../../../core/posts/post/providers.dart';
import '../../../core/posts/post/types.dart';
import '../../../core/search/queries/providers.dart';
import '../../../core/settings/providers.dart';
import '../client_provider.dart';
import 'parser.dart';
import 'query.dart';

final pawchivePostRepoProvider =
    Provider.family<PostRepository, BooruConfigSearch>(
      (ref, config) {
        final client = ref.watch(pawchiveClientProvider(config.auth));
        final tagComposer = ref.watch(defaultTagQueryComposerProvider(config));

        return PostRepositoryBuilder(
          tagComposer: tagComposer,
          getSettings: () async => ref.read(imageListingSettingsProvider),
          fetchSingle: (id, {options}) {
            // Ids are synthesised per file, so they cannot be turned back into
            // an API request. Post details are always reached from a listing,
            // which already holds the composite key.
            return Future.value();
          },
          fetch: (tags, page, {limit, options}) async {
            final query = PawchiveQuery.parse(tags);
            final metadata = PostMetadata(
              page: page,
              search: tags.join(' '),
              limit: limit,
            );

            // Offsets step by 50 and the API ignores `limit` entirely, so the
            // page size is fixed regardless of the user's setting.
            final offset = (page - 1) * kPawchivePageSize;

            final dtos = query.hasCreator
                ? await client.getCreatorPosts(
                    service: query.service!,
                    creatorId: query.creatorId!,
                    query: query.text,
                    tag: query.tag,
                    offset: offset,
                  )
                : await client.getRecentPosts(
                    query: query.text,
                    offset: offset,
                  );

            return postDtosToPosts(
              dtos,
              client,
              metadata: metadata,
            ).toResult();
          },
        );
      },
    );

/// Tags belonging to one creator, for filtering within their posts.
final pawchiveCreatorTagsProvider =
    FutureProvider.family<
      List<String>,
      ({BooruConfigAuth config, String service, String creatorId})
    >((ref, params) {
      final client = ref.watch(pawchiveClientProvider(params.config));

      return client.getCreatorTags(
        service: params.service,
        creatorId: params.creatorId,
      );
    });
