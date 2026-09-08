// Project imports:
import '../../core/boorus/defaults/widgets.dart';
import '../../core/boorus/engine/types.dart';
import '../../core/configs/config/types.dart';
import '../../core/configs/create/widgets.dart';
import '../../core/home/types.dart';
import '../../core/posts/details/widgets.dart';
import '../../core/posts/details_parts/types.dart';
import '../../core/posts/details_parts/widgets.dart';
import 'posts/types.dart';

class PixivBuilder extends BaseBooruBuilder {
  PixivBuilder();

  /// A plain, unauthenticated config page for now — Pixiv has no anonymous
  /// mode, so this is a placeholder seam. S3 replaces it with the OAuth
  /// login / refresh-token-paste tab.
  @override
  CreateConfigPageBuilder get createConfigPageBuilder =>
      (
        context,
        id, {
        backgroundColor,
      }) => CreateBooruConfigScope(
        id: id,
        config: BooruConfig.defaultConfig(
          booruType: id.booruType,
          url: id.url,
          customDownloadFileNameFormat: null,
        ),
        child: CreateAnonConfigPage(
          backgroundColor: backgroundColor,
        ),
      );

  @override
  PostDetailsPageBuilder get postDetailsPageBuilder => (context, payload) {
    final posts = payload.posts.map((e) => e as PixivPost).toList();

    return PostDetailsScope(
      initialIndex: payload.initialIndex,
      initialThumbnailUrl: payload.initialThumbnailUrl,
      posts: posts,
      scrollController: payload.scrollController,
      dislclaimer: payload.dislclaimer,
      child: const DefaultPostDetailsPage<PixivPost>(),
    );
  };

  /// Unlike Pawchive, Pixiv illusts carry a real, meaningful tag pool, so —
  /// unlike that engine — the tags section stays part of the details UI.
  @override
  final postDetailsUIBuilder = PostDetailsUIBuilder(
    preview: {
      DetailsPart.toolbar: (context) =>
          const DefaultInheritedPostActionToolbar<PixivPost>(),
    },
    full: {
      DetailsPart.toolbar: (context) =>
          const DefaultInheritedPostActionToolbar<PixivPost>(),
      DetailsPart.tags: (context) =>
          const DefaultInheritedTagsTile<PixivPost>(),
      DetailsPart.fileDetails: (context) =>
          const DefaultInheritedFileDetailsSection<PixivPost>(),
    },
  );

  /// Spread from the shared default for now — S4 adds the Ranking page as
  /// an extra entry here.
  @override
  Map<CustomHomeViewKey, CustomHomeDataBuilder> get customHomeViewBuilders => {
    ...kDefaultAltHomeView,
  };
}
