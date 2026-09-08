// Package imports:
import 'package:booru_clients/pawchive.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:material_symbols_icons/symbols.dart';

// Project imports:
import '../../../core/configs/config/providers.dart';
import '../../../core/search/search/routes.dart';
import '../client_provider.dart';
import '../posts/query.dart';
import 'providers.dart';

/// Browse and filter archived creators.
///
/// The whole creator list has to be downloaded to show this page — see
/// [pawchiveCreatorsProvider] — so it is only built when the user opens the
/// view, never at startup.
class PawchiveCreatorsPage extends ConsumerWidget {
  const PawchiveCreatorsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watchConfigAuth;
    final creators = ref.watch(pawchiveFilteredCreatorsProvider(config));

    return Scaffold(
      appBar: AppBar(
        title: Text(context.t.artists.title),
      ),
      body: Column(
        children: [
          const _FilterField(),
          Expanded(
            child: creators.when(
              data: (data) =>
                  data.isEmpty ? const _Empty() : _CreatorList(creators: data),
              loading: () => const _Loading(),
              error: (error, _) => _Error(error: error),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterField extends ConsumerWidget {
  const _FilterField();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: TextField(
        onChanged: ref.read(pawchiveCreatorFilterProvider.notifier).update,
        decoration: InputDecoration(
          isDense: true,
          prefixIcon: const Icon(Symbols.search),
          hintText: context.t.generic.action.search,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}

class _CreatorList extends ConsumerWidget {
  const _CreatorList({required this.creators});

  final List<PawchiveCreatorDto> creators;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watchConfigAuth;
    final client = ref.watch(pawchiveClientProvider(config));

    return ListView.builder(
      itemCount: creators.length,
      itemBuilder: (context, index) {
        final creator = creators[index];
        final service = creator.service;
        final id = creator.id;

        if (service == null || id == null) return const SizedBox.shrink();

        return ListTile(
          leading: CircleAvatar(
            foregroundImage: NetworkImage(
              client.creatorIconUrl(service: service, creatorId: id),
            ),
            child: const Icon(Symbols.person),
          ),
          title: Text(
            creator.name ?? id,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(service),
          onTap: () => goToSearchPage(
            ref,
            tag: PawchiveQuery.creatorTag(service: service, creatorId: id),
          ),
        );
      },
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator.adaptive(),
            SizedBox(height: 16),
            // The creator list is a single large download with no paging, so
            // warn rather than appear stuck.
            Text(
              'Downloading the full creator list. This is a large, '
              'one-time download for this session.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(context.t.generic.errors.no_data),
    );
  }
}

class _Error extends StatelessWidget {
  const _Error({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          error.toString(),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Kurumi.themeOf(context).colorScheme.error,
          ),
        ),
      ),
    );
  }
}
