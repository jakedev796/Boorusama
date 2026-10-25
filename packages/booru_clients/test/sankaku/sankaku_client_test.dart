import 'dart:convert';
import 'dart:io';

import 'package:booru_clients/sankaku.dart';
import 'package:dio/dio.dart' show Dio;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:test/test.dart';

void main() {
  group('SankakuClient', () {
    late HttpServer server;
    late String baseUrl;
    final requests = <Request>[];

    setUp(() async {
      requests.clear();
      server = await shelf_io.serve(
        (request) async {
          requests.add(request);
          final body = switch (request.url.path) {
            'auth/token' => {
              'success': true,
              'token_type': 'Bearer',
              'access_token': 'token-abc',
              'current_user': {'name': 'account_name'},
            },
            _ => <Object>[],
          };
          return Response.ok(
            jsonEncode(body),
            headers: {'content-type': 'application/json'},
          );
        },
        'localhost',
        0,
      );
      baseUrl = 'http://localhost:${server.port}';
    });

    tearDown(() async {
      await server.close(force: true);
    });

    SankakuClient createClient({String? username, String? password}) =>
        SankakuClient(
          baseUrl: baseUrl,
          dio: Dio(),
          username: username,
          password: password,
        );

    final cases = [
      (hidePostsInBooks: true, expected: 'always'),
      (hidePostsInBooks: false, expected: null),
    ];
    for (final c in cases) {
      test(
        'sends hide_posts_in_books=${c.expected} when hiding is ${c.hidePostsInBooks}',
        () async {
          await createClient().getPosts(
            tags: ['tag'],
            hidePostsInBooks: c.hidePostsInBooks,
          );

          final posts = requests.singleWhere((r) => r.url.path == 'posts');
          expect(posts.url.queryParameters['hide_posts_in_books'], c.expected);
        },
      );
    }

    test('resolves the account name when logging in by email', () async {
      final client = createClient(
        username: 'someone@example.com',
        password: 'secret',
      );

      expect(await client.getCurrentUsername(), 'account_name');
    });

    test('has no account name without credentials', () async {
      expect(await createClient().getCurrentUsername(), isNull);
    });
  });
}
