// Package imports:
import 'package:booru_clients/pawchive.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../core/boorus/defaults/types.dart';
import '../../core/configs/config/types.dart';
import '../../core/configs/create/create.dart';
import '../../core/downloads/filename/types.dart';
import '../../core/http/client/providers.dart';
import '../../core/posts/post/types.dart';
import '../../core/tags/autocompletes/types.dart';
import 'posts/link_generator.dart';
import 'posts/providers.dart';
import 'posts/types.dart';

class PawchiveRepository extends BooruRepositoryDefault {
  const PawchiveRepository({required this.ref});

  @override
  final Ref ref;

  @override
  PostRepository<Post> post(BooruConfigSearch config) {
    return ref.read(pawchivePostRepoProvider(config));
  }

  /// Pawchive has no global tag pool and no autocomplete endpoint — tags
  /// exist only per creator — so there is nothing to suggest.
  @override
  AutocompleteRepository autocomplete(BooruConfigAuth config) {
    return EmptyAutocompleteRepository();
  }

  @override
  PostLinkGenerator<Post> postLinkGenerator(BooruConfigAuth config) {
    return PawchivePostLinkGenerator(baseUrl: config.url);
  }

  @override
  BooruSiteValidator? siteValidator(BooruConfigAuth config) {
    final dio = ref.watch(defaultDioProvider(config));

    return () => PawchiveClient(
      baseUrl: config.url,
      dio: dio,
    ).getRecentPosts().then((value) => true);
  }

  @override
  DownloadFilenameGenerator<Post> downloadFilenameBuilder(
    BooruConfigAuth config,
  ) {
    return DownloadFileNameBuilder<Post>(
      defaultFileNameFormat: kDefaultCustomDownloadFileNameFormat,
      defaultBulkDownloadFileNameFormat: kDefaultCustomDownloadFileNameFormat,
      sampleData: const [],
      hasRating: false,
      extensionHandler: (post, config) =>
          post.format.startsWith('.') ? post.format.substring(1) : post.format,
      tokenHandlers: [
        // The archive stores files by content hash, so the original filename
        // is the only human-readable name available.
        TokenHandler('file_name', (post, options) {
          return post is PawchivePost ? post.fileName ?? '' : '';
        }),
        TokenHandler('creator', (post, options) {
          return post is PawchivePost ? post.creatorId : '';
        }),
        TokenHandler('service', (post, options) {
          return post is PawchivePost ? post.service : '';
        }),
        TokenHandler('post_id', (post, options) {
          return post is PawchivePost ? post.postId : '';
        }),
      ],
    );
  }
}
