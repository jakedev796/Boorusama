// Dart imports:
import 'dart:convert';
import 'dart:io';

// Package imports:
import 'package:booru_clients/sankaku.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;

// Project imports:
import 'package:boorusama/boorus/sankaku/client_provider.dart';
import 'package:boorusama/boorus/sankaku/posts/providers.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'riverpod_test_utils.dart';

void main() {
  group('Opening a Sankaku post by id', () {
    late HttpServer server;

    setUp(() async {
      server = await shelf_io.serve(
        (request) {
          final id = request.url.pathSegments.last;
          return shelf.Response.ok(
            jsonEncode({
              'id': int.tryParse(id) ?? id,
              'file_url': 'https://s.sankakucomplex.com/o/$id.jpg',
              'tags': <Object>[],
            }),
            headers: {'content-type': 'application/json'},
          );
        },
        'localhost',
        0,
      );
    });

    tearDown(() => server.close(force: true));

    for (final id in ['62946704', '1QaEx8z82M9']) {
      test('loads the post for id $id', () async {
        final config = BooruConfig.defaultConfig(
          booruType: BooruType.sankaku,
          url: 'https://chan.sankakucomplex.com/',
          customDownloadFileNameFormat: null,
        );
        final container = createContainer(
          overrides: [
            sankakuClientProvider.overrideWith(
              (ref, _) => SankakuClient(
                baseUrl: 'http://localhost:${server.port}',
                dio: Dio(),
              ),
            ),
          ],
        );

        final result = await container
            .read(sankakuPostRepoProvider(config.search))
            .getPost(PostId.from(id))
            .run();

        expect(
          result.getOrElse((e) => fail('lookup failed: $e'))?.originalImageUrl,
          'https://s.sankakucomplex.com/o/$id.jpg',
        );
      });
    }
  });
}
