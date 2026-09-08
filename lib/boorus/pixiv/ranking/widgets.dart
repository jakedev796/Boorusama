// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

// Project imports:
import '../../../core/configs/config/providers.dart';
import '../../../core/posts/explores/types.dart';
import '../../../core/posts/explores/widgets.dart';
import '../../../core/posts/listing/widgets.dart';
import '../posts/types.dart';
import 'providers.dart';

/// Pre-made popularity filters — Day/Week/Month, with step back/forward
/// through pixiv's per-day ranking snapshots.
///
/// A true rolling 24h window is not offered by the API (see the ranking
/// slice's plan notes): the ranking is an immutable per-JST-day snapshot,
/// so "day" here means the whole of one JST calendar day, not a trailing
/// 24 hours.
class PixivRankingPage extends ConsumerStatefulWidget {
  const PixivRankingPage({super.key});

  @override
  ConsumerState<PixivRankingPage> createState() => _PixivRankingPageState();
}

class _PixivRankingPageState extends ConsumerState<PixivRankingPage> {
  final _scale = ValueNotifier(TimeScale.day);
  late final _date = ValueNotifier(pixivRankingNewestDate());

  @override
  void dispose() {
    _scale.dispose();
    _date.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watchConfigAuth;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.t.pixiv.ranking.title),
      ),
      body: PostScope<PixivPost>(
        fetcher: (page) => ref
            .read(pixivRankingRepoProvider(config))
            .getRanking(
              scale: _scale.value,
              date: _date.value,
              page: page,
            ),
        builder: (context, controller) => Column(
          children: [
            ValueListenableBuilder(
              valueListenable: _scale,
              builder: (_, scale, _) => TimeScaleToggleSwitch(
                initialValue: scale,
                onToggle: (newScale) {
                  _scale.value = newScale;
                  // Changing scale can move the clamped window (e.g. a
                  // month-scale newest date differs from a day-scale one
                  // once JST-yesterday is involved), so re-clamp before
                  // refetching.
                  _date.value = clampPixivRankingDate(_date.value);
                  controller.refresh();
                },
              ),
            ),
            Expanded(
              child: PostGrid(
                controller: controller,
              ),
            ),
            ValueListenableBuilder(
              valueListenable: _date,
              builder: (_, date, _) => ValueListenableBuilder(
                valueListenable: _scale,
                builder: (_, scale, _) => DateTimeSelector(
                  onDateChanged: (newDate) {
                    _date.value = clampPixivRankingDate(newDate);
                    controller.refresh();
                  },
                  date: date,
                  scale: scale,
                  backgroundColor: Colors.transparent,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
