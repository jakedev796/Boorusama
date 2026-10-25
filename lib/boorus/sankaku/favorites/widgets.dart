// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurumi/material.dart';

// Project imports:
import '../../../core/configs/auth/widgets.dart';
import '../../../core/configs/config/providers.dart';
import '../../../core/posts/favorites/widgets.dart';
import '../posts/providers.dart';
import 'providers.dart';

class SankakuFavoritesPage extends ConsumerWidget {
  const SankakuFavoritesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watchConfigAuth;

    return BooruConfigAuthFailsafe(
      builder: (_) => ref
          .watch(sankakuAccountNameProvider(config))
          .when(
            data: (username) => switch (username) {
              final username? => SankakuFavoritesPageInternal(
                username: username,
              ),
              null => const _AccountNameError(),
            },
            loading: () => const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            ),
            error: (_, _) => const _AccountNameError(),
          ),
    );
  }
}

class _AccountNameError extends StatelessWidget {
  const _AccountNameError();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('Could not find your Sankaku account name.'),
      ),
    );
  }
}

class SankakuFavoritesPageInternal extends ConsumerWidget {
  const SankakuFavoritesPageInternal({
    required this.username,
    super.key,
  });

  final String username;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watchConfigSearch;
    final query = 'fav:$username';

    return FavoritesPageScaffold(
      favQueryBuilder: () => query,
      fetcher: (page) =>
          ref.read(sankakuPostRepoProvider(config)).getPosts(query, page),
    );
  }
}
