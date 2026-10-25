// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurumi/material.dart';
import 'package:rich_text_controller/rich_text_controller.dart';

// Project imports:
import '../../../core/configs/config/providers.dart';
import '../../../core/search/search/routes.dart';
import '../../../core/search/search/widgets.dart';
import '../../../core/tags/metatag/widgets.dart';
import '../../../foundation/utils/flutter_utils.dart';
import '../posts/providers.dart';
import '../tags/metatags.dart';

class SankakuSearchPage extends ConsumerWidget {
  const SankakuSearchPage({
    required this.params,
    super.key,
  });

  final SearchParams params;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postRepo = ref.watch(sankakuPostRepoProvider(ref.watchConfigSearch));
    final metatags = kSankakuMetatags.map((e) => e.name).join('|');

    return SearchPageScaffold(
      params: params,
      fetcher: (page, controller) =>
          postRepo.getPostsFromController(controller.tagSet, page),
      textMatchers: [
        RegexMatcher(
          pattern: RegExp(
            '($metatags)+:',
            caseSensitive: false,
          ),
          spanBuilder: (match) => WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: MetatagContainer(
              tag: match.text,
            ),
          ),
        ),
      ],
      landingViewBuilder: (controller) => SearchLandingView(
        child: DefaultSearchLandingChildren(
          children: [
            DefaultMobileQueryActionSection(controller: controller),
            SankakuMetatagsSection(controller: controller),
            DefaultMobileFavoriteTagsSection(controller: controller),
            DefaultMobileSearchHistorySection(controller: controller),
          ],
        ),
      ),
    );
  }
}

class SankakuMetatagsSection extends StatelessWidget {
  const SankakuMetatagsSection({
    required this.controller,
    super.key,
  });

  final SearchPageController controller;

  @override
  Widget build(BuildContext context) {
    return MetatagsSection(
      editable: false,
      metatags: kSankakuMetatags.toList(),
      userMetatags: kSankakuQuickMetatags,
      onOptionTap: _insert,
      onUserMetatagAdded: (tag) async => _insert(tag.name),
      onUserMetatagDeleted: (_) async {},
    );
  }

  void _insert(String metatag) {
    controller.tapRawMetaTag(metatag);
    controller.focus.requestFocus();
    controller.textController.setTextAndCollapseSelection('$metatag:');
  }
}
