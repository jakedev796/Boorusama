// Project imports:
import '../../core/boorus/defaults/widgets.dart';
import '../../core/boorus/engine/types.dart';
import '../../core/configs/config/types.dart';
import '../../core/configs/create/widgets.dart';
import '../../core/home/types.dart';
import '../../core/posts/details/widgets.dart';
import '../../core/posts/details_parts/types.dart';
import '../../core/posts/details_parts/widgets.dart';
import 'home/custom_home.dart';
import 'posts/types.dart';

class PawchiveBuilder extends BaseBooruBuilder {
  PawchiveBuilder();

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
    final posts = payload.posts.map((e) => e as PawchivePost).toList();

    return PostDetailsScope(
      initialIndex: payload.initialIndex,
      initialThumbnailUrl: payload.initialThumbnailUrl,
      posts: posts,
      scrollController: payload.scrollController,
      dislclaimer: payload.dislclaimer,
      child: const DefaultPostDetailsPage<PawchivePost>(),
    );
  };

  /// No tags section — Pawchive has no global tag pool, and per-creator tags
  /// are not carried on individual posts.
  @override
  final postDetailsUIBuilder = PostDetailsUIBuilder(
    preview: {
      DetailsPart.toolbar: (context) =>
          const DefaultInheritedPostActionToolbar<PawchivePost>(),
    },
    full: {
      DetailsPart.toolbar: (context) =>
          const DefaultInheritedPostActionToolbar<PawchivePost>(),
      DetailsPart.fileDetails: (context) =>
          const DefaultInheritedFileDetailsSection<PawchivePost>(),
    },
  );

  @override
  Map<CustomHomeViewKey, CustomHomeDataBuilder> get customHomeViewBuilders =>
      pawchiveCustomHome;
}
