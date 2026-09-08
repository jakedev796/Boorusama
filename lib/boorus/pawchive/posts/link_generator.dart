// Project imports:
import '../../../core/posts/post/types.dart';
import 'types.dart';

/// Builds the web URL for an archived post.
///
/// Post pages are addressed by the whole `{service}/user/{creator}/post/{id}`
/// triple, so none of the shared id-based generators fit.
///
/// Typed against [Post] rather than [PawchivePost]: Dart generics are
/// covariant, so a `PostLinkGenerator<PawchivePost>` would satisfy the
/// analyzer here and then throw at runtime on anything else.
class PawchivePostLinkGenerator implements PostLinkGenerator<Post> {
  const PawchivePostLinkGenerator({required this.baseUrl});

  final String baseUrl;

  @override
  String getLink(Post post) {
    if (post is! PawchivePost) return baseUrl;

    final root = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;

    return '$root/${post.service}/user/${post.creatorId}/post/${post.postId}';
  }
}
