// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

// Project imports:
import '../../../core/configs/config/providers.dart';
import '../../../core/posts/explores/types.dart';
import '../../../core/posts/explores/widgets.dart';
import '../../../core/posts/listing/widgets.dart';
import '../posts/providers.dart';
import 'types.dart';

class SankakuExplorePage extends ConsumerStatefulWidget {
  const SankakuExplorePage({
    super.key,
  });

  @override
  ConsumerState<SankakuExplorePage> createState() => _SankakuExplorePageState();
}

class _SankakuExplorePageState extends ConsumerState<SankakuExplorePage> {
  final selectedDate = ValueNotifier(DateTime.now());
  final selectedScale = ValueNotifier(TimeScale.day);
  final selectedOrder = ValueNotifier(SankakuExploreOrder.popularity);

  @override
  void dispose() {
    selectedDate.dispose();
    selectedScale.dispose();
    selectedOrder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(sankakuPostRepoProvider(ref.watchConfigSearch));

    return PostScope(
      fetcher: (page) => repo.getPosts(
        sankakuExploreQuery(
          order: selectedOrder.value,
          scale: selectedScale.value,
          date: selectedDate.value,
        ),
        page,
      ),
      builder: (context, controller) => PostGrid(
        controller: controller,
        sliverHeaders: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Center(
                child: KurumiSegmentedButton(
                  segments: {
                    SankakuExploreOrder.popularity: context.t.explore.popular,
                    SankakuExploreOrder.quality: context.t.explore.top,
                  },
                  initialValue: selectedOrder.value,
                  onChanged: (order) {
                    selectedOrder.value = order;
                    controller.refresh();
                  },
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: TimeScaleToggleSwitch(
              initialValue: selectedScale.value,
              onToggle: (scale) {
                selectedScale.value = scale;
                controller.refresh();
              },
            ),
          ),
          SliverToBoxAdapter(
            child: ValueListenableBuilder(
              valueListenable: selectedDate,
              builder: (context, date, _) => ValueListenableBuilder(
                valueListenable: selectedScale,
                builder: (_, scale, _) => DateTimeSelector(
                  onDateChanged: (date) {
                    selectedDate.value = date;
                    controller.refresh();
                  },
                  date: date,
                  scale: scale,
                  lastDate: DateTime.now(),
                  backgroundColor: Colors.transparent,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
